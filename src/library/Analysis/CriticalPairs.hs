module Analysis.CriticalPairs
 ( CP (..),
   CriticalPair,
   criticalPairs,
   namedCriticalPairs,
   allDeleteUse,
   allProduceForbid,
   allProduceDangling,
   getMatch,
   getComatch,
   getCPNacIdx,
   getCPNac,
   getCP,
   deleteUse
   ) where

import           Abstract.AdhesiveHLR      as RW
import           Abstract.DPO              as RW hiding (comatch)
import           Analysis.DiagramAlgorithms
import           Data.Maybe                (mapMaybe)

-- | Data representing the type of a 'CriticalPair'
data CP = FOL | DeleteUse | ProduceForbid | ProduceDangling deriving(Eq,Show)

-- | A Critical Pair is defined as two matches (m1,m2) from the left side of their rules to a same graph.
-- It assumes that the derivation of the rule with match @m1@ causes a conflict with the rule with match @m2@
--
-- This diagram shows graphs and morphisms names used in the algorithms below
--
-- l = production (L1,K1,R1,[N1])
--
-- r = production (L2,K2,R2,[N2])
--
-- @
--                    N1    N2
--                    ^      ^
--          r     l   │      │n
--     R1◀─────K1────▶L1    L2◀────K2─────▶R2
--     │       │       \\   /       │       │
--  m1'│      k│      m1\\ /m2      │       │
--     ▼       ▼         ▼         ▼       ▼
--     P1◀─────D1───────▶G◀───────D2──────▶P2
--         r'       l'
-- @
--
-- m2' :: from L2 to P1
--
-- h21 :: from L2 to D1
--
-- q21 (nacMatch) :: from N2 to P1

data CriticalPair m = CriticalPair {
    match  :: (m, m),
    comatch :: Maybe (m, m),
    nacMatch :: Maybe (m, Int), --if is ProduceForbid, here is the index of the nac
    cp  :: CP
    } deriving (Eq,Show)

-- | Returns the matches (m1,m2)
getMatch :: CriticalPair m -> (m, m)
getMatch = match

-- | Returns the comatches (m1',m2')
getComatch :: CriticalPair m -> Maybe (m, m)
getComatch = comatch

-- | Returns the type of a 'CriticalPair'
getCP :: CriticalPair m -> CP
getCP = cp

-- | Returns the nac match of a 'CriticalPair'
getCPNac :: CriticalPair m -> Maybe m
getCPNac cp = case nacMatch cp of
                Just (nac,_) -> Just nac
                Nothing -> Nothing

-- | Returns the nac index of a 'CriticalPair'
getCPNacIdx :: CriticalPair m -> Maybe Int
getCPNacIdx cp = case nacMatch cp of
                   Just (_,idx) -> Just idx
                   Nothing -> Nothing

-- | Returns the Critical Pairs with rule names
namedCriticalPairs :: (EpiPairs m, DPO m) => NacSatisfaction -> MatchRestriction
  -> [(String, Production m)] -> [(String,String,[CriticalPair m])]
namedCriticalPairs nacInj inj r = map (uncurry getCPs) [(a,b) | a <- r, b <- r]
  where
    getCPs (n1,r1) (n2,r2) = (n1, n2, criticalPairs nacInj inj r1 r2)

-- | All Critical Pairs
criticalPairs :: (EpiPairs m, DPO m) => NacSatisfaction -> MatchRestriction
              -> Production m -> Production m -> [CriticalPair m]
--criticalPairs nacInj inj l r = (allDeleteUse nacInj inj l r) ++ (allProduceDangling nacInj inj l r) ++ (allProduceForbid nacInj inj l r)
criticalPairs nacInj inj l r =
  allDeleteUseAndDang nacInj inj l r ++
  allProduceForbid nacInj inj l r

---- Delete-Use

-- | All DeleteUse caused by the derivation of @l@ before @r@
allDeleteUse :: (EpiPairs m, DPO m) => NacSatisfaction -> MatchRestriction
             -> Production m -> Production m -> [CriticalPair m]
allDeleteUse nacInj inj l r =
  map
    (\m -> CriticalPair m Nothing Nothing DeleteUse)
    delUse
  where
    pairs = createPairsCodomain inj (left l) (left r)
    gluing = filter (\(m1,m2) -> satsGluingNacsBoth nacInj inj (l,m1) (r,m2)) pairs
    delUse = filter (deleteUse inj l) gluing

---- Produce-Dangling

allProduceDangling :: (EpiPairs m, DPO m) => NacSatisfaction -> MatchRestriction
                   -> Production m -> Production m -> [CriticalPair m]
allProduceDangling nacInj i l r =
  map
    (\m -> CriticalPair m Nothing Nothing ProduceDangling)
    prodDang
  where
    pairs = createPairsCodomain i (left l) (left r)
    gluing = filter (\(m1,m2) -> satsGluingNacsBoth nacInj i (l,m1) (r,m2)) pairs
    prodDang = filter (produceDangling nacInj i l r) gluing

---- DeleteUse and Produce-Dangling

-- | Tests DeleteUse and ProduceDangling for the same pairs,
-- more efficient than deal separately.
allDeleteUseAndDang :: (EpiPairs m, DPO m) => NacSatisfaction -> MatchRestriction
                    -> Production m -> Production m -> [CriticalPair m]
allDeleteUseAndDang nacInj i l r =
  let conflicts = mapMaybe (deleteUseDangling nacInj i l r) gluing
  in map
      (\x -> case x of
        (Left m) -> CriticalPair m Nothing Nothing DeleteUse
        (Right m) -> CriticalPair m Nothing Nothing ProduceDangling)
      conflicts
  where
    pairs = createPairsCodomain i (left l) (left r)
    gluing = filter (\(m1,m2) -> satsGluingNacsBoth nacInj i (l,m1) (r,m2)) pairs

---- Produce-Forbid

-- | All ProduceForbid caused by the derivation of @l@ before @r@.
-- Rule @l@ causes a produce-forbid conflict with @r@ if some NAC in @r@
-- fails to be satisfied after the aplication of @l@.
allProduceForbid :: (EpiPairs m, DPO m) => NacSatisfaction -> MatchRestriction
                 -> Production m -> Production m -> [CriticalPair m]
allProduceForbid nacInj inj l r =
  concatMap
    (produceForbid nacInj inj l inverseLeft r)
    (zip (nacs r) [0..])
  where
    inverseLeft = inverse nacInj inj l

-- | Check ProduceForbid for a NAC @n@ in @r@.
produceForbid :: (EpiPairs m, DPO m) => NacSatisfaction -> MatchRestriction -> Production m
              -> Production m -> Production m -> (m, Int) -> [CriticalPair m]
produceForbid nacInj inj l inverseLeft r nac =
  map
    (\(m,m',nac) -> CriticalPair m (Just m') (Just nac) ProduceForbid)
    (produceForbidOneNac nacInj inj l inverseLeft r nac)


-- | Create all jointly epimorphic pairs of morphisms from the codomains of
-- the given morphisms.
-- The flag indicates only monomorphic morphisms.
createPairsCodomain :: (EpiPairs m) => MatchRestriction -> m -> m -> [(m, m)]
createPairsCodomain inj m1 m2 = createPairs (inj == MonoMatches) (codomain m1) (codomain m2)