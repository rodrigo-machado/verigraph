module Abstract.Cocomplete (

  Cocomplete(..)

)

where

import           Abstract.Morphism

class (Morphism m) => Cocomplete m where

  -- | Given two morphisms @/f : A -> B/@ and @/g : A -> B/@ retuns the coequalizer morphism
  -- @/h : B -> X/@
  calculateCoequalizer :: m -> m -> m

  -- | Given a list of morphisms of the form @/f : A -> B/@ returns the coequalizer Morphism
  -- @/h : B -> X/@
  calculateNCoequalizer :: [m] -> m

  --calculateCoproduct :: m -> m -> (m,m)
