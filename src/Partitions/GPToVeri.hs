module Partitions.GPToVeri (
   mountTGMBoth
   ) where

{-Converts from GraphPart to Verigraph structures-}

import qualified Abstract.Morphism        as M
import qualified Graph.Graph              as G
import qualified Graph.GraphMorphism      as GM
import qualified Graph.TypedGraphMorphism as TGM
import           Partitions.GraphPart     as GP

-- | For two typed graphs and a EpiPair (in GraphPart format) return two TypedGraphMorphism for the graph in verigraph format
mountTGMBoth :: GM.GraphMorphism a b -> GM.GraphMorphism a b
             -> GP.EqClassGraph
             -> (TGM.TypedGraphMorphism a b, TGM.TypedGraphMorphism a b)
mountTGMBoth l r g = (mountTGM "Left" l, mountTGM "Right" r)
  where
    typeGraph = M.codomain l
    typedG = mountTypeGraph g (mountG g) typeGraph
    mountTGM side match = TGM.typedMorphism match typedG (mountMapping side g match)

mountG :: GP.EqClassGraph -> G.Graph a b
mountG (nodes,edges) = G.build nods edgs
  where
    nods = map (\(n:_) -> GP.nid n) nodes
    edgs = map (\(e:_) -> (GP.eid e, nodeSrc e, nodeTgt e)) edges
    nodeSrc e = GP.nid $ head $ GP.getListNode (nameAndSrc (GP.source e)) nodes
    nodeTgt e = GP.nid $ head $ GP.getListNode (nameAndSrc (GP.target e)) nodes
    nameAndSrc node = (nname node, ngsource node)

mountTypeGraph :: GP.EqClassGraph -> G.Graph a b -> G.Graph a b -> GM.TypedGraph a b
mountTypeGraph gp g typeG = GM.gmbuild g typeG nodes edges
  where
    nodes = map (\(n:_) -> (GP.nid n, GP.ntype n)) (fst gp)
    edges = map (\(e:_) -> (GP.eid e, GP.etype e)) (snd gp)

mountMapping :: String -> GP.EqClassGraph -> GM.GraphMorphism a b -> GM.GraphMorphism a b
mountMapping side g@(nodes,edges) m = GM.gmbuild (M.domain m) (mountG g) nods edgs
  where
    nods = map (\(G.NodeId n) -> (n, nodeId n)) (G.nodes (M.domain m))
    nodeId n = GP.nid $ head $ getListNodeName (side,n) nodes
    edgs = map (\(G.EdgeId e) -> (e, edgeId e)) (G.edges (M.domain m))
    edgeId e = GP.eid $ head $ getListEdgeName (side,e) edges

-- | Returns the list which Node is in [[Node]]
getListNodeName :: (String,Int) -> [[Node]] -> [Node]
getListNodeName p@(side,a) (x:xs) = if any (\(Node _ name _ _ src) -> name == a && src == side) x then x else getListNodeName p xs
getListNodeName _ [] = error "error when mounting overlapping pairs (getListNodeName)" -- There must be at least one equivalence class of nodes


-- | Returns the list which Edge is in [[Edge]]
getListEdgeName :: (String,Int) -> [[Edge]] -> [Edge]
getListEdgeName p@(side,a) (x:xs) = if any (\e -> (label e == a) && (egsource e == side)) x then x else getListEdgeName p xs
getListEdgeName _ [] = error "error when mounting overlapping pairs (getListNodeName)" -- There must be at least one equivalence class of edges
