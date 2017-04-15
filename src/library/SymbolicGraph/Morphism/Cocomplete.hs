{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE PatternSynonyms           #-}
{-# LANGUAGE Rank2Types                #-}
{-# LANGUAGE TypeFamilies              #-}
module SymbolicGraph.Morphism.Cocomplete where

import           Abstract.Cocomplete
import           Abstract.Morphism
import           Control.Arrow
import           Equivalence.EquivalenceClasses
import           SymbolicGraph.DataAlgebra
import           SymbolicGraph.Internal
import           SymbolicGraph.Morphism.Internal


import           Control.Monad
import           Data.IntMap                     (IntMap)
import qualified Data.IntMap                     as IntMap
import qualified Data.List.NonEmpty              as NonEmpty
import           Data.Map                        (Map)
import qualified Data.Map                        as Map
import           Data.Maybe                      (catMaybes, listToMaybe,
                                                  mapMaybe)
import           Data.Set                        (Set)
import qualified Data.Set                        as Set


newtype Pair a =
  Pair { unPair :: (a, a) }


mkPair :: a -> a -> Pair a
mkPair x y =
  Pair (x, y)


instance Cocomplete SymbolicMorphism where

  initialObject _ =
    SymbolicGraph.Internal.empty


  calculateCoequalizer f g =
      calculateGenericCoequalizer (domain f) (codomain f) (mkPair f g)


  calculateNCoequalizer morphisms =
      calculateGenericCoequalizer
        (domain $ NonEmpty.head morphisms)
        (codomain $ NonEmpty.head morphisms)
        (NonEmpty.toList morphisms)



class Coequalizable collection where

  -- | Apply the given function to all elements of the given collection, returning the collection
  -- of non-'Nothing' results. If the resulting collection would be empty, may return 'Nothing'.
  filterMap :: Ord b => (a -> Maybe b) -> collection a -> Maybe (collection b)

  -- | Given collections of elements that should belong to the same partition, "collapses" the
  -- appropriate equivalent classes of the given partition.
  mergeElements :: (Ord a, Show a) => [collection a] -> Partition a -> Partition a


instance Coequalizable Pair where

  filterMap f (Pair (a, b)) =
    mkPair <$> f a <*> f b

  mergeElements =
    mergePairs . map unPair


instance Coequalizable [] where

  filterMap f =
    Just . mapMaybe f

  mergeElements =
    mergeSets . map Set.fromList


calculateGenericCoequalizer :: Coequalizable collection => SymbolicGraph -> SymbolicGraph -> collection SymbolicMorphism -> SymbolicMorphism
{-# INLINE calculateGenericCoequalizer #-}
calculateGenericCoequalizer sharedDomain sharedCodomain parallelMorphisms =
  let
    collapsedNodes =
      catMaybes [ filterMap (lookupNodeId n) parallelMorphisms | n <- nodeIds sharedDomain ]

    collapsedEdges =
      catMaybes [ filterMap (lookupEdgeId e) parallelMorphisms | e <- edgeIds sharedDomain ]

    collapsedVarsFromNodes =
        catMaybes [ filterMap lookupAttribute nodeGroup | nodeGroup <- collapsedNodes ]
      where
        lookupAttribute nodeId =
          lookupNode nodeId sharedCodomain >>= nodeAttribute

    collapsedVarsFromFunctions =
      catMaybes
        [ filterMap (applyToVariable v) parallelMorphisms
            | v <- Set.toList (freeVariablesOf sharedDomain)
        ]

    variableRenaming =
      partitionToMapping
        (mergeElements
          (collapsedVarsFromFunctions ++ collapsedVarsFromNodes)
          (discretePartition . Set.toList $ freeVariablesOf sharedCodomain))
        Set.findMin

    nodeMapping =
      partitionToMapping
        (mergeElements collapsedNodes . discretePartition $ nodeIds sharedDomain)
        getRepresentativeNode
      where
        getRepresentativeNode equivalentNodeIds =
          let
            representativeId =
              Set.findMin equivalentNodeIds

            originalAttributes =
              mapMaybe ((`lookupNode` sharedCodomain) >=> nodeAttribute) (Set.toList equivalentNodeIds)

            renamedAttribute =
              listToMaybe originalAttributes >>= (`Map.lookup` variableRenaming)
          in
            N representativeId renamedAttribute

    edgeMapping =
      partitionToMapping
        (mergeElements collapsedEdges . discretePartition $ edgeIds sharedDomain)
        getRepresentativeEdge
      where
        getRepresentativeEdge equivalentEdgeIds =
          let
            representativeId =
              Set.findMin equivalentEdgeIds

            Just (E _ originalSource originalTarget) =
              lookupEdge representativeId sharedCodomain

            Just (N mappedSource _) =
              Map.lookup originalSource nodeMapping

            Just (N mappedTarget _) =
              Map.lookup originalTarget nodeMapping
          in
            E representativeId mappedSource mappedTarget

    coequalizerGraph =
      fromNodesAndEdges
        (Map.elems nodeMapping)
        (Map.elems edgeMapping)
        (renameVariables variableRenaming $ restrictions sharedCodomain)
  in
    SymbMor
      sharedCodomain
      coequalizerGraph
      (asIntMap $ fmap nodeId nodeMapping)
      (asIntMap $ fmap edgeId edgeMapping)
      variableRenaming



asIntMap :: Enum k => Map k v -> IntMap v
asIntMap =
  IntMap.fromList . map (first fromEnum) . Map.toList
