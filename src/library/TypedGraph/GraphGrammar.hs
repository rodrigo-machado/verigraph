module TypedGraph.GraphGrammar (
      graphGrammar
    , GraphGrammar
    , initialGraph
    , constraints
    , rules
    , sndOrderRules
    , typeGraph
) where

import qualified Abstract.Morphism     as M
import           Graph.Graph           (Graph)
import           Graph.GraphMorphism
import           SndOrder.Rule         (SndOrderRule)
import           TypedGraph.Constraint
import           TypedGraph.GraphRule  (GraphRule)

-- TODO: use a list of initial Graphs instead of a single graph
-- TODO: extract as DPO grammar?
data GraphGrammar a b = GraphGrammar {
                            initialGraph  :: GraphMorphism a b
                          , constraints   :: [Constraint a b]
                          , rules         :: [(String, GraphRule a b)]
                          , sndOrderRules :: [(String, SndOrderRule a b)]
                        } deriving (Show, Read)

graphGrammar :: GraphMorphism a b -> [Constraint a b] -> [(String, GraphRule a b)] -> [(String, SndOrderRule a b)]
  -> GraphGrammar a b
graphGrammar = GraphGrammar

typeGraph :: GraphGrammar a b -> Graph a b
typeGraph    = M.codomain . initialGraph
