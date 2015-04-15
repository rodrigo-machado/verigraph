{-# LANGUAGE TypeFamilies #-}

module Graph.GraphMorphism (
      applyNode
    , applyEdge
    , graphMorphism
    , Graph.GraphMorphism.null
    , GraphMorphism
    , Graph.GraphMorphism.empty
    , inverse
    , nodeRelation
    , edgeRelation
    , TypedGraph
    , updateCodomain
    , updateDomain
    , updateNodes
    , updateEdges
) where

import qualified Abstract.Relation as R
import Graph.Graph as G
import Graph.Graph (Graph)
import Abstract.Morphism
import Abstract.Valid

data GraphMorphism a b = GraphMorphism {
                          getDomain    :: Graph a b
                        , getCodomain  :: Graph a b
                        , nodeRelation :: R.Relation G.NodeId
                        , edgeRelation :: R.Relation G.EdgeId
                    } deriving (Read)

instance Eq (GraphMorphism a b) where
    m1 == m2 = domain m1 == domain m2 &&
               codomain m1 == codomain m2 &&
               nodeRelation m1 == nodeRelation m2 &&
               edgeRelation m1 == edgeRelation m2

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



applyNode :: GraphMorphism a b -> G.NodeId -> [G.NodeId]
applyNode m ln =
    R.apply (nodeRelation m) ln

applyEdge :: GraphMorphism a b -> G.EdgeId -> [G.EdgeId]
applyEdge m le =
    R.apply (edgeRelation m) le
    
empty :: Graph a b -> Graph a b -> GraphMorphism a b
empty gA gB = GraphMorphism gA gB (R.empty [] []) (R.empty [] [])

graphMorphism = GraphMorphism

inverse (GraphMorphism dom cod nm em) =
    GraphMorphism cod dom (R.inverse nm) (R.inverse em)

null :: TypedGraph a b -> Bool
null = G.null . getDomain

updateCodomain :: Graph a b -> GraphMorphism a b -> GraphMorphism a b
updateCodomain g gm = gm { getCodomain = g }

updateDomain :: Graph a b -> GraphMorphism a b -> GraphMorphism a b
updateDomain g gm = gm { getDomain = g }

updateNodes :: NodeId -> NodeId -> GraphMorphism a b -> GraphMorphism a b
updateNodes ln gn morphism@(GraphMorphism l g nm em)
    | G.isNodeOf l ln && G.isNodeOf g gn && notMapped morphism ln =
        GraphMorphism l g (R.update ln gn nm) em
    | otherwise = morphism
  where
    notMapped m = Prelude.null . applyNode m

updateEdges :: EdgeId -> EdgeId -> GraphMorphism a b -> GraphMorphism a b
updateEdges le ge morphism@(GraphMorphism l g nm em)
    | G.isEdgeOf l le && G.isEdgeOf g ge && notMapped morphism le =
        GraphMorphism l g nm (R.update le ge em)
    | otherwise = morphism
  where
    notMapped m = Prelude.null . applyEdge m


instance Morphism (GraphMorphism a b) where
    type Obj (GraphMorphism a b) = Graph a b

    domain = getDomain
    codomain = getCodomain
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
        all (\e -> (applyEdge m e >>= G.sourceOf cod) ==
                   (G.sourceOf dom e >>= applyNode m)
                   &&
                   (applyEdge m e >>= G.targetOf cod) ==
                   (G.targetOf dom e >>= applyNode m))
            (G.edges dom)
