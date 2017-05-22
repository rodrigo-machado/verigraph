module Data.GraphPartition.ToVerigraph
( mountTypedGraphMorphisms
) where

{-Converts from GraphPartition to Verigraph structures-}
-- TODO: break this module in two, one for graphs and other for typed graphs?
import           Data.GraphPartition      as GP
import qualified Data.Graphs              as G
import qualified Data.Graphs.Morphism     as GM
import           Data.TypedGraph          as TG
import qualified Data.TypedGraph.Morphism as TGM

-- | For two typed graphs and a EpiPair (in GraphPartition format) return two TypedGraphMorphism for the graph in verigraph format
mountTypedGraphMorphisms :: TypedGraph a b -> TypedGraph a b -> GP.GraphPartition -> (TGM.TypedGraphMorphism a b, TGM.TypedGraphMorphism a b)
mountTypedGraphMorphisms tg1 tg2 graphPartition = (mountTGM True tg1, mountTGM False tg2)
  where
    typeGraph = TG.typeGraph tg1
    typedGraph = mountTypedGraph graphPartition typeGraph
    mountTGM side match = TGM.buildTypedGraphMorphism match typedGraph (mountMapping side graphPartition match)

mountGraph :: GP.GraphPartition -> G.Graph (Maybe a) (Maybe b)
mountGraph (nodes,edges) = G.build nodes' edges'
  where
    nodes' = map (\(n:_) -> GP.nodeId n) nodes
    edges' = map (\(e:_) -> (GP.edgeId e, nodeSrc e, nodeTgt e)) edges
    nodeSrc e = GP.nodeId $ GP.getNode (nodeNameAndSource (GP.source e)) nodes
    nodeTgt e = GP.nodeId $ GP.getNode (nodeNameAndSource (GP.target e)) nodes
    nodeNameAndSource node = (nodeName node, nodeFromLeft node)

mountTypedGraph :: GP.GraphPartition -> G.Graph (Maybe a) (Maybe b) -> TypedGraph a b
mountTypedGraph graphPartition typeGraph = GM.buildGraphMorphism graph typeGraph nodes edges
  where
    nodes = map (\(n:_) -> (GP.nodeId n, GP.nodeType n)) (fst graphPartition)
    edges = map (\(e:_) -> (GP.edgeId e, GP.edgeType e)) (snd graphPartition)
    graph = mountGraph graphPartition

mountMapping :: Bool -> GP.GraphPartition -> GM.GraphMorphism (Maybe a) (Maybe b) -> GM.GraphMorphism (Maybe a) (Maybe b)
mountMapping side g@(nodes,edges) m = GM.buildGraphMorphism (GM.domainGraph m) (mountGraph g) nods edgs
  where
    nods = map (\(G.NodeId n) -> (n, nodeId n)) (G.nodeIds (GM.domainGraph m))
    nodeId n = GP.nodeId $ head $ getListContainingNode (side,n) nodes
    edgs = map (\(G.EdgeId e) -> (e, edgeId e)) (G.edgeIds (GM.domainGraph m))
    edgeId e = GP.edgeId $ head $ getListContainingEdge (side,e) edges

-- | Returns the list which Node is in [[Node]]
getListContainingNode :: (Bool,Int) -> [[Node]] -> [Node]
getListContainingNode p@(side,a) (x:xs) =
  if any (\(Node _ name _ _ src) -> name == a && src == side) x then x else getListContainingNode p xs
getListContainingNode _ [] = error "error when mounting overlapping pairs (getListContainingNode)" -- There must be at least one equivalence class of nodes


-- | Returns the list which Edge is in [[Edge]]
getListContainingEdge :: (Bool,Int) -> [[Edge]] -> [Edge]
getListContainingEdge p@(side,a) (x:xs) = if any (\e -> (label e == a) && (edgeFromLeft e == side)) x then x else getListContainingEdge p xs
getListContainingEdge _ [] = error "error when mounting overlapping pairs (getListContainingNode)" -- There must be at least one equivalence class of edges