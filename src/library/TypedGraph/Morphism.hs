{-# OPTIONS_GHC -fno-warn-orphans #-}
module TypedGraph.Morphism (
      TypedGraphMorphism
    , idMap
    , isPartialInjective
    , invert
    , nodesFromDomain
    , edgesFromDomain
    , nodesFromCodomain
    , edgesFromCodomain
    , graphDomain
    , graphCodomain
    , mapping
    , MC.applyNode
    , MC.applyEdge
    , buildTypedGraphMorphism
    , removeNodeFromDomain
    , removeEdgeFromDomain
    , removeNodeFromCodomain
    , removeEdgeFromCodomain
    , applyNodeUnsafe
    , applyEdgeUnsafe
    , createEdgeOnDomain
    , createEdgeOnCodomain
    , createNodeOnDomain
    , createNodeOnCodomain
    , updateEdgeRelation
    , updateNodeRelation
    , orphanTypedNodes
    , orphanTypedEdges
) where

import           Abstract.AdhesiveHLR
import           Abstract.Morphism                               as M
import           Data.List                                       as L
import           Data.Maybe
import           Graph.Graph                                     as G
import qualified Graph.GraphMorphism                             as GM
import           TypedGraph.Graph
import           TypedGraph.MorphismCore                         as MC
import           TypedGraph.Partitions.GraphPartition            (generateGraphPartitions)
import           TypedGraph.Partitions.GraphPartitionToVerigraph (mountTypedGraphMorphisms)
import           TypedGraph.Partitions.VerigraphToGraphPartition (createDisjointUnion,
                                                                  createSatisfyingNacsDisjointUnion)


-- | Return the domain graph
graphDomain :: TypedGraphMorphism a b -> Graph a b
graphDomain = untypedGraph . domain

-- | Return the codomain graph
graphCodomain :: TypedGraphMorphism a b -> Graph a b
graphCodomain = untypedGraph . codomain

-- | Given a @TypedGraphMorphism@ @__t__@and a node @n@ in the domain of @__t__@, return the node in the image
--of @t@ to which @n@ gets mapped or error in the case of undefined
applyNodeUnsafe :: TypedGraphMorphism a b -> G.NodeId -> G.NodeId
applyNodeUnsafe m n = fromMaybe (error "Error, apply node in a non total morphism") $ MC.applyNode m n

-- | Given a @TypedGraphMorphism@ @__t__@and an edge @e@ in the domain of @__t__@, return the edge in the image
--of @t@ to which @e@ gets mapped or error in the case of undefined
applyEdgeUnsafe :: TypedGraphMorphism a b -> G.EdgeId -> G.EdgeId
applyEdgeUnsafe m e = fromMaybe (error "Error, apply edge in a non total morphism") $ MC.applyEdge m e

-- | Given a @TypedGraphMorphism@, return its orphan nodes
orphanTypedNodes :: TypedGraphMorphism a b -> [G.NodeId]
orphanTypedNodes tgm = GM.orphanNodes (mapping tgm)

-- | Given a @TypedGraphMorphism@, return its orphan edges
orphanTypedEdges :: TypedGraphMorphism a b -> [G.EdgeId]
orphanTypedEdges tgm = GM.orphanEdges (mapping tgm)

-- | Invert a typed graph morphism
invert :: TypedGraphMorphism a b -> TypedGraphMorphism a b
invert tgm =
  TypedGraphMorphism { getDomain = codomain tgm
                     , getCodomain = codomain tgm
                     , mapping = GM.invertGraphMorphism (mapping tgm)
                     }

-- | This function adds an edge e1 (with source s1, target t1 and type tp) to the domain of the typed graph morphism, and associate it to e2
--   It assumes s1, t1, e2, tp already exist, and that e1 does not exist.
createEdgeOnDomain :: G.EdgeId -> G.NodeId -> G.NodeId -> G.EdgeId -> G.EdgeId -> TypedGraphMorphism a b -> TypedGraphMorphism a b
createEdgeOnDomain e1 s1 t1 tp e2 tgm =
  tgm { getDomain = GM.createEdgeOnDomain e1 s1 t1 tp (domain tgm)
      , mapping = GM.createEdgeOnDomain e1 s1 t1 e2 (mapping tgm)
      }

-- | This function adds an edge e2 (with source s2, target t2 and type tp) to the codomain of the typed graph morphism
--   It assumes s2, t2, tp already exist, and that e2 does not exist.
createEdgeOnCodomain :: G.EdgeId -> G.NodeId -> G.NodeId -> G.EdgeId -> TypedGraphMorphism a b -> TypedGraphMorphism a b
createEdgeOnCodomain e2 s2 t2 tp tgm =
  tgm { getCodomain = GM.createEdgeOnDomain e2 s2 t2 tp (codomain tgm)
      , mapping = GM.createEdgeOnCodomain e2 s2 t2 (mapping tgm)
      }

-- | This function adds a node n1 (type tp) to the domain of the typed graph morphism, and associate it to n2
--   It assumes n2 and tp already exist, and that n1 does not exist.
createNodeOnDomain :: G.NodeId -> G.NodeId -> G.NodeId -> TypedGraphMorphism a b -> TypedGraphMorphism a b
createNodeOnDomain n1 tp n2 tgm =
  tgm { getDomain = GM.createNodeOnDomain n1 tp (domain tgm)
      , mapping = GM.createNodeOnDomain n1 n2 (mapping tgm)
      }

-- | This function adds a node n2 (type tp) to the codomain of the typed graph morphism
--   It assumes tp already exist, and that n2 does not exist.
createNodeOnCodomain :: G.NodeId -> G.NodeId -> TypedGraphMorphism a b -> TypedGraphMorphism a b
createNodeOnCodomain n2 tp tgm =
  tgm { getCodomain = GM.createNodeOnDomain n2 tp (codomain tgm)
      , mapping = GM.createNodeOnCodomain n2 (mapping tgm)
      }

-- | updates a typed graph morphism, mapping node n1 to node n2. It assumes both nodes already exist.
updateNodeRelation :: G.NodeId -> G.NodeId -> G.NodeId -> TypedGraphMorphism a b -> TypedGraphMorphism a b
updateNodeRelation n1 n2 tp tgm =
  TypedGraphMorphism { getDomain = GM.updateNodeRelation n1 tp (domain tgm)
                     , getCodomain = GM.updateNodeRelation n2 tp (codomain tgm)
                     , mapping = GM.updateNodeRelation n1 n2 (mapping tgm)
                     }

-- | updates a typed graph morphism, mapping edge e1 to edge e2. It assumes both edges already exist.
updateEdgeRelation :: G.EdgeId -> G.EdgeId -> TypedGraphMorphism a b -> TypedGraphMorphism a b
updateEdgeRelation e1 e2 tgm =
  tgm { mapping = GM.updateEdgeRelation e1 e2 (mapping tgm) }

-- | Remove a node from the domain of a typed graph morphism
removeNodeFromDomain :: G.NodeId -> TypedGraphMorphism a b -> TypedGraphMorphism a b
removeNodeFromDomain n tgm =
  tgm { getDomain = GM.removeNodeFromDomain n (domain tgm)
      , mapping = GM.removeNodeFromDomain n (mapping tgm)
      }

-- | Remove an edge from the domain of a typed graph morphism
removeEdgeFromDomain :: G.EdgeId -> TypedGraphMorphism a b -> TypedGraphMorphism a b
removeEdgeFromDomain e tgm =
  tgm { getDomain = GM.removeEdgeFromDomain e (domain tgm)
      , mapping = GM.removeEdgeFromDomain e (mapping tgm)
      }

-- | Remove a node from the codomain of a typed graph morphism
removeNodeFromCodomain :: G.NodeId -> TypedGraphMorphism a b -> TypedGraphMorphism a b
removeNodeFromCodomain n tgm =
  tgm { getCodomain = GM.removeNodeFromDomain n (codomain tgm)
      , mapping = GM.removeNodeFromCodomain n (mapping tgm)
      }

-- | Remove an edge from the domain of a typed graph morphism
removeEdgeFromCodomain :: G.EdgeId -> TypedGraphMorphism a b -> TypedGraphMorphism a b
removeEdgeFromCodomain e tgm =
  tgm { getCodomain = GM.removeEdgeFromDomain e (codomain tgm)
      , mapping = GM.removeEdgeFromCodomain e (mapping tgm) }

-- | Test if a @nac@ is partial injective (injective out of @m@)
isPartialInjective :: TypedGraphMorphism a b -> TypedGraphMorphism a b -> Bool
isPartialInjective nac q = GM.isPartialInjective (mapping nac) (mapping q)

-- | Creates a TypedGraphMorphism mapping the same elements of theirs codomains, from @tgm1@ to @tgm2@
idMap :: GM.GraphMorphism a b -> GM.GraphMorphism a b -> TypedGraphMorphism a b
idMap gm1 gm2 =
  buildTypedGraphMorphism gm1 gm2 edgesUpdate
    where
      initialGraph = GM.empty (domain gm1) (domain gm2)
      nodesUpdate = foldr (\n -> GM.updateNodes n n) initialGraph (G.nodes (domain gm1))
      edgesUpdate = foldr (\e -> GM.updateEdges e e) nodesUpdate (G.edges (domain gm2))

instance AdhesiveHLR (TypedGraphMorphism a b) where

  {-
          r
      K──────▶R
      │       │
     k│   =   │
      ▼       ▼
      D──────▶G'

     PO algorithm:
     1. invert r
     2. compose k and r^-1
     3. create node table  (R -> G')
     5. create edge table  (R -> G')
     4. associate nodes
     6. associate edges
  -}

  calculatePushout k r =
    let
        kr = compose (invert r) k                                 -- invert r and compose with k, obtain kr : R -> D
        createdNodes = orphanTypedNodes r                                -- nodes in R to be created
        createdEdges = orphanTypedEdges r                                -- edges in R to be created
        nodeTable    = zip createdNodes (newTypedNodes $ codomain kr) -- table mapping NodeIds in R to NodeIds in G'
        edgeTable    = zip createdEdges (newTypedEdges $ codomain kr) -- table mapping EdgeIds in R to EdgeIds in G'

        -- generate new node instances in G', associating them to the "created" nodes in R
        kr'          = foldr (\(a,b) tgm -> let tp = fromJust $ GM.applyNode (domain kr) a
                                            in updateNodeRelation a b tp tgm)
                             kr
                             nodeTable

        -- query the instance graphs R
        typemor = domain         kr'                     -- typemor is the typed graph (R -> T)
        g       = domain         typemor                 -- g  is the instance graph R
        mp      = mapping        kr'                     -- mp is the mapping of kr'  : (R -> D'), where D' = D + new nodes
        s1 e = fromJust $ G.sourceOf g e                     -- obtain source of e in R
        t1 e = fromJust $ G.targetOf g e                     -- obtain target of e in R
        s2 e = fromJust $ GM.applyNode mp (s1 e)             -- obtain source of m'(e) in G'
        t2 e = fromJust $ GM.applyNode mp (t1 e)             -- obtain target of m'(e) in G'
        tp e = fromJust $ GM.applyEdge typemor e             -- obtain type of e in R

        -- generate new edge table with new information
        edgeTable' = map (\(e,e2) -> (e, s1 e, t1 e, e2, s2 e, t2 e, tp e)) edgeTable

        -- create new morphism adding all edges
        kr''      = foldr (\(a,_,_,b,sb,tb,tp) tgm -> updateEdgeRelation a b (createEdgeOnCodomain b sb tb tp tgm) )
                          kr'
                          edgeTable'
    in (kr'', idMap (codomain k) (codomain kr''))

  {-
     PO complement algorithm:
     1. compose l and m generating ml
     2. query edges for deletion in the codomain of ml
     2. query nodes for deletion in the codomain of ml
     3. delete all edges
     4. delete all nodes
  -}
  calculatePushoutComplement m l =
    let ml       = compose l m                                                         -- compose l and m obtaining ml
        delEdges = mapMaybe (GM.applyEdge $ mapping m) (orphanTypedEdges l) -- obtain list of edges to be deleted in G
        delNodes = mapMaybe (GM.applyNode $ mapping m) (orphanTypedNodes l) -- obtain list of nodes to be deleted in G
        k        = foldr removeNodeFromCodomain                                          -- delete all edges, then all nodes from ml
                       (foldr removeEdgeFromCodomain ml delEdges)
                           delNodes
    in (k, idMap (codomain k) (codomain m))

  monomorphicPullback f g = (delNodesFromF', delNodesFromG')
    where
      f' = invert f
      g' = invert g
      nodes = nodesFromDomain f'
      edges = edgesFromDomain f'
      knodes = filter (\n -> isJust (MC.applyNode f' n) && isJust (MC.applyNode g' n)) nodes
      kedges = filter (\e -> isJust (MC.applyEdge f' e) && isJust (MC.applyEdge g' e)) edges
      delNodes = nodes \\ knodes
      delEdges = edges \\ kedges
      delEdgesFromF' = foldr removeEdgeFromDomain f' delEdges
      delNodesFromF' = foldr removeNodeFromDomain delEdgesFromF' delNodes
      delEdgesFromG' = foldr removeEdgeFromDomain g' delEdges
      delNodesFromG' = foldr removeNodeFromDomain delEdgesFromG' delNodes

  hasPushoutComplement (Monomorphism, g) (_, f) =
    satisfiesDanglingCondition f g

  hasPushoutComplement (_, g) (_, f) =
    satisfiesDanglingCondition f g && satisfiesIdentificationCondition f g


---- Gluing Conditions

-- | Return True if the match @m@ satifies the identification condition for existence of
-- a pushout complement
satisfiesIdentificationCondition :: TypedGraphMorphism a b -> TypedGraphMorphism a b -> Bool
satisfiesIdentificationCondition l m =
  all (==True) (nodesDelPres ++ edgesDelPres)

  where
    nodesDelPres =
      map (satsDelItemsAux l m nodesFromDomain MC.applyNode) (nodesFromCodomain m)

    edgesDelPres =
      map (satsDelItemsAux l m edgesFromDomain MC.applyEdge) (edgesFromCodomain m)

    -- | Check if in the match @m@, a element @n@ is deleted and at same time have another incident element on himself
    satsDelItemsAux :: Eq t => TypedGraphMorphism a b -> TypedGraphMorphism a b
                             -> (TypedGraphMorphism a b -> [t])
                             -> (TypedGraphMorphism a b -> t -> Maybe t)
                             -> t -> Bool
    -- if just one element is incident in @n@, so it is not deleted and preserved at same match
    -- otherwise, is needed to verify if in the list of incident elements, if some is deleting @n@
    -- if two or more incident elements delete the element @n@ return False
    satsDelItemsAux l m dom apply n =
      (length incident <= 1) || not someIsDel

      where
        incident = [a | a <- dom m, apply m a == Just n]
        ruleDel = apply (invert l)
        someIsDel = Nothing `elem` map ruleDel incident

-- | Return True if do not exist dangling edges by the derivation of @r@ with match @m@
satisfiesDanglingCondition :: TypedGraphMorphism a b -> TypedGraphMorphism a b -> Bool
satisfiesDanglingCondition leftR m = all (==True) (concat incidentEdgesDel)
    where
        l = graphDomain m
        g = graphCodomain m
        matchedLInG = mapMaybe (MC.applyNode m) (nodes l)
        delNodes = filter (checkDeletion leftR m MC.applyNode nodesFromDomain) matchedLInG
        hasIncEdges = map (incidentEdges g) delNodes
        verEdgeDel = map (checkDeletion leftR m MC.applyEdge edgesFromDomain)
        incidentEdgesDel = map verEdgeDel hasIncEdges

-- | Return True if the element @n@ is deleted by the rule @rule@ with match @m@
-- assumes that @n@ has type NodeId or EdgeId
-- @n@ not is necessarily element of G (the graph matched by @m@), in this case return False
-- @list@ must get all element in the domain of @m@
checkDeletion :: Eq t => TypedGraphMorphism a b -> TypedGraphMorphism a b
                  -> (TypedGraphMorphism a b -> t -> Maybe t)
                  -> (TypedGraphMorphism a b -> [t])
                  -> t -> Bool
checkDeletion l m apply list n = inL && not isPreserv
    where
        inL = any (\x -> apply m x == Just n) (list m)
        kToG = compose l m
        isPreserv = any (\x -> apply kToG x == Just n) (list kToG)

instance EpiPairs (TypedGraphMorphism a b) where
  -- | Create all jointly surjective pairs of @m1@ and @m2@
  createJointlyEpimorphicPairs inj m1 m2 = map (mountTypedGraphMorphisms m1 m2) (generateGraphPartitions (createDisjointUnion (m1,inj) (m2,inj)))

  createAllSubobjects inj m1 = map fst part
    where
      m2 = GM.buildGraphMorphism G.empty G.empty [] []
      part = map (mountTypedGraphMorphisms m1 m2) (generateGraphPartitions (createDisjointUnion (m1,inj) (m2,inj)))

  createJointlyEpimorphicPairsFromNAC conf r nac =
    map (mountTypedGraphMorphisms r (codomain nac)) (generateGraphPartitions (createSatisfyingNacsDisjointUnion (r, matchInj) (nac, nacInj)))

    where
      matchInj =
        matchRestriction conf == MonoMatches

      nacInj =
        nacSatisfaction conf == MonomorphicNAC

  -- | Create all jointly surjective pairs of @m1@ and @m2@ that commutes,
  -- considering they have same domain
  -- and flags indicating the injective of each morphism
  calculateCommutativeSquaresAlongMonomorphism (m1,inj1) (m2,inj2) = filt
    where
      cod1 = codomain m1
      cod2 = codomain m2
      allPairs = map (mountTypedGraphMorphisms cod1 cod2) (generateGraphPartitions (createDisjointUnion (cod1,inj1) (cod2,inj2)))
      filt = filter (\(x,y) -> compose m1 x == compose m2 y) allPairs


instance FindMorphism (TypedGraphMorphism a b) where
  findMorphisms = matches'
  partialInjectiveMatches = partialInjectiveMatches'

--ALIAS OF MOST USED FUNCTIONS --

-- TODO: following functions should be part of the Graph interface
srcE, tgtE :: Graph a b -> EdgeId -> NodeId
srcE gm e = fromJust $ G.sourceOf gm e
tgtE gm e = fromJust $ G.targetOf gm e

-- TODO: following function should be part of TypedGraph interface
typeN :: GM.GraphMorphism a b -> NodeId -> NodeId
typeN gm n = fromMaybe (error "NODE NOT TYPED") $ GM.applyNode gm n

-- TODO: following function should be part of TypedGraph interface
typeE :: GM.GraphMorphism a b -> EdgeId -> EdgeId
typeE gm e = fromMaybe (error "EDGE NOT TYPED") $ GM.applyEdge gm e

---------------------------------------------------------------------------------

-- | Finds matches __/q/__ .
--
--   Partially injective. (Injective out of __/m/__)
partialInjectiveMatches' :: TypedGraphMorphism a b -> TypedGraphMorphism a b
               -> [TypedGraphMorphism a b]
partialInjectiveMatches' nac match =
  do
    let
      --NODES AND EDGES FROM lhs OF A RULE
      nodesL = nodes $ domain $ domain match
      edgesL = edges $ domain $ domain match

      --PRÉ-BUILD @q@
      domQ   = codomain nac
      codQ   = codomain match
      mapQ   = GM.empty (domain domQ) (domain codQ)
      q      = buildTypedGraphMorphism domQ codQ mapQ

      --VERIFY EDGES MAPPING N <- l AND L -> G AND BUILD A N -> G
      --PARTIAL EDGES MORPHISM
      composeEdges :: TypedGraphMorphism a b -> [G.EdgeId]
                   -> Maybe (TypedGraphMorphism a b)
      composeEdges tgm [] = Just tgm
      composeEdges tgm (h:t) =
        do
          let edgeNac = fromMaybe (error "EDGE NOT MAPPING L -> N") $
                                  MC.applyEdge nac h
              edgeG   = fromMaybe (error "EDGE NOT MAPPING L -> G") $
                                  MC.applyEdge match h

              dom     = domain tgm
              cod     = codomain tgm

              tgm' = if (typeE dom edgeNac == typeE cod edgeG) &&
                        (isNothing (MC.applyEdge tgm edgeNac) ||
                         (MC.applyEdge tgm edgeNac == Just edgeG))
                     then Just $ buildTypedGraphMorphism dom cod
                                 (GM.updateEdges edgeNac edgeG $ mapping tgm)
                     else Nothing

          case tgm' of
            Just tgm'' -> composeEdges tgm'' t
            Nothing    -> Nothing

      --VERIFY NODES MAPPING N <- l AND L -> G AND BUILD A N -> G
      --PARTIAL NODES MORPHISM
      composeNodes :: TypedGraphMorphism a b -> [G.NodeId]
                   -> Maybe (TypedGraphMorphism a b)
      composeNodes tgm [] = Just tgm
      composeNodes tgm (h:t) =
        do
          let nodeNac = fromMaybe (error "NODE NOT MAPPED L->N") $
                        MC.applyNode nac h
              nodeG   = fromMaybe (error "NODE NOT MAPPED L->G") $
                        MC.applyNode match h

              dom     = domain tgm
              cod     = codomain tgm
              m       = mapping tgm

              tgm' = if (typeN dom nodeNac == typeN cod nodeG) &&
                        (isNothing (MC.applyNode tgm nodeNac) ||
                         (MC.applyNode tgm nodeNac == Just nodeG))
                     then Just $ buildTypedGraphMorphism dom cod
                                 (GM.updateNodes nodeNac nodeG m)
                     else Nothing
          case tgm' of
            Just tgm'' -> composeNodes tgm'' t
            Nothing    -> Nothing

      --PRE-BUILD EDGES MAPPING OF @q@
      q' = composeEdges q edgesL

      --PRE-BUILD NODES MAPPING OF @q@
      q'' = case q' of
        Just q1 -> composeNodes q1 nodesL
        Nothing -> Nothing

    case q'' of
      Nothing -> []
      Just q2 -> buildMappings Monomorphism nodesSrc edgesSrc nodesTgt edgesTgt q2
        where
          --DELETE FROM QUEUE ALREADY MAPPED SOURCE NODES (NODES FROM NAC)
          nodesSrc = filter (notMappedNodes q2) (nodes $ domain domQ)
            where
              notMappedNodes tgm node = isNothing $ MC.applyNode tgm node
          --DELETE FROM QUEUE ALREADY MAPPED SOURCE EDGES (EDGES FROM NAC)
          edgesSrc = filter (notMappedEdges q2) (edges $ domain domQ)
            where
              notMappedEdges tgm edge = isNothing $ MC.applyEdge tgm edge

          --REMOVE FROM TARGET LIST NODES ALREADY MAPPED (NODES FROM G)
          nodesTgt = orphanTypedNodes q2

          --REMOVE FROM TARGET LIST EDGES ALREADY MAPPED (EDGES FROM G)
          edgesTgt = orphanTypedEdges q2

---------------------------------------------------------------------------------

-- | Finds matches __/m/__
--
--   Injective, surjective, isomorphic or all possible matches
matches' :: MorphismType -> GM.GraphMorphism a b-> GM.GraphMorphism a b
        -> [TypedGraphMorphism a b]
matches' prop graph1 graph2 =
  buildMappings prop nodesSrc edgesSrc nodesTgt edgesTgt tgm
  where
    nodesSrc = nodes $ domain graph1
    nodesTgt = nodes $ domain graph2
    edgesSrc = edges $ domain graph1
    edgesTgt = edges $ domain graph2

    d   = graph1
    c   = graph2
    m   = GM.empty (domain graph1) (domain graph2)
    tgm = buildTypedGraphMorphism d c m




---------------------------------------------------------------------------------

buildMappings :: MorphismType -> [G.NodeId] -> [G.EdgeId] -> [G.NodeId] -> [G.EdgeId]
              -> TypedGraphMorphism a b -> [TypedGraphMorphism a b]

--IF NO HAS FREE NODES OR FREE EDGES TO MAP, RETURN THE FOUND MORPHISMO
buildMappings prop [] [] nodesT edgesT tgm =
      case prop of
        GenericMorphism -> all
        Monomorphism    -> all
        Epimorphism     -> epimorphism
        Isomorphism     -> isomorphism
      where
        all = return tgm

        isomorphism | L.null nodesT && L.null edgesT = return tgm
                    | otherwise = []

        epimorphism | L.null (orphanTypedNodes tgm) &&
                      L.null (orphanTypedEdges tgm) = return tgm
                    | otherwise = []

---------------------------------------------------------------------------------

--IF HAS FREE NODES, MAP GenericMorphism FREE NODES TO GenericMorphism DESTINATION NODES
buildMappings prop (h:t) [] nodesT edgesT tgm
  | L.null nodesT = []
  | otherwise  = do
      y <- nodesT

      --MAP FREE NODES TO GenericMorphism TYPE COMPATIBLE DESTINATION NODES
      let tgmN = updateNodesMapping h y nodesT tgm

      case tgmN of
        Just tgm' ->
          --CHOSE BETWEEN INJECTIVE OR NOT
          case prop of
            GenericMorphism -> all
            Monomorphism    -> monomorphism
            Epimorphism     -> all
            Isomorphism     -> monomorphism
          where
            monomorphism = buildMappings prop t [] nodesT' edgesT tgm'
            all          = buildMappings prop t [] nodesT  edgesT tgm'
            --REMOVE THE TARGET NODES MAPPED (INJECTIVE MODULE)
            nodesT'   = delete y nodesT
        Nothing  -> []

---------------------------------------------------------------------------------

--IF HAS FREE NODES, AND FREE EDGES, VERIFY THE CURRENT STATUS
buildMappings prop nodes (h:t) nodesT edgesT tgm
  | L.null edgesT = []
  | otherwise  =
    do  --VERIFY THE POSSIBILITY OF A MAPPING BETWEEN h AND THE DESTINATION EDGES
      y <- edgesT
      --MAPPING SRC AND TGT NODES
      let tgmN
            | isNothing tgm1 = Nothing
            | otherwise = tgm2
            where tgm1 = updateNodesMapping (srcE d h) (srcE c y) nodesT tgm
                  tgm2 = updateNodesMapping (tgtE d h) (tgtE c y) nodesT' $ fromJust tgm1
                  d = domain $ domain tgm
                  c = domain $ codomain tgm
                  nodesT' = case prop of
                    Monomorphism    -> L.delete (srcE c y) nodesT
                    Isomorphism     -> L.delete (srcE c y) nodesT
                    Epimorphism     -> nodesT
                    GenericMorphism -> nodesT

          --MAPPING SRC EDGE AND TGT EDGE
          tgmE
            | isNothing tgmN = Nothing
            | otherwise = updateEdgesMapping h y edgesT $ fromJust tgmN

      --FOR THE COMPATIBLES MAPPINGS, GO TO THE NEXT STEP
      case tgmE of
        Just tgm' -> do
          let nodes'       = delete (srcE d h) $ delete (tgtE d h) nodes
              d            = domain $ domain tgm
              c            = domain $ codomain tgm
              --REMOVE THE TARGET EDGES AND NODES MAPPED (INJECTIVE MODULE)
              edgesT'      = delete y edgesT
              nodesT'      = delete (srcE c y) $ delete (tgtE c y) nodesT
              monomorphism = buildMappings prop nodes' t nodesT' edgesT' tgm'
              all          = buildMappings prop nodes' t nodesT  edgesT  tgm'
              --CHOSE BETWEEN INJECTIVE OR NOT
          case prop of
            GenericMorphism -> all
            Monomorphism    -> monomorphism
            Epimorphism     -> all
            Isomorphism     -> monomorphism
        Nothing  -> []

---------------------------------------------------------------------------------

-- VALIDATION OF A NODE MAPPING
-- VERIFY IF THE TYPES OF n1 AND n2 ARE COMPATIBLE AND UPDATE MAPPING
updateNodesMapping :: G.NodeId -> G.NodeId -> [G.NodeId] -> TypedGraphMorphism a b
                   -> Maybe (TypedGraphMorphism a b)
updateNodesMapping n1 n2 nodesT tgm =
  do
    let d = domain tgm
        c = codomain tgm
        m = mapping tgm

    if typeN d n1 == typeN c n2 &&
       ((isNothing (MC.applyNode tgm n1) && L.elem n2 nodesT) ||
        MC.applyNode tgm n1 == Just n2)
      then Just $ buildTypedGraphMorphism d c $ GM.updateNodes n1 n2 m
      else Nothing

---------------------------------------------------------------------------------

-- VALIDATION OF A EDGE MAPPING
-- VERIFY IF THE TYPES OF e1 AND e2 ARE COMPATIBLE AND UPDATE MAPPING
updateEdgesMapping :: G.EdgeId -> G.EdgeId -> [G.EdgeId] -> TypedGraphMorphism a b
                   -> Maybe (TypedGraphMorphism a b)
updateEdgesMapping e1 e2 edgesT tgm =
  do
    let d = domain tgm
        c = codomain tgm
        m = mapping tgm

    if typeE d e1 == typeE c e2 &&
       ((isNothing (MC.applyEdge tgm e1) && L.elem e2 edgesT ) ||
        MC.applyEdge tgm e1 == Just e2)
      then Just $ buildTypedGraphMorphism d c (GM.updateEdges e1 e2 m)
      else Nothing
