module ConcurrentRules
  ( Options
  , options
  , execute
  ) where

import           GlobalOptions

import           Abstract.AdhesiveHLR
import           Analysis.ConcurrentRules
import           Control.Monad
import           Options.Applicative
import qualified TypedGraph.GraphGrammar  as GG
import           TypedGraph.GraphRule
import           TypedGraph.Morphism
import qualified XML.GGXReader            as XML
import qualified XML.GGXWriter            as GW

data Options = Options
  { outputFile     :: String
  , generationType :: CRGenerationType
  , concRulesbyDep :: CRDependencies
  }

data CRGenerationType = MaxConcurrentRule | AllConcurrentRules

data CREpiPairsType = AllEpiPairs | OnlyInjectiveEpiPairs deriving (Eq)

options :: Parser Options
options = Options
  <$> strOption
    ( long "output-file"
    <> short 'o'
    <> metavar "FILE"
    <> action "file"
    <> help "GGX file that will be written, adding the concurrent rules to the original graph grammar")
  <*> crGenerationType
  <*> crDependencies

crGenerationType :: Parser CRGenerationType
crGenerationType =
      flag' MaxConcurrentRule
        ( long "max-rule"
         <> help "Generate only the concurrent rule with maximum overlap between calculateComatch and match")
  <|> flag' AllConcurrentRules
        ( long "all-rules"
          <> help "Generate concurrent rules for all possible overlaps between calculateComatch and match")

crDependencies :: Parser CRDependencies
crDependencies =
      flag AllOverlapings OnlyDependency
        ( long "by-dependency"
         <> help "Generate only the concurrent rules by the dependencies between the two rules")

execute :: GlobalOptions -> Options -> IO ()
execute globalOpts opts = do
    let dpoConf = dpoConfig globalOpts

    (gg,_) <- XML.readGrammar (inputFile globalOpts) (useConstraints globalOpts) dpoConf
    ggName <- XML.readGGName (inputFile globalOpts)
    names <- XML.readNames (inputFile globalOpts)
    sequences <- XML.readSequences gg (inputFile globalOpts)
    let makeConcurrentRules = case generationType opts of
                                MaxConcurrentRule  -> makeMaxConcurrentRules
                                AllConcurrentRules -> makeAllConcurrentRules
        dependencies = concRulesbyDep opts
        newRules = map (makeConcurrentRules dependencies (dpoConfig globalOpts) (GG.constraints gg)) sequences

    forM_ (zip sequences newRules) $ \((name, _), rules) ->
      when (null rules)
        (putStrLn $ "No concurrent rules were found for rule sequence '" ++ name ++ "'")

    let gg' = GG.graphGrammar (GG.initialGraph gg) [] (GG.rules gg ++ concat newRules) []
    GW.writeGrammarFile gg' ggName names (outputFile opts)


makeAllConcurrentRules :: CRDependencies -> DPOConfig -> [Constraint (TypedGraphMorphism a b)] -> (String, [GraphRule a b]) -> [(String, GraphRule a b)]
makeAllConcurrentRules dep conf constraints (baseName, sequence) = zipWith makeName (allConcurrentRules dep conf constraints sequence) [0::Int ..]
  where makeName rule idx = (baseName++"_"++show idx, rule)

makeMaxConcurrentRules :: CRDependencies -> DPOConfig -> [Constraint (TypedGraphMorphism a b)] -> (String, [GraphRule a b]) -> [(String, GraphRule a b)]
makeMaxConcurrentRules dep conf constraints (baseName, sequence) = zipWith makeName (maxConcurrentRules dep conf constraints sequence) [0::Int ..]
  where makeName rule idx = (baseName++"_"++show idx, rule)
