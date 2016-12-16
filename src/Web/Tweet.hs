{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric     #-}

-- | Various utilities to tweet using the twitter api
-- 
-- Make sure you have a file credentials file (default `.cred`) with the following info:
--
-- api-key: API_KEY
--
-- api-sec: API_SECRE
--
-- tok: OAUTH_TOKEN
--
-- tok-sec: TOKEN_SECRET

module Web.Tweet
    ( tweet
    , signRequest
    , urlString
    ) where

import Data.Aeson
import GHC.Generics
import Network.HTTP.Client
import Network.HTTP.Client.TLS
import Network.HTTP.Types.Status (statusCode)
import Web.Authenticate.OAuth
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as BSL
import Data.Char (toLower)

-- | Data type for our request
data Tweet = Tweet
    { status    :: String
    , trim_user :: Bool
    } deriving Generic

instance ToJSON Tweet where

-- | tweet a byteString, with credentials from a given file
tweet :: FilePath -> BS.ByteString -> IO ()
tweet filepath content = do
    requestString <- urlString content
    manager <- newManager tlsManagerSettings
    initialRequest <- parseRequest ("https://api.twitter.com/1.1/statuses/update.json" ++ requestString)
    request <- signRequest filepath $ initialRequest { method = "POST" }
    response request manager

-- | print output of a request
response :: Request -> Manager -> IO ()
response request manager = do
    response <- httpLbs request manager
    putStrLn $ "The status code was: " ++ show (statusCode $ responseStatus response)
    BSL.putStrLn $ responseBody response

-- | Sign a request using your OAuth dev token.
-- Uses the IO monad because signatures require a timestamp
signRequest :: FilePath -> Request -> IO Request
signRequest filepath req = do
    o <- oAuth filepath
    c <- credential filepath
    signOAuth o c req

-- | Create an OAuth token
oAuth :: FilePath -> IO OAuth
oAuth filepath = do
    secret <- (lineByKey "api-sec") <$> getConfigData filepath
    key <- (lineByKey "api-key") <$> getConfigData filepath
    let url = "api.twitter.com"
    return newOAuth { oauthConsumerKey = key , oauthConsumerSecret = secret , oauthServerName = url }

-- | Create a new credential from a token and secret component of that token
credential :: FilePath -> IO Credential
credential filepath = newCredential <$> token <*> secretToken
    where token       = (lineByKey "tok") <$> getConfigData filepath
          secretToken = (lineByKey "tok-sec") <$> getConfigData filepath

-- | Pick out a key value from a key
lineByKey :: BS.ByteString -> [(BS.ByteString, BS.ByteString)] -> BS.ByteString
lineByKey key = snd . head . (filter (\i -> fst i == key))

-- | Get pairs of "key" to search for and actual values
getConfigData :: FilePath -> IO [(BS.ByteString, BS.ByteString)]
getConfigData filepath = zip <$> keys <*> content
    where content = (map (BS.pack . filterLine)) . lines <$> file
          keys    = (map (BS.pack . keyLine)) . lines <$> file
          file    = readFile filepath

keyLine :: String -> String
keyLine = takeWhile (/=':')

-- | Filter a line of a file for only the actual data and no descriptors
filterLine :: String -> String
filterLine = reverse . (takeWhile (not . (`elem` (" :" :: String)))) . reverse

-- | Convert a byteString to the percent-encoded version
urlString :: BS.ByteString -> IO String
urlString content = do
    return $ "?status=" ++ ((BS.unpack . paramEncode) content) ++ "&trim_user" ++ (map toLower $ show True)
