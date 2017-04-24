module TypedGraph.Morphism (
      TypedGraphMorphism
    , idMap
    , isPartialInjective
    , invert
    , nodeIdsFromDomain
    , edgeIdsFromDomain
    , edgesFromDomain
    , nodeIdsFromCodomain
    , edgeIdsFromCodomain
    , edgesFromCodomain
    , graphDomain
    , graphCodomain
    , mapping
    , applyNode
    , applyEdge
    , buildTypedGraphMorphism
    , checkDeletion
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
    , untypedUpdateNodeRelation
    , orphanTypedNodeIds
    , orphanTypedEdgeIds
    , orphanTypedEdges
    , reflectIdsFromTypeGraph
    , reflectIdsFromCodomain
    , reflectIdsFromDomains
) where

import           TypedGraph.Morphism.AdhesiveHLR  (checkDeletion)
import           TypedGraph.Morphism.Cocomplete   ()
import           TypedGraph.Morphism.Core
import           TypedGraph.Morphism.EpiPairs     ()
import           TypedGraph.Morphism.FindMorphism ()
