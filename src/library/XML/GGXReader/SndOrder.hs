module XML.GGXReader.SndOrder (instantiateSndOrderRules) where

import           Abstract.Category.DPO
import           Abstract.Category.FinitaryCategory
import qualified Data.Graphs               as G
import           Data.Graphs.Morphism       as GM
import           SndOrder.Morphism
import           TypedGraph.DPO.GraphRule  as GR
import           Data.TypedGraph
import           Data.TypedGraph.Morphism

import           XML.GGXReader.Span
import           XML.ParsedTypes
import qualified XML.ParseSndOrderRule     as SO
import           XML.Utilities

instantiateSndOrderRules :: G.Graph (Maybe a) (Maybe b) -> [RuleWithNacs] -> [(String, Production (RuleMorphism a b))]
instantiateSndOrderRules typeGraph sndOrdRules = zip sndOrderNames d
  where
    a = SO.parseSndOrderRules sndOrdRules
    c = map (instantiateSndOrderRule typeGraph) a
    d = map (\(_,(l,r),n) -> buildProduction l r n) c
    sndOrderNames = map fstOfThree c

instantiateSndOrderRule :: G.Graph (Maybe a) (Maybe b) -> (SndOrderRuleSide, SndOrderRuleSide,[SndOrderRuleSide]) -> (String,(RuleMorphism a b, RuleMorphism a b),[RuleMorphism a b])
instantiateSndOrderRule typegraph (l@(_,nameL,leftL),r@(_,_,rightR), n) = (nameL, instantiateMorphs, nacs)
  where
    ruleLeft = instantiateRule typegraph leftL
    ruleRight = instantiateRule typegraph rightR
    instantiateMorphs = instantiateRuleMorphisms (l,ruleLeft) (r,ruleRight)
    nacsRules = map (instantiateRule typegraph . (\(_,_,(x,_)) -> (x,[]))) n
    nacs = map (instantiateSndOrderNac (l,ruleLeft)) (zip n nacsRules)

instantiateSndOrderNac :: (SndOrderRuleSide, GraphRule a b) -> (SndOrderRuleSide, GraphRule a b) -> RuleMorphism a b
instantiateSndOrderNac (parsedLeft, l) (n, nacRule) = ruleMorphism l nacRule nacL nacK nacR
  where
    mapL = SO.getLeftObjNameMapping parsedLeft n
    mapR = SO.getRightObjNameMapping parsedLeft n
    nacL = instantiateNacMorphisms (codomain (getLHS l)) (codomain (getLHS nacRule)) mapL
    nacK = instantiateNacMorphisms (domain (getLHS l)) (domain (getLHS nacRule)) mapL
    nacR = instantiateNacMorphisms (codomain (getRHS l)) (codomain (getRHS nacRule)) mapR

instantiateNacMorphisms :: TypedGraph a b -> TypedGraph a b
                        -> [Mapping] -> TypedGraphMorphism a b
instantiateNacMorphisms graphL graphN mapping = buildTypedGraphMorphism graphL graphN maps
  where
    mapElements = map (\(x,_,y) -> (read y :: Int, read x :: Int)) mapping
    maps = buildGraphMorphism
             (domain graphL)
             (domain graphN)
             mapElements
             mapElements

instantiateRuleMorphisms :: (SndOrderRuleSide, GraphRule a b)
                         -> (SndOrderRuleSide, GraphRule a b)
                         -> (RuleMorphism a b , RuleMorphism a b)
instantiateRuleMorphisms (parsedLeft, l) (parsedRight, r) =
  (ruleMorphism ruleK l leftKtoLeftL interfaceKtoL rightKtoRightL,
   ruleMorphism ruleK r leftKtoLeftR interfaceKtoR rightKtoRightR)
    where
      graphKRuleL = domain (getLHS l)
      graphKRuleR = domain (getLHS r)
      graphLRuleL = codomain (getLHS l)
      graphLRuleR = codomain (getLHS r)
      graphRRuleL = codomain (getRHS l)
      graphRRuleR = codomain (getRHS r)

      mappingBetweenLeft = SO.getLeftObjNameMapping parsedLeft parsedRight
      mappingBetweenRight = SO.getRightObjNameMapping parsedLeft parsedRight

      ruleK = buildProduction leftK rightK []

      graphLRuleK = domain leftKtoLeftL
      graphRRuleK = domain rightKtoRightL

      (leftKtoLeftL, leftKtoLeftR) =
        instantiateSpan graphLRuleL graphLRuleR mappingBetweenLeft

      (interfaceKtoL, interfaceKtoR) =
        instantiateSpan graphKRuleL graphKRuleR mappingBetweenLeft

      (rightKtoRightL, rightKtoRightR) =
        instantiateSpan graphRRuleL graphRRuleR mappingBetweenRight

      maps (_,_,((_,_,_,x),_)) = x
      (leftK, rightK) = instantiateSpan graphLRuleK graphRRuleK (maps parsedLeft)
