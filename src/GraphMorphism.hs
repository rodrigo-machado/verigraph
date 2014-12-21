{-# LANGUAGE TypeFamilies #-}

module GraphMorphism (
      applyNode
    , applyEdge
    , GraphMorphism
    , TypedGraph
    , updateNodes
    , updateEdges
) where

import qualified Relation as R
import Graph as G
import Graph (Graph)
import Morphism
import Valid

data GraphMorphism a b = GraphMorphism {
                          getDomain    :: Graph a b
                        , getCodomain  :: Graph a b
                        , nodeRelation :: R.Relation G.NodeID
                        , edgeRelation :: R.Relation G.EdgeID
                    }

type TypedGraph a b = GraphMorphism a b

instance Show (GraphMorphism a b) where
    show m =
--        "Domain: " ++ (show $ getDomain m) ++
--        "\nCodomain: " ++ (show $ getCodomain m) ++
        "\nNode mappings: \n" ++
        concatMap (\n -> (show n) ++ " --> " ++ (show (applyNode m n)) ++ "\n")
                  (G.nodes $ getDomain m) ++
        "\nEdge mappings: \n" ++
        concatMap (\e -> (show e) ++ " --> " ++ (show (applyEdge m e)) ++ "\n")
                  (G.edges $ getDomain m)



applyNode :: GraphMorphism a b -> G.NodeID -> [G.NodeID]
applyNode m ln =
    R.apply (nodeRelation m) ln

applyEdge :: GraphMorphism a b -> G.EdgeID -> [G.EdgeID]
applyEdge m le =
    R.apply (edgeRelation m) le
    
empty :: Graph a b -> Graph a b -> GraphMorphism a b
empty gA gB = GraphMorphism gA gB (R.empty [] []) (R.empty [] [])

inverse (GraphMorphism dom cod nm em) =
    GraphMorphism cod dom (R.inverse nm) (R.inverse em)

updateNodes ln gn morphism@(GraphMorphism l g nm em)
    | G.isNodeOf l ln && G.isNodeOf g gn =
        GraphMorphism l g (R.update ln gn nm) em
    | otherwise = morphism

updateEdges le ge morphism@(GraphMorphism l g nm em)
    | G.isEdgeOf l le && G.isEdgeOf g ge =
        GraphMorphism l g nm (R.update le ge em)
    | otherwise = morphism

instance (Eq a, Eq b) => Eq (GraphMorphism a b) where
    m1 == m2 = domain m1 == domain m2 &&
               codomain m1 == codomain m2 &&
               nodeRelation m1 == nodeRelation m2 &&
               edgeRelation m1 == edgeRelation m2


instance (Eq a, Eq b) => Morphism (GraphMorphism a b) where
    type Obj (GraphMorphism a b) = Graph a b

    domain m = getDomain m
    codomain m = getCodomain m
    compose m1 m2 =
        GraphMorphism (domain m1)
                      (codomain m2)
                      (R.compose (nodeRelation m1) (nodeRelation m2))
                      (R.compose (edgeRelation m1) (edgeRelation m2))
    id g = GraphMorphism g g (R.id $ nodes g) (R.id $ edges g)
    monomorphism m =
        R.injective (nodeRelation m) &&
        R.injective (edgeRelation m)
    epimorphism m =
        R.surjective (nodeRelation m) &&
        R.surjective (edgeRelation m)
    isomorphism m =
        monomorphism m && epimorphism m

               

instance Valid (GraphMorphism a b) where
    valid m@(GraphMorphism dom cod nm em) =
        R.total nm &&
        R.functional nm &&
        R.total em &&
        R.functional em &&
        valid dom &&
        valid cod &&
        all (\e -> (G.sourceOf cod e >>= applyEdge m) ==
                   (applyNode m e >>= G.sourceOf dom)
                   &&
                   (G.targetOf cod e >>= applyEdge m) ==
                   (applyEdge m e >>= G.targetOf dom))
            (G.edges dom)
