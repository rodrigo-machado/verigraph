--{-# LANGUAGE TypeFamilies #-}

--import Analysis.ConcurrentRules
import qualified XML.GGXReader        as XML
--import           Abstract.Valid
--import qualified Analysis.CriticalSequence as CS
--import qualified Analysis.CriticalPairs as CP
--import           Partitions.GraphPartitionToVerigraph
--import           Partitions.GraphPart
--import           Partitions.VeriToGP
import           Graph.Graph          as G
--import qualified TypedGraph.GraphRule as GR
import qualified Graph.GraphMorphism  as GM
import           TypedGraph.Morphism  as TGM
--import qualified TypedGraph.GraphGrammar as GG
--import qualified XML.GGXWriter as GW
import           TypedGraph.GraphRule
--import System.Process
--import System.Environment
--import System.Exit
import           Abstract.Morphism



import           Abstract.AdhesiveHLR as RW
import           Abstract.DPO         as RW
--import Data.Matrix
import qualified Data.List            as L
import           Data.Maybe

--import qualified XML.GGXReader as XML

fn :: String
fn = "test/elevator2.ggx"

a :: String -> IO (GM.GraphMorphism a b, GM.GraphMorphism a b)
a fn = do
      prls <- XML.readRules fn
      ptg <- XML.readTypeGraph fn
      let rs = map (XML.instantiateRule (head ptg)) prls
          r1 = rs!!0
          r2 = rs!!1
          pairs = createPairsCodomain True (left r1) (left r2)
          --dgs = Partitions.GraphPart.edges mix2
          inj = filter (\(m1,m2) -> monomorphism m1 && monomorphism m2) pairs
          gluing = filter (\(m1,m2) -> satisfiesGluingConditions True r1 m1 && satisfiesGluingConditions True r2 m2) inj
          delUse = filter (deleteUse r1 r2) gluing
      return (r1,r2)
      --print (fst cp)
      --print k
      --print d1
      return (codomain (head (nacs r1)), codomain (fst (delUse!!1)))

-- | Rule @l@ causes a delete-use conflict with @r@ if rule @l@ deletes something that is used by @r@
-- DeleteUse using a most aproximated algorithm of the categorial diagram
-- Verify the non existence of h21: L2 -> D1 such that d1 . h21 = m2

deleteUse :: GraphRule a b -> GraphRule a b
           -> (TGM.TypedGraphMorphism a b,TGM.TypedGraphMorphism a b)
           -> Bool
deleteUse l _ (m1,m2) = Prelude.null matchD
    where
        (_,d1) = RW.calculatePushoutComplement m1 (left l) --get only the morphism D2 to G
        l2TOd1 = matches GenericMorphism (domain m2) (domain d1)
        matchD = filter (\x -> m2 == compose x d1) l2TOd1


-- TODO: following functions should be part of the Graph interface
srcE, tgtE :: G.Graph a b -> EdgeId -> NodeId
srcE gm e = fromJust $ G.sourceOf gm e
tgtE gm e = fromJust $ G.targetOf gm e

-- TODO: following function should be part of TypedGraph interface
typeN :: GM.GraphMorphism a b -> NodeId -> NodeId
typeN gm n = fromMaybe (error "NODE NOT TYPED") $ GM.applyNode gm n

-- TODO: following function should be part of TypedGraph interface
typeE :: GM.GraphMorphism a b -> EdgeId -> EdgeId
typeE gm e = fromMaybe (error "EDGE NOT TYPED") $ GM.applyEdge gm e







---------------------------------------------------------------------------------

-- | Finds matches __/m/__
--
--   Injective, surjective, isomorphic or all possible matches
matches' :: MorphismType -> GM.GraphMorphism a b-> GM.GraphMorphism a b
        -> [TGM.TypedGraphMorphism a b]
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
    tgm = TGM.typedMorphism d c m




---------------------------------------------------------------------------------

buildMappings :: MorphismType -> [G.NodeId] -> [G.EdgeId] -> [G.NodeId] -> [G.EdgeId]
              -> TGM.TypedGraphMorphism a b -> [TGM.TypedGraphMorphism a b]

--IF NO HAS FREE NODES OR FREE EDGES TO MAP, RETURN THE FOUND MORPHISMO
buildMappings prop [] [] nodesT edgesT tgm =
      case prop of
        GenericMorphism  -> all
        Monomorphism -> all
        Epimorphism  -> epimorphism
        Isomorphism  -> isomorphism
      where
        all = return tgm

        isomorphism | L.null nodesT && L.null edgesT = return tgm
                    | otherwise = []

        epimorphism | L.null (orphanNodesTyped tgm) &&
                      L.null (orphanEdgesTyped tgm) = return tgm
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
            GenericMorphism  -> all
            Monomorphism -> monomorphism
            Epimorphism  -> all
            Isomorphism  -> monomorphism
          where
            monomorphism = buildMappings prop t [] nodesT' edgesT tgm'
            all          = buildMappings prop t [] nodesT  edgesT tgm'
            --REMOVE THE TARGET NODES MAPPED (INJECTIVE MODULE)
            nodesT'   = L.delete y nodesT
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
                    Monomorphism -> L.delete (srcE c y) nodesT
                    Isomorphism  -> L.delete (srcE c y) nodesT
                    Epimorphism  -> nodesT
                    GenericMorphism  -> nodesT

          --MAPPING SRC EDGE AND TGT EDGE
          tgmE
            | isNothing tgmN = Nothing
            | otherwise = updateEdgesMapping h y edgesT $ fromJust tgmN

      --FOR THE COMPATIBLES MAPPINGS, GO TO THE NEXT STEP
      case tgmE of
        Just tgm' -> do
          let nodes'       = L.delete (srcE d h) $ L.delete (tgtE d h) nodes
              d            = domain $ domain tgm
              c            = domain $ codomain tgm
              --REMOVE THE TARGET EDGES AND NODES MAPPED (INJECTIVE MODULE)
              edgesT'      = L.delete y edgesT
              nodesT'      = L.delete (srcE c y) $ L.delete (tgtE c y) nodesT
              monomorphism = buildMappings prop nodes' t nodesT' edgesT' tgm'
              all          = buildMappings prop nodes' t nodesT  edgesT  tgm'
              --CHOSE BETWEEN INJECTIVE OR NOT
          case prop of
            GenericMorphism  -> all
            Monomorphism -> monomorphism
            Epimorphism  -> all
            Isomorphism  -> monomorphism
        Nothing  -> []

---------------------------------------------------------------------------------

-- VALIDATION OF A NODE MAPPING
-- VERIFY IF THE TYPES OF n1 AND n2 ARE COMPATIBLE AND UPDATE MAPPING
updateNodesMapping :: G.NodeId -> G.NodeId -> [G.NodeId] -> TGM.TypedGraphMorphism a b
                   -> Maybe (TGM.TypedGraphMorphism a b)
updateNodesMapping n1 n2 nodesT tgm =
  do
    let d = domain tgm
        c = codomain tgm
        m = mapping tgm

    if typeN d n1 == typeN c n2 &&
       (((isNothing $ applyNodeTGM tgm n1) && L.elem n2 nodesT) ||
        applyNodeTGM tgm n1 == Just n2)
      then Just $ TGM.typedMorphism d c $ GM.updateNodes n1 n2 m
      else Nothing

---------------------------------------------------------------------------------

-- VALIDATION OF A EDGE MAPPING
-- VERIFY IF THE TYPES OF e1 AND e2 ARE COMPATIBLE AND UPDATE MAPPING
updateEdgesMapping :: G.EdgeId -> G.EdgeId -> [G.EdgeId] -> TGM.TypedGraphMorphism a b
                   -> Maybe (TGM.TypedGraphMorphism a b)
updateEdgesMapping e1 e2 edgesT tgm =
  do
    let d = domain tgm
        c = codomain tgm
        m = mapping tgm

    if typeE d e1 == typeE c e2 &&
       (((isNothing $ applyEdgeTGM tgm e1) && L.elem e2 edgesT ) ||
        applyEdgeTGM tgm e1 == Just e2)
      then Just $ TGM.typedMorphism d c (GM.updateEdges e1 e2 m)
      else Nothing

{-

iN = insertNode
iE = insertEdge
uN = GM.updateNodes
uE = GM.updateEdges

{-grafo tipo-}
grafotipo = build [4,3,2,1] [(5,3,4),(4,2,4),(3,2,3),(2,2,1),(1,3,1)]

{-sendMSG-}
lr1 = build [11,13,14] [(11,13,11)]
kr1 = build [21,23,24] []
rr1 = build [31,33,34] [(35,33,34)]

--tipagem
tlr1 = GM.buildGraphMorphism lr1 grafotipo [(14,4),(13,3),(11,1)] [(11,1)]
tkr1 = GM.buildGraphMorphism kr1 grafotipo [(24,4),(23,3),(21,1)] []
trr1 = GM.buildGraphMorphism rr1 grafotipo [(34,4),(33,3),(31,1)] [(35,5)]

--span
kr1_lr1 = GM.buildGraphMorphism kr1 lr1 [(24,14),(23,13),(21,11)] []
l1 = TGM.typedMorphism tkr1 tlr1 kr1_lr1

kr1_rr1 = GM.buildGraphMorphism kr1 rr1 [(24,34),(23,33),(21,31)] []
r1 = TGM.typedMorphism tkr1 trr1 kr1_rr1

--nac
nacGraph = build [501,502,503,504] [(501,503,501),(503,502,503)]
nacType = GM.buildGraphMorphism nacGraph grafotipo [(501,1),(502,2),(503,3),(504,4)] [(501,1),(503,3)]
nacMap = GM.buildGraphMorphism lr1 nacGraph [(11,501),(13,503),(14,504)] [(11,501)]
nacSendMsg = TGM.typedMorphism tlr1 nacType nacMap

sendMsg = graphRule l1 r1 [nacSendMsg]

{-getDATA-}
lr2 = build [42,43,44] [(44,42,44),(45,43,44)]
kr2 = build [52,53,54] [(55,53,54)]
rr2 = build [62,63,64] [(65,63,64),(63,62,63)]

--tipagem
tlr2 = GM.buildGraphMorphism lr2 grafotipo [(44,4),(43,3),(42,2)] [(44,4),(45,5)]
tkr2 = GM.buildGraphMorphism kr2 grafotipo [(54,4),(53,3),(52,2)] [(55,5)]
trr2 = GM.buildGraphMorphism rr2 grafotipo [(64,4),(63,3),(62,2)] [(65,5),(63,3)]

--span
kr2_lr2 = GM.buildGraphMorphism kr2 lr2 [(52,42),(53,43),(54,44)] [(55,45)]
l2 = TGM.typedMorphism tkr2 tlr2 kr2_lr2

kr2_rr2 = GM.buildGraphMorphism kr2 rr2 [(54,64),(53,63),(52,62)] [(55,65)]
r2 = TGM.typedMorphism tkr2 trr2 kr2_rr2

getDATA = graphRule l2 r2 []

{-receiveMSG-}
lr3 = build [71,72,73,74] [(75,73,74),(73,72,73)]
kr3 = build [84,83,82,81] [(83,82,83)]
rr3 = build [94,93,92,91] [(91,93,91),(93,92,93)]

--tipagem
tlr3 = GM.buildGraphMorphism lr3 grafotipo [(74,4),(73,3),(72,2),(71,1)] [(75,5),(73,3)]
tkr3 = GM.buildGraphMorphism kr3 grafotipo [(84,4),(83,3),(82,2),(81,1)] [(83,3)]
trr3 = GM.buildGraphMorphism rr3 grafotipo [(94,4),(93,3),(92,2),(91,1)] [(91,1),(93,3)]

--span
kr3_lr3 = GM.buildGraphMorphism kr3 lr3 [(84,74),(83,73),(82,72),(81,71)] [(83,73)]
l3 = TGM.typedMorphism tkr3 tlr3 kr3_lr3

kr3_rr3 = GM.buildGraphMorphism kr3 rr3 [(84,94),(83,93),(82,92),(81,91)] [(83,93)]
r3 = TGM.typedMorphism tkr3 trr3 kr3_rr3

receiveMSG = graphRule l3 r3 []

{-deleteMSG-}
lr4 = build [101,102,103] [(101,103,101),(103,102,103)]
kr4 = build [112,111] []
rr4 = build [121,122] [(122,122,121)]

--tipagem
tlr4 = GM.buildGraphMorphism lr4 grafotipo [(101,1),(102,2),(103,3)] [(101,1),(103,3)]
tkr4 = GM.buildGraphMorphism kr4 grafotipo [(112,2),(111,1)] []
trr4 = GM.buildGraphMorphism rr4 grafotipo [(121,1),(122,2)] [(122,2)]

--span
kr4_lr4 = GM.buildGraphMorphism kr4 lr4 [(111,101),(112,102)] []
l4 = TGM.typedMorphism tkr4 tlr4 kr4_lr4

kr4_rr4 = GM.buildGraphMorphism kr4 rr4 [(111,121),(112,122)] []
r4 = TGM.typedMorphism tkr4 trr4 kr4_rr4

deleteMSG = graphRule l4 r4 []

{-teste-}
lr5 = build [200,201] []
kr5 = build [300] []
rr5 = build [400] []

--tipagem
tlr5 = GM.buildGraphMorphism lr5 grafotipo [(200,1),(201,1)] []
tkr5 = GM.buildGraphMorphism kr5 grafotipo [(300,1)] []
trr5 = GM.buildGraphMorphism rr5 grafotipo [(400,1)] []

--span
kr5_lr5 = GM.buildGraphMorphism kr5 lr5 [(300,200)] []
l5 = TGM.typedMorphism tkr5 tlr5 kr5_lr5

kr5_rr5 = GM.buildGraphMorphism kr5 rr5 [(300,400)] []
r5 = TGM.typedMorphism tkr5 trr5 kr5_rr5

teste = graphRule l5 r5 []

{-testeNac-}
lr6 = build [212] []
kr6 = build [222] []
rr6 = build [232] []

--tipagem
tlr6 = GM.buildGraphMorphism lr6 grafotipo [(212,2)] []
tkr6 = GM.buildGraphMorphism kr6 grafotipo [(222,2)] []
trr6 = GM.buildGraphMorphism rr6 grafotipo [(232,2)] []

--span
kr6_lr6 = GM.buildGraphMorphism kr6 lr6 [(222,212)] []
l6 = TGM.typedMorphism tkr6 tlr6 kr6_lr6

kr6_rr6 = GM.buildGraphMorphism kr6 rr6 [(222,232)] []
r6 = TGM.typedMorphism tkr6 trr6 kr6_rr6

--nac
ng6 = build [242,241] []
nt6 = GM.buildGraphMorphism ng6 grafotipo [(242,2),(241,1)] []
lr6_n6 = GM.buildGraphMorphism lr6 ng6 [(212,242)] []
nac6 = TGM.typedMorphism tlr6 nt6 lr6_n6

wnac = graphRule l6 r6 [nac6]

{-testeNac2-}
lr7 = build [312] []
kr7 = build [322] []
rr7 = build [332] []

--tipagem
tlr7 = GM.buildGraphMorphism lr7 grafotipo [(312,2)] []
tkr7 = GM.buildGraphMorphism kr7 grafotipo [(322,2)] []
trr7 = GM.buildGraphMorphism rr7 grafotipo [(332,2)] []

--span
kr7_lr7 = GM.buildGraphMorphism kr7 lr7 [(322,312)] []
l7 = TGM.typedMorphism tkr7 tlr7 kr7_lr7

kr7_rr7 = GM.buildGraphMorphism kr7 rr7 [(322,332)] []
r7 = TGM.typedMorphism tkr7 trr7 kr7_rr7

wnac2 = graphRule l7 r7 []

{-testeCreate-}
lr8 = build [] []
kr8 = build [] []
rr8 = build [350] []

--tipagem
tlr8 = GM.buildGraphMorphism lr8 grafotipo [] []
tkr8 = GM.buildGraphMorphism kr8 grafotipo [] []
trr8 = GM.buildGraphMorphism rr8 grafotipo [(350,1)] []

--span
kr8_lr8 = GM.buildGraphMorphism kr8 lr8 [] []
l8 = TGM.typedMorphism tkr8 tlr8 kr8_lr8

kr8_rr8 = GM.buildGraphMorphism kr8 rr8 [] []
r8 = TGM.typedMorphism tkr8 trr8 kr8_rr8

testeCreate = graphRule l8 r8 []

-}


{-Fim das Regras-}

--test1 = build [1] []
--test2 = build [1,2] []

--gm1 = GM.buildGraphMorphism test1 grafotipo [(1,1)] []
--gm2 = GM.buildGraphMorphism test2 grafotipo [(1,1),(2,1)] []

--t1 = GM.buildGraphMorphism test1 test2 [(1,1)] []
--t2 = GM.buildGraphMorphism test2 test1 [(1,1),(2,1)] []

-----

--rules = [sendMsg,getDATA,receiveMSG,deleteMSG]
--rules2 = rules ++ [teste,wnac,wnac2,testeCreate]

--rulesTest = concat (replicate 32 rules)
--27.9s useDelete old - nac matches part inj
--28.5s useDelete old - nac matches total inj
--33.6s useDelete categorial diagram - nac matches part inj
--34.2s useDelete categorial diagram - nac matches total inj

--rulesTest2 = concat (replicate 16 rules2)
-- 9.8s useDelete old - nac matches part inj
-- 9.9s useDelete old - nac matches total inj
--11.7s useDelete categorial diagram - nac matches part inj
--11.9s useDelete categorial diagram - nac matches total inj

--initGraph = GM.empty grafotipo grafotipo
--ggg = GG.graphGrammar initGraph [("sendMsg",sendMsg), ("getDATA", getDATA), ("receiveMsg", receiveMSG), ("deleteMsg", deleteMSG), ("teste", teste), ("wnac", wnac), ("wnac2", wnac2), ("testeCreate", testeCreate)]

-- fileName = "teste-conflito.ggx"

--fileName = "elevator.ggx"

-- fileName = "ev.ggx"

{-calculate = do
  tg <- XML.readTypeGraph fileName
  rs <- XML.readRules fileName
  let rulesNames = map (\((x,_,_,_),_) -> x) rs
  print rulesNames
  let rles = map (XML.instantiateRule (head tg)) rs
  print $ "Numero de regras: " ++ show (length rles)
  print "Delete-Use"
  let ud = m rles
  print ud
  print "Produce-Forbid"
  let pf = mpf rles
  print pf
  print "Produce Edge Delete Node"
  let pe = mpe rles
  print pe
  print "Matriz final"
  print $ ud + pf + pe
  --return (criticalPairs (rles!!0) (rles!!2))
  return (rles)
  --return ()
-}
{------
filtMono x = filter (\(_,q) -> M.monomorphism q) x

filtPairs inverseLeft x = filter (\(h1,_) -> satsGluingCond inverseLeft h1) x

calculatePushoutComplement inverseLeft x = map (\(h1,q21) -> let (k,r') = RW.calculatePushoutComplement h1 (left inverseLeft) in
 (h1,q21,k,r')) x

calculatePushout inverseLeft x = map (\(h1,q21,k,r') ->
 let (m1,l') = RW.calculatePushout k (right inverseLeft) in
 (h1,q21,k,r',m1,l')) x

filtM1 l x = filter (\(_,_,_,_,m1,_) -> satisfiesNACs l m1) x

h21 x n = concat
 (map (\(h1,q21,k,r',m1,l') ->
 let f = matches (M.domain n) (M.codomain k) FREE in
 if Prelude.null f
 then []
 else [(h1,q21,k,r',m1,l',head f)])
 x)

validH21 n x = filter (\(h1,q21,k,r',m1,l',l2d1) -> M.compose l2d1 r' == M.compose n q21) x

m1m2 x = map (\(h1,q21,k,r',m1,l',l2d1) -> (m1, M.compose l2d1 l')) x
filtM2 r = filter (\(m1,m2) -> satsGluingCond r m2)

------}

{-cpRT = criticalPairs receiveMSG teste
mA = m1 (cpRT!!1)
mB = m2 (cpRT!!1)
kToG = M.compose (left receiveMSG) mA
gToK = TGM.typedMorphism (M.codomain kToG) (M.domain kToG) (GM.inverse (TGM.mapping kToG))
gToR = M.compose gToK (right receiveMSG)
rToG = TGM.typedMorphism (M.codomain gToR) (M.domain gToR) (GM.inverse (TGM.mapping gToR))
nvMB = M.compose mB gToR

---------
cps = criticalPairs getDATA sendMsg
cp0 = cps!!0
l = left sendMsg
r = TGM.inverseTGM (right sendMsg)
deleted = M.compose l (m2 cp0)
created = M.compose r deleted
---------}

{-ri = sendMsg
le = sendMsg

n = head (nacs ri)
inverseRule = inverseGR le

pairs = createPairs (right le) n
filtPairs = filter (\(m'1,_) -> satsGluingCond inverseRule m'1) pairs
m' = map fst filtPairs
q = map snd filtPairs

kr' = map (\m'1 -> RW.calculatePushoutComplement m'1 (left inverseRule)) m'
k = map fst kr'
r' = map snd kr'

ml' = map (\x -> RW.calculatePushout x (right inverseRule)) k
mm1 = map fst ml'
l' = map snd ml'

m1k = zip mm1 k

filtM1 = filter (\(m1,_) -> satisfiesNACs le m1) m1k

h12 = map (\(_,k) -> matches (M.codomain (left ri)) (M.codomain k) FREE) filtM1
filtH12 = map (\(x,y,z) -> validH12 x y z) (zip3 h12 (map snd filtPairs) r')
adjH12 = ajeita filtH12 filtM1 l'

mm2 = map (\(h,m1,ls) -> (m1,M.compose h ls)) adjH12
filtM2 = filter (\(m1,m2) -> satsGluingCond ri m2) mm2

len = length filtM2

validH12 h12 q r' = filter (\h -> M.compose n q == M.compose h r') h12

ajeita [] _ _ = []
ajeita (h:hs) (m1:m1s) (l:ls) = (if Prelude.null h then [] else [(head h,m1,l)]) ++ (ajeita hs m1s ls)-}
---

{-g = fst (head filtPairs)
k = fst (RW.calculatePushoutComplement g (left inverseRule))
r = right inverseRule

kr = M.compose (TGM.invertTGM r) k                                 -- invert r and compose with k, obtain kr : R -> D
createdNodess = TGM.orphanNodesTyped r                                -- nodes in R to be created
createdEdgess = TGM.orphanEdgesTyped r                                -- edges in R to be created
nodeTable    = zip createdNodess (GM.newNodesTyped $ M.codomain kr) -- table mapping NodeIds in R to NodeIds in G'
edgeTable    = zip createdEdgess (GM.newEdgesTyped $ M.codomain kr) -- table mapping EdgeIds in R to EdgeIds in G'

-- generate new node instances in G', associating them to the "created" nodes in R
kr'          = foldr (\(a,b) tgm -> let tp = fromJust $ GM.applyNode (M.domain kr) a
 in TGM.updateNodeRelationTGM a b tp tgm)
 kr
 nodeTable

-- query the instance graphs R
typemor = M.domain         kr'                     -- typemor is the typed graph (R -> T)
g2      = M.domain         typemor                 -- g  is the instance graph R
mp      = TGM.mapping        kr'                     -- mp is the mapping of kr'  : (R -> D'), where D' = D + new nodes
s1 e = fromJust $ sourceOf g2 e                    -- obtain source of e in R
t1 e = fromJust $ targetOf g2 e                    -- obtain target of e in R
s2 e = fromJust $ GM.applyNode mp (s1 e)             -- obtain source of m'(e) in G'
t2 e = fromJust $ GM.applyNode mp (t1 e)             -- obtain target of m'(e) in G'
tp e = fromJust $ GM.applyEdge typemor e             -- obtain type of e in R

-- generate new edge table with new information
edgeTable' = map (\(e,e2) -> (e, s1 e, t1 e, e2, s2 e, t2 e, tp e)) edgeTable

--(101,103,101,1009,1006,1002,1)
e101 = EdgeId 101
n103 = NodeId 103
n101 = NodeId 101
e1009 = EdgeId 1009
n1006 = NodeId 1006
n1002 = NodeId 1002
e1 = EdgeId 1

--(103,102,103,1010,1000,1006,3)
e103 = EdgeId 103
n102 = NodeId 102
e1010 = EdgeId 1010
n1000 = NodeId 1000
e3 = EdgeId 3

-- create new morphism adding all edges
kr''      = foldr (\(a,sa,ta,b,sb,tb,tp) tgm -> TGM.updateEdgeRelationTGM a b (TGM.createEdgeCodTGM b sb tb tp tgm) )
 kr'
 edgeTable'-}

-----

--graphEqClass = map (\x -> GP.genEqClass (mixTGM (right getDATA) x)) (nacs sendMsg)
--md = map (\x -> (map (mountTypedGraphMorphisms (right getDATA) x graphEqClass))) (nacs sendMsg)
--ms = map (map (mountTGM (right getDATA) "Right")) (map(\x -> GP.genEqClass (mixTGM x (right getDATA))) (nacs sendMsg))

--injectiveMatches = True

--m   r = matrix (length r) (length r) (\y -> length $ allDeleteUse       injectiveMatches (r!!((fst y)-1)) (r!!((snd y)-1)))
--mpf r = matrix (length r) (length r) (\y -> length $ allProduceForbid   injectiveMatches (r!!((fst y)-1)) (r!!((snd y)-1)))
--mpe r = matrix (length r) (length r) (\y -> length $ allProdEdgeDelNode injectiveMatches (r!!((fst y)-1)) (r!!((snd y)-1)))

--classes de equivalência dos lados esquerdos das regras
--utilizado apenas no módulo toJPG
--gg :: [GP.EqClassGraphMap]
--gg = GP.genEqClass $ mixLeftRule sendMsg sendMsg
--gg = GP.genEqClass $ mixTGM (head (nacs sendMsg)) (right sendMsg)

--classes de equivalencia em formato Text
--ggs = gind (map GP.eqGraph gg)

--main :: IO ()
--main = calculate--f2
{-
   do
      --f ((length ggs)-1)
      args <- getArgs
      parse args
--      let fileName = head args
--      print (if Prelude.null args then "Error" else ma)
      return ()

parse [] = error "Passe um arquivo, por favor"
parse fs = XML.main2 $ head fs-}

--r = rulesTest2

--apaga os .dot
--f2 =
--  do
--      writeFile ("matrix.txt") (show ((m r) + (mpf r) + (mpe r)))
--      return ()

--cria os .dot e os .jpg
{-f 0 =
   do
      writeFile ("0.dot") (write ggs 0)
      runCommand ("dot -Tjpg 0.dot > 0.jpg")
      return ()

f n =
   do
      writeFile ((show n)++".dot") (write ggs n)
      runCommand ("dot -Tjpg "++(show n)++".dot > "++(show n)++".jpg")
      (f (n-1))-}
