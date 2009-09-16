module Main where
import System.Directory
import System.FilePath
import System.Console.GetOpt
import System.Environment
import System.Exit
import System.IO
import Control.Monad
import qualified Data.Map as M
import Data.List
import Data.Ord
import Data.Time
import Text.Printf
import Data.Maybe
import Data.Version (showVersion)
import qualified Text.Tabular.AsciiArt as TA

import TimeLog
import Data
import Categorize
import Stats

import Paths_arbtt (version)

data Flag = Help | Version |
        Report Report |
        Filter Filter |
	ReportOption ReportOption
        deriving Eq

getReports = mapMaybe (\f -> case f of {Report r -> Just r; _ -> Nothing})
getFilters = mapMaybe (\f -> case f of {Filter f -> Just f; _ -> Nothing})
getRepOpts = mapMaybe (\f -> case f of {ReportOption o -> Just o; _ -> Nothing})

versionStr = "arbtt-stats " ++ showVersion version
header = "Usage: arbtt-stats [OPTIONS...]"

options :: [OptDescr Flag]
options =
     [ Option "h?"     ["help"]
              (NoArg Help)
	      "show this help"
     , Option ['V']     ["version"]
              (NoArg Version)
	      "show the version number"
--     , Option ['g']     ["graphical"] (NoArg Graphical)    "render the reports as graphical charts"
     , Option ['x']     ["exclude"]
              (ReqArg (Filter . Exclude . Activity Nothing) "TAG")
	      "ignore samples containing this tag"
     , Option ['o']     ["only"]
              (ReqArg (Filter . Only . read) "TAG")
	      "only consider samples containing this tag"
     , Option []        ["also-inactive"]
              (NoArg (Filter AlsoInactive))
	      "include samples with the tag \"inactive\""
     , Option ['m']     ["min-percentage"]
              (ReqArg (ReportOption . MinPercentage . read) "PERC")
	      "do not show tags with a percentage lower than PERC% (default: 1)"
     , Option ['i']     ["information"]
              (NoArg (Report GeneralInfos))
	      "show general statistics about the data"
     , Option ['t']     ["total-time"]
              (NoArg (Report TotalTime))
	      "show total time for each tag"
     , Option ['c']     ["category"]
              (ReqArg (Report . Category) "CATEGORY")
	      "show statistics about category CATEGORY"
     ]


main = do
  args <- getArgs
  flags <- case getOpt Permute options args of
          (o,[],[]) | Help `notElem` o  && Version `notElem` o -> return o
          (o,_,_) | Version `elem` o -> do
                hPutStrLn stderr versionStr
                exitSuccess
          (o,_,_) | Help `elem` o -> do
                hPutStr stderr (usageInfo header options)
                exitSuccess
          (_,_,errs) -> do
                hPutStr stderr (concat errs ++ usageInfo header options)
                exitFailure

  dir <- getAppUserDataDirectory "arbtt"

  let categorizeFilename = dir </> "categorize.cfg"
  fileEx <- doesFileExist categorizeFilename
  unless (fileEx) $ do
     putStrLn $ printf "Configuration file %s does not exist." categorizeFilename
     putStrLn $ "Please see the example file and the README for more details"
     exitFailure
  categorizer <- readCategorizer categorizeFilename

  let captureFilename = dir </> "capture.log"
  captures <- readTimeLog captureFilename
  let allTags = categorizer captures
  when (null allTags) $ do
     putStrLn "Nothing recorded yet"
     exitFailure
      
  let tags = applyFilters (getFilters flags) allTags
  let opts = case getRepOpts flags of {[] -> [MinPercentage 1]; ropts -> ropts }
  let reps = case getReports flags of {[] -> [TotalTime]; reps -> reps }

  -- These are defined here, but of course only evaluated when any report
  -- refers to them. Some are needed by more than one report, which is then
  -- advantageous.
  let c = prepareCalculations allTags tags
  
  sequence_ $ intersperse (putStrLn "")
            $ map (\r -> let (h,t) = renderReport opts c r in do
  			putStrLnUnderlined h
			putStr (TA.render id id id t)
	                )
	    $ reps

putStrLnUnderlined str = do
        putStrLn str
        putStrLn $ map (const '=') str


{-
import Data.Accessor
import Graphics.Rendering.Chart
import Graphics.Rendering.Chart.Gtk

        graphicalReport TotalTime = do
          let values = zipWith (\(k,v) n -> (PlotIndex n,[fromIntegral v::Double])) (M.toList sums) [1..]
          let plot = plot_bars_values ^= values $ defaultPlotBars
          let layoutaxis = laxis_generate ^= autoIndexAxis (map (show.fst) (M.toList  sums)) $
                           defaultLayoutAxis
          let layout = layout1_plots ^= [Right (plotBars plot)] $
                       layout1_bottom_axis ^= layoutaxis $
                       defaultLayout1
          do renderableToWindow (toRenderable layout) 800 600
-}