{-# LANGUAGE NamedFieldPuns #-}
module LabeledGraph.Morphism.FindMorphism where

import           Abstract.Morphism              hiding (id)
import           Abstract.Variable
import           Graph.Graph                    (Edge (..), EdgeId, Node (..),
                                                 NodeId)
import qualified Graph.Graph                    as Graph
import           LabeledGraph.Internal
import           LabeledGraph.Morphism.Internal hiding (edgeMap, id, nodeMap,
                                                 variableMap)

import           Control.Applicative
import           Control.Arrow
import           Control.Monad
import           Data.IntMap                    (IntMap)
import qualified Data.IntMap                    as IntMap
import           Data.IntSet                    (IntSet)
import qualified Data.IntSet                    as IntSet
import           Data.Map                       (Map)
import qualified Data.Map                       as Map
import           Data.Set                       (Set)
import qualified Data.Set                       as Set



instance FindMorphism LabeledMorphism where


  {-# INLINE findMorphisms #-}
  findMorphisms restriction domain codomain =
    let
      config =
        makeConfig restriction
    in
      runMorphismBuilder config domain codomain $
        buildMorphisms (makeConfig restriction)


  {-# INLINE partialInjectiveMatches #-}
  partialInjectiveMatches nac match =
    runMorphismBuilder config (codomain nac) (codomain match) $
      addMappingsFromSpan >=> buildMorphisms config
    where
      config = makeConfig Monomorphism

      addMappingsFromSpan :: BuilderState -> [BuilderState]
      addMappingsFromSpan state =
        do
          let
            mappedVariables =
              [ (v1, v2)
                  | v <- freeVariablesOf (domain nac)
                  , Just v1 <- [applyToVariable v nac]
                  , Just v2 <- [applyToVariable v match]
              ]
          state1 <- foldM addVariableMapping' state mappedVariables

          let
            mappedNodes =
              [ (n1, n2)
                  | n <- Graph.nodeIds (domain nac)
                  , Just n1 <- [applyToNodeId n nac]
                  , Just n2 <- [applyToNodeId n match]
              ]
          state2 <- foldM addNodeMapping' state1 mappedNodes

          let
            mappedEdges =
              [ (e1, e2)
                  | e <- Graph.edgeIds (domain nac)
                  , Just e1 <- [applyToEdgeId e nac]
                  , Just e2 <- [applyToEdgeId e match]
              ]
          foldM addEdgeMapping' state2 mappedEdges

      addNodeMapping' state (domainNode, codomainNode) =
        case IntMap.lookup (fromEnum $ nodeId domainNode) (nodeMap state) of
          Just previousMapping ->
            [ state | previousMapping == nodeId codomainNode ]

          Nothing ->
            addNodeMapping config domainNode codomainNode state

      addEdgeMapping' state (domainEdge, codomainEdge) =
        case IntMap.lookup (fromEnum $ edgeId domainEdge) (edgeMap state) of
          Just previousMapping ->
            [ state | previousMapping == edgeId codomainEdge ]

          Nothing ->
            addEdgeMapping config domainEdge codomainEdge state

      addVariableMapping' state (domainVar, codomainVar) =
        case Map.lookup domainVar (variableMap state) of
          Just previousMapping ->
            [ state | previousMapping == codomainVar ]

          Nothing ->
            addVariableMapping config domainVar codomainVar state



type MorphismBuilder =
  BuilderState -> [BuilderState]


data BuilderState =
  State
    { unmappedDomNodes        :: IntMap LNode
    , unmappedDomEdges        :: IntMap LEdge
    , unmappedDomVariables    :: Set Variable
    , availableCodNodes     :: IntMap LNode
    , availableCodEdges     :: IntMap LEdge
    , availableCodVariables :: Set Variable
    , nodeMap                    :: IntMap NodeId
    , edgeMap                    :: IntMap EdgeId
    , variableMap                :: Map Variable Variable
    }
    deriving (Show)


data BuilderConfig =
  Config
    { updateAfterMappingEdge :: LEdge -> LEdge -> BuilderState -> BuilderState
    , updateAfterMappingNode :: LNode -> LNode -> BuilderState -> BuilderState
    , updateAfterMappingVariable :: Variable -> Variable -> BuilderState -> BuilderState
    , validateFinalState :: LabeledGraph -> LabeledGraph -> BuilderState -> Bool
    }


makeConfig :: MorphismType -> BuilderConfig
{-# INLINE makeConfig #-}
makeConfig restriction =
  case restriction of
    GenericMorphism ->
      Config
        { updateAfterMappingEdge = \_ _ -> id
        , updateAfterMappingNode = \_ _ -> id
        , updateAfterMappingVariable = \_ _ -> id
        , validateFinalState = \_ _ _ -> True
        }

    Monomorphism ->
      Config
        { updateAfterMappingEdge = \_ (Edge e _ _ _) state ->
            state { availableCodEdges = IntMap.delete (fromEnum e) (availableCodEdges state) }
        , updateAfterMappingNode = \_ (Node n _) state ->
            state { availableCodNodes = IntMap.delete (fromEnum n) (availableCodNodes state)}
        , updateAfterMappingVariable = \_ v state ->
            state { availableCodVariables = Set.delete v (availableCodVariables state) }
        , validateFinalState = \_ _ _ -> True
        }

    Epimorphism ->
      Config
        { updateAfterMappingEdge = \_ _ -> id
        , updateAfterMappingNode = \_ _ -> id
        , updateAfterMappingVariable = \_ _ -> id
        , validateFinalState = \_ codomain state ->
            asIntSet (IntMap.elems $ nodeMap state) == asIntSet (Graph.nodeIds codomain)
              && asIntSet (IntMap.elems $ edgeMap state) == asIntSet (Graph.edgeIds codomain)
              && Set.fromList (Map.elems $ variableMap state) == freeVariableSet codomain
        }

    Isomorphism ->
      Config
        { updateAfterMappingEdge = \_ (Edge e _ _ _) state ->
            state { availableCodEdges = IntMap.delete (fromEnum e) (availableCodEdges state) }
        , updateAfterMappingNode = \_ (Node n _) state ->
            state { availableCodNodes = IntMap.delete (fromEnum n) (availableCodNodes state)}
        , updateAfterMappingVariable = \_ v state ->
            state { availableCodVariables = Set.delete v (availableCodVariables state) }
        , validateFinalState = \_ _ state ->
            IntMap.null (availableCodNodes state)
              && IntMap.null (availableCodEdges state)
              && Set.null (availableCodVariables state)
        }


runMorphismBuilder :: (Alternative m, Monad m) =>
  BuilderConfig -> LabeledGraph -> LabeledGraph ->
  (BuilderState -> m BuilderState) -> m LabeledMorphism
runMorphismBuilder config domain codomain build =
  let
    initialState =
      State
        { unmappedDomNodes = asIntMap (Graph.nodeMap domain)
        , unmappedDomEdges = asIntMap (Graph.edgeMap domain)
        , unmappedDomVariables = freeVariableSet domain
        , availableCodNodes = asIntMap (Graph.nodeMap codomain)
        , availableCodEdges = asIntMap (Graph.edgeMap codomain)
        , availableCodVariables = freeVariableSet codomain
        , nodeMap = IntMap.empty
        , edgeMap = IntMap.empty
        , variableMap = Map.empty
        }
    in do
      finalState <- build initialState
      guard $ validateFinalState config domain codomain finalState
      return $
        LabeledMor domain codomain (nodeMap finalState) (edgeMap finalState) (variableMap finalState)


buildMorphisms :: BuilderConfig -> BuilderState -> [BuilderState]
{-# INLINE buildMorphisms #-}
buildMorphisms config =
  mapAllEdges config >=> mapAllNodes config >=> mapAllVariables config


mapAll :: Monad m =>
  (BuilderState -> Bool) -> (BuilderState -> element) -> (BuilderState -> m element)
  -> (BuilderConfig -> element -> element -> BuilderState -> m BuilderState)
  -> BuilderConfig -> BuilderState -> m BuilderState
{-# INLINE mapAll #-}
mapAll noUnmappedElements pickDomElement pickCodElement addMapping config =
    recurse
  where
    recurse state =
      if noUnmappedElements state then
        return state
      else do
        let domainElement = pickDomElement state
        codomainElement <- pickCodElement state
        state' <- addMapping config domainElement codomainElement state
        recurse state'


mapAllEdges :: BuilderConfig -> BuilderState -> [BuilderState]
mapAllEdges =
  mapAll
    (IntMap.null . unmappedDomEdges)
    (snd . IntMap.findMin . unmappedDomEdges)
    (IntMap.elems . availableCodEdges)
    addEdgeMapping

mapAllNodes :: BuilderConfig -> BuilderState -> [BuilderState]
mapAllNodes =
  mapAll
    (IntMap.null . unmappedDomNodes)
    (snd . IntMap.findMin . unmappedDomNodes)
    (IntMap.elems . availableCodNodes)
    addNodeMapping

mapAllVariables :: BuilderConfig -> BuilderState -> [BuilderState]
mapAllVariables =
  mapAll
    (Set.null . unmappedDomVariables)
    (Set.findMin . unmappedDomVariables)
    (Set.elems . availableCodVariables)
    addVariableMapping


-- | Assumes the domain edgein unmapped and the codomain edge is available.
addEdgeMapping :: BuilderConfig -> LEdge -> LEdge -> BuilderState -> [BuilderState]
addEdgeMapping config domainEdge codomainEdge state =
  do
    state' <- addNodeMapping' (sourceId domainEdge) (sourceId codomainEdge) state
    state'' <- addNodeMapping' (targetId domainEdge) (targetId codomainEdge) state'

    let state''' = updateAfterMappingEdge config domainEdge codomainEdge state''

    let domainId = fromEnum $ edgeId domainEdge
    let codomainId = edgeId codomainEdge

    return $
      state'''
        { edgeMap = IntMap.insert domainId codomainId (edgeMap state''')
        , unmappedDomEdges = IntMap.delete domainId (unmappedDomEdges state''')
        }

  where
    addNodeMapping' domainNodeId codomainNodeId state =
      case IntMap.lookup (fromEnum domainNodeId) (unmappedDomNodes state) of
        Nothing -> do
          -- Ensure the node was already mapped correctly
          guard $ IntMap.lookup (fromEnum domainNodeId) (nodeMap state) == Just codomainNodeId
          return state

        Just domainNode ->
          case IntMap.lookup (fromEnum codomainNodeId) (availableCodNodes state) of
            Nothing ->
              []

            Just codomainNode ->
              addNodeMapping config domainNode codomainNode state


-- | Assumes the domain node is unmapped and the codomain node is available.
addNodeMapping :: BuilderConfig -> LNode -> LNode -> BuilderState -> [BuilderState]
addNodeMapping config domainNode codomainNode state =
  do
    state' <- addVariableMapping' (nodeLabel domainNode, nodeLabel codomainNode) state
    let state'' = updateAfterMappingNode config domainNode codomainNode state'

    let domainId = fromEnum $ nodeId domainNode
    let codomainId = nodeId codomainNode

    return $
      state''
        { nodeMap = IntMap.insert domainId codomainId (nodeMap state'')
        , unmappedDomNodes = IntMap.delete domainId (unmappedDomNodes state'')
        }

  where
    addVariableMapping' vars state =
      case vars of
        (Nothing, _) ->
          -- Unlabeled nodes can be mapped to labeled nodes
          return state

        (Just _, Nothing) ->
          -- Labeled nodes must be mapped to labeled nodes
          []

        (Just domainVar, Just codomainVar) ->
          case Map.lookup domainVar (variableMap state) of
            Just previousMapping ->
              [ state | previousMapping == codomainVar ]

            Nothing ->
              if Set.member codomainVar (availableCodVariables state) then
                addVariableMapping config domainVar codomainVar state

              else
                []


-- | Assumes the domain variable is unmapped and the codomain variable is available
addVariableMapping :: BuilderConfig -> Variable -> Variable -> BuilderState -> [BuilderState]
addVariableMapping config domainVar codomainVar state =
  let
    state' =
      updateAfterMappingVariable config domainVar codomainVar state
  in
    return $
      state'
        { variableMap =
            Map.insert domainVar codomainVar (variableMap state')
        , unmappedDomVariables =
            Set.delete domainVar (unmappedDomVariables state')
        }



asIntMap :: Enum k => [(k, v)] -> IntMap v
asIntMap =
  IntMap.fromList . map (first fromEnum)


asIntSet :: Enum k => [k] -> IntSet
asIntSet =
  IntSet.fromList . map fromEnum