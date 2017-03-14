-- | Provides IO action that parses command line options and tweets from stdin
module Web.Tweet.Exec ( exec
                      , Program (Program)) where

import Web.Tweet
import Options.Applicative
import qualified Data.ByteString.Char8 as BS
import Control.Monad
import Data.Foldable (fold)
import Data.Monoid
import System.Directory

-- | Data type for our program: one optional path to a credential file, (optionally) the number of tweets to make, the id of the status you're replying to, and a list of users you wish to mention.
data Program = Program { subcommand :: Command , cred :: Maybe FilePath }

data Command = Timeline { count :: Maybe Int , color :: Bool } | Send { tweets :: Maybe Int, replyId :: Maybe String, replyHandles :: Maybe [String] } | Profile { count :: Maybe Int , color :: Bool , screenName :: String } | Raw { screenName :: String }

-- | query twitter to post stdin with no fancy options
fromStdIn :: Int -> FilePath -> IO ()
fromStdIn = threadStdIn [] Nothing

-- | Threaded tweets from stdIn
threadStdIn :: [String] -> Maybe Int -> Int -> FilePath -> IO ()
threadStdIn hs idNum num filepath = do
    contents <- getContents
    thread contents hs idNum num filepath

-- | Executes parser
exec :: IO ()
exec = execParser opts >>= select
    where
        opts = info (helper <*> program)
            (fullDesc
            <> progDesc "Send from stdin!"
            <> header "clit - a Command Line Interface Sender")

-- | Executes program
select :: Program -> IO ()
select (Program (Send (Just n) Nothing Nothing) Nothing) = fromStdIn n =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Send Nothing Nothing Nothing) Nothing) = fromStdIn 4  =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Send (Just n) Nothing Nothing) (Just file))  = fromStdIn n file
select (Program (Send Nothing Nothing Nothing) (Just file) ) = fromStdIn 4 file
select (Program (Send (Just n) (Just id) (Just handles)) Nothing) = threadStdIn handles (read id) n  =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Send (Just n) (Just id) (Just handles)) (Just file)) = threadStdIn handles (pure . read $ id) n file
select (Program (Send Nothing (Just id) (Just handles)) (Just file))  = threadStdIn handles (pure . read $ id) 4 file
select (Program (Send (Just n) (Just id) Nothing) Nothing) = threadStdIn [] (pure . read $ id) n  =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Send Nothing (Just id) Nothing) Nothing) = threadStdIn [] (pure . read $ id) 4  =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Send Nothing (Just id) (Just handles)) Nothing) = threadStdIn handles (pure . read $ id) 4  =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Send (Just n) (Just id) Nothing) (Just file)) = threadStdIn [] (pure . read $ id) n file
select (Program (Send (Just n) Nothing (Just handles)) (Just file)) = threadStdIn handles Nothing n file
select (Program (Timeline Nothing False) Nothing) = putStrLn =<< showTimeline 8 False  =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Timeline Nothing False) (Just file)) = putStrLn =<< showTimeline 8 False file
select (Program (Timeline (Just n) False) (Just file)) = putStrLn =<< showTimeline 8 False file
select (Program (Timeline (Just n) False) Nothing) = putStrLn =<< showTimeline 8 False  =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Timeline Nothing True) Nothing) = putStrLn =<< showTimeline 8 True  =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Timeline Nothing True) (Just file)) = putStrLn =<< showTimeline 8 True file
select (Program (Timeline (Just n) True) (Just file)) = putStrLn =<< showTimeline 8 True file
select (Program (Timeline (Just n) True) Nothing) = putStrLn =<< showTimeline 8 True  =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Profile (Just n) True name) (Just file)) = putStrLn =<< showProfile name n True file
select (Program (Profile Nothing True name) (Just file)) = putStrLn =<< showProfile name 12 True file
select (Program (Profile (Just n) True name) Nothing) = putStrLn =<< showProfile name n True  =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Profile Nothing True name) Nothing) = putStrLn =<< showProfile name 12 True  =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Profile (Just n) False name) (Just file)) = putStrLn =<< showProfile name n False file
select (Program (Profile Nothing False name) (Just file)) = putStrLn =<< showProfile name 12 False file
select (Program (Profile (Just n) False name) Nothing) = putStrLn =<< showProfile name n False  =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Profile Nothing False name) Nothing) = putStrLn =<< showProfile name 12 False  =<< (++ "/.cred") <$> getHomeDirectory
select (Program (Raw name) Nothing) = do
    raw' <- getRaw name =<< (++ "/.cred") <$> getHomeDirectory
    sequence_ $ putStrLn <$> [raw']
select (Program (Raw name) (Just file)) = do
    raw' <- getRaw name file
    sequence_ $ putStrLn <$> [raw'] --fix this idk

-- | Parser to return a program datatype
program :: Parser Program
program = Program
    <$> (hsubparser
        (command "send" (info tweet (progDesc "Send a tweet"))
        <> command "view" (info timeline (progDesc "Get your timeline"))
        <> command "user" (info profile (progDesc "Get a user's profile"))
        <> command "raw" (info raw (progDesc "Grab tweets en masse."))))
    <*> (optional $ strOption
        (long "cred"
        <> short 'c'
        <> metavar "CREDENTIALS"
        <> help "path to credentials"))

timeline :: Parser Command
timeline = Timeline
    <$> (optional $ read <$> strOption
        (long "count"
        <> short 'n'
        <> metavar "NUM"
        <> help "number of tweets to fetch, default 5"))
    <*> switch
        (long "color"
        <> short 'l'
        <> help "Display timeline with colorized terminal output.")

raw :: Parser Command
raw = Raw
  <$> argument str
    (metavar "SCREEN_NAME"
    <> help "Screen name of user whose tweets you want in bulk.")

profile :: Parser Command
profile = Profile
    <$> (optional $ read <$> strOption
        (long "count"
        <> short 'n'
        <> metavar "NUM"
        <> help "Number of tweets to fetch, default 12"))
    <*> switch
        (long "color"
        <> short 'l'
        <> help "Whether to display profile with colorized terminal output")
    <*> argument str
        (metavar "SCREEN_NAME"
        <> help "Screen name of user you want to view.")

tweet :: Parser Command
tweet = Send
    <$> (optional $ read <$> strOption
        (long "tweets"
        <> short 't'
        <> metavar "NUM"
        <> help "Number of tweets in a row, default 4"))
    <*> (optional $ strOption
        (long "reply"
        <> short 'r'
        <> help "id of status to reply to - be sure to include their handle, e.g. @my_build_errors"))
    <*> (optional $ some $ argument str
        (metavar "HANDLE1"
        <> help "handles to include in replies"))
