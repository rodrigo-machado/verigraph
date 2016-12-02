module TypedGraph.Morphism.Cocomplete (

  calculateCoequalizer,
  calculateNCoequalizer,
  calculateCoproduct,
  calculateNCoproduct,
  calculatePushout

)

where

import           Abstract.Cocomplete
import           Abstract.Morphism              as M
import qualified Data.List.NonEmpty             as NE
import           Data.Maybe                     (fromJust)
import           Data.Set                       as DS
import           Equivalence.EquivalenceClasses
import           Graph.Graph                    as G
import qualified Graph.GraphMorphism            as GM
import           TypedGraph.Graph
import           TypedGraph.Morphism.Core

type TypedNode = (NodeId,NodeId)
type TypedEdge = (EdgeId, NodeId, NodeId, EdgeId)
type RelabelFunction = (NodeId -> NodeId, EdgeId -> EdgeId)

instance Cocomplete (TypedGraphMorphism a b) where
  calculateCoequalizer = calculateCoequalizer'
  calculateNCoequalizer = calculateNCoequalizer'
  calculateCoproduct = calculateCoproduct'
  calculateNCoproduct = calculateNCoproduct'
  initialObject = initialObject'

initialObject' :: TypedGraphMorphism a b -> TypedGraph a b
initialObject' tgm = GM.empty G.empty (typeGraph (domain tgm))

calculateCoequalizer' :: TypedGraphMorphism a b -> TypedGraphMorphism a b -> TypedGraphMorphism a b
calculateCoequalizer' f g = initCoequalizerMorphism b nodeEquivalences edgeEquivalences
  where
    b = getCodomain f
    nodeEquivalences = createNodeEquivalences f g
    edgeEquivalences = createEdgeEquivalences f g

calculateNCoequalizer' :: NE.NonEmpty (TypedGraphMorphism a b) -> TypedGraphMorphism a b
calculateNCoequalizer' fs' = initCoequalizerMorphism b nodeEquivalences edgeEquivalences
  where
    fs = NE.toList fs'
    b = getCodomain $ head fs
    nodeEquivalences = createNodeNEquivalences fs
    edgeEquivalences = createEdgeNEquivalences fs

-- | Given a typed graph @B@ and the sets @Ne@ and @Ee@ of node and edge equivalences
-- it returns the the skeleton of the coequalizer morphism @h : B -> X@, consisting of
-- the typed graphs @B@ and @X@ but without the morphisms between them
initCoequalizerMorphism :: TypedGraph a b -> Set (EquivalenceClass TypedNode) -> Set (EquivalenceClass TypedEdge) -> TypedGraphMorphism a b
initCoequalizerMorphism b nodeEquivalences edgeEquivalences = addEdges
  where
    x = GM.empty G.empty (typeGraph b)
    h = buildTypedGraphMorphism b x (GM.empty (domain b) (domain x))
    addNodes = DS.foldr addNode h nodeEquivalences
    addEdges = DS.foldr addEdge addNodes edgeEquivalences

calculateCoproduct' :: TypedGraph a b -> TypedGraph a b -> (TypedGraphMorphism a b, TypedGraphMorphism a b)
calculateCoproduct' a b = (ha',hb')
  where
    coproductObject = Prelude.foldr calculateCoproductObject emptyObject maps
    emptyObject = GM.empty G.empty (typeGraph a)
    ha = buildTypedGraphMorphism a coproductObject (GM.empty (domain a) (domain coproductObject))
    hb = buildTypedGraphMorphism b coproductObject (GM.empty (domain b) (domain coproductObject))
    ha' = addCoproductMorphisms (head maps) ha
    hb' = addCoproductMorphisms (head $ tail maps) hb
    labels = relablingFunctions [a,b] (0,0) []
    maps = zip [a,b] labels

calculateNCoproduct' :: NE.NonEmpty (TypedGraph a b) -> [TypedGraphMorphism a b]
calculateNCoproduct' gs' = zipWith addCoproductMorphisms maps allMorphisms
  where
    gs = NE.toList gs'
    tg = typeGraph (head gs)
    emptyObject = GM.empty G.empty tg
    coproductObject = Prelude.foldr calculateCoproductObject emptyObject maps
    buildMorphism graph = buildTypedGraphMorphism graph coproductObject (GM.empty (domain graph) (domain coproductObject))
    allMorphisms = Prelude.map buildMorphism gs
    labels = relablingFunctions gs (0,0) []
    maps = zip gs labels

addCoproductMorphisms :: (TypedGraph a b, RelabelFunction) -> TypedGraphMorphism a b -> TypedGraphMorphism a b
addCoproductMorphisms (original, relabel) morph = addEdges
  where
    addNodes = Prelude.foldr updateN morph graphNodes
    addEdges = Prelude.foldr updateE addNodes graphEdges
    nodeName = fst relabel
    edgeName = snd relabel
    graphNodes = nodesWithType original
    graphEdges = edgesWithType original
    updateN (n1,t) = updateNodeRelation n1 (nodeName n1) t
    updateE (e1,_,_,_) = updateEdgeRelation e1 (edgeName e1)

calculateCoproductObject :: (TypedGraph a b, RelabelFunction) -> TypedGraph a b -> TypedGraph a b
calculateCoproductObject (original,relabel) target = addEdges
  where
    addNodes = Prelude.foldr createNewNode target newNodes
    addEdges = Prelude.foldr createNewEdge addNodes newEdges
    originalNodes = nodesWithType original
    newNodes = Prelude.map newNode originalNodes
    newNode (n,nt) = (fst relabel n, nt)
    createNewNode (n,nt) = GM.createNodeOnDomain n nt
    originalEdges = edgesWithType original
    newEdges = Prelude.map newEdge originalEdges
    newEdge (e,s,t,et) = (snd relabel e, fst relabel s, fst relabel t, et)
    createNewEdge (e,s,t,et) = GM.createEdgeOnDomain e s t et

relablingFunctions :: [TypedGraph a b] -> (NodeId, EdgeId) -> [RelabelFunction] -> [RelabelFunction]
relablingFunctions [] _ functions = functions
relablingFunctions (g:gs) (nodeSeed, edgeSeed) functions =
  relablingFunctions gs (nextNode g + nodeSeed, nextEdge g + edgeSeed) (functions ++ [((+) nodeSeed, (+) edgeSeed)])
  where
    ns g = nodes (untypedGraph g)
    es g = edges (untypedGraph g)
    nextNode g = if Prelude.null (ns g) then 1 else maximum (ns g) + 1
    nextEdge g = if Prelude.null (es g) then 1 else maximum (es g) + 1

createNodeNEquivalences :: [TypedGraphMorphism a b] -> Set (EquivalenceClass TypedNode)
createNodeNEquivalences fs = nodesOnX
  where
    representant = head fs
    equivalentNodes (n,nt) = fromList $ Prelude.map (\f -> (fromJust $ applyNode f n,nt)) fs
    nodesFromA = fromList $ nodesWithType (getDomain representant)
    nodesToGluingOnB = DS.map equivalentNodes nodesFromA
    initialNodesOnX = maximumDisjointClass (nodesWithType (getCodomain representant))
    nodesOnX = enaryConstruct nodesToGluingOnB initialNodesOnX

createEdgeNEquivalences :: [TypedGraphMorphism a b] -> Set (EquivalenceClass TypedEdge)
createEdgeNEquivalences fs = edgesOnX
  where
    representant = head fs
    equivalentEdges (e,s,t,et) = fromList $ Prelude.map (\f -> (fromJust $ applyEdge f e, fromJust $ applyNode f s, fromJust $ applyNode f t,et)) fs
    edgesFromA = fromList $ edgesWithType (getDomain representant)
    edgesToGluingOnB = DS.map equivalentEdges edgesFromA
    initialEdgesOnX = maximumDisjointClass (edgesWithType (getCodomain representant))
    edgesOnX = enaryConstruct edgesToGluingOnB initialEdgesOnX

createNodeEquivalences :: TypedGraphMorphism a b -> TypedGraphMorphism a b -> Set (EquivalenceClass TypedNode)
createNodeEquivalences f g = nodesOnX
  where
    equivalentNodes (n,nt) = ((fromJust $ applyNode f n,nt), (fromJust $ applyNode g n,nt))
    nodesFromA = fromList $ nodesWithType (getDomain f)
    nodesToGluingOnB = DS.map equivalentNodes nodesFromA
    initialNodesOnX = maximumDisjointClass (nodesWithType (getCodomain f))
    nodesOnX = binaryConstruct nodesToGluingOnB initialNodesOnX

createEdgeEquivalences :: TypedGraphMorphism a b -> TypedGraphMorphism a b -> Set (EquivalenceClass TypedEdge)
createEdgeEquivalences f g = edgesOnX
  where
    equivalentEdges (e,s,t,et) =
      ((fromJust $ applyEdge f e, mapByF s, mapByF t,et), (fromJust $ applyEdge g e,mapByG s,mapByG t,et))
    mapByF = fromJust . applyNode f
    mapByG = fromJust . applyNode g
    edgesFromA = fromList $ edgesWithType (getDomain f)
    edgesToGluingOnB = DS.map equivalentEdges edgesFromA
    initialEdgesOnX = maximumDisjointClass (edgesWithType (getCodomain f))
    edgesOnX = binaryConstruct edgesToGluingOnB initialEdgesOnX

addNode :: EquivalenceClass TypedNode -> TypedGraphMorphism a b -> TypedGraphMorphism a b
addNode nodes h
  | DS.null nodes = h
  | otherwise = buildNodeMaps (createNodeOnCodomain n2 tp h) n2 nodes
  where
    (n2, tp) = getElem nodes

buildNodeMaps :: TypedGraphMorphism a b -> NodeId -> EquivalenceClass TypedNode -> TypedGraphMorphism a b
buildNodeMaps h nodeInX nodes
  | DS.null nodes = h
  | otherwise = buildNodeMaps h' nodeInX nodes'
    where
      (nodeInA, tp) = getElem nodes
      h' = updateNodeRelation nodeInA nodeInX tp h
      nodes' = getTail nodes

addEdge :: EquivalenceClass TypedEdge -> TypedGraphMorphism a b -> TypedGraphMorphism a b
addEdge edges h
  | DS.null edges = h
  | otherwise = buildEdgeMaps (createEdgeOnCodomain e2 s2 t2 tp h) e2 edges
  where
    (e2, s, t, tp) = getElem edges
    s2 = fromJust $ applyNode h s
    t2 = fromJust $ applyNode h t

buildEdgeMaps :: TypedGraphMorphism a b -> EdgeId -> EquivalenceClass TypedEdge -> TypedGraphMorphism a b
buildEdgeMaps h edgeInX edges
  | DS.null edges = h
  | otherwise = buildEdgeMaps h' edgeInX edges'
    where
      (edgeInA, _, _, _) = getElem edges
      h' = updateEdgeRelation edgeInA edgeInX h
      edges' = getTail edges