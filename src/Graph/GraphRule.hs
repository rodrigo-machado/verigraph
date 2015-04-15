module Graph.GraphRule (
      graphRule
    , GraphRule
    , left
    , right
    , nacs
) where

import Graph.TypedGraphMorphism (TypedGraphMorphism)
import Abstract.Morphism
import Abstract.Valid

data GraphRule a b = GraphRule {
                          leftSide  :: TypedGraphMorphism a b
                        , rightSide :: TypedGraphMorphism a b
                        , getNacs   :: [TypedGraphMorphism a b]
                     } deriving (Show, Read)

left  = leftSide
right = rightSide
nacs  = getNacs
graphRule = GraphRule

instance Valid (GraphRule a b) where
    valid (GraphRule lside rside nacs) =
        valid lside &&
        valid rside &&
        all valid nacs &&
        (domain lside) == (domain rside)