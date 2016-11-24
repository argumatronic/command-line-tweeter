{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric     #-}

module Tweet
    ( exec
    ) where

import Data.Aeson
import GHC.Generics
import Network.HTTP.Client
import Network.HTTP.Client.TLS
import Network.HTTP.Types.Status (statusCode)
import Web.Authenticate.OAuth hiding (signOAuth')
import qualified Data.ByteString.Char8 as BS
import Control.Monad.IO.Class (MonadIO)

data Tweet = Tweet
    { status    :: String
    , trim_user :: Bool
    } deriving Generic

instance ToJSON Tweet where

--query twitter to post stdin (aka what's passed in via pipes)
exec :: IO ()
exec = do
    tweet <- inputToTweet
    let requestObject = toJSON tweet
    manager <- newManager tlsManagerSettings
    initialRequest <- parseRequest "https://api.twitter.com/1.1/statuses/update.json" --"http://httpbin.org/post" to test
    signedRequest <- signRequest initialRequest
    print signedRequest
    let request = signedRequest { method = "POST", requestBody = RequestBodyLBS $ encode requestObject }
    --response
    response <- httpLbs request manager
    putStrLn $ "The status code was: " ++ (show $ statusCode $ responseStatus response)
    print $ responseBody response

signRequest :: Request -> IO Request
signRequest = signOAuth oAuth credential
    where oAuth = newOAuth { oauthConsumerKey = key , oauthConsumerSecret = secret }
          credential  = newCredential key secret
          key         = "739626641450635265-qiX6qWR9uoqhoZZjTQfscrWFSjwiHMC"
          secret      = "n7sUjCinVt3abFD7Qgnxd9MnaMFK6OXYS119eWWzR"

inputToTweet :: IO Tweet
inputToTweet = do
    content <- fmap (take 140) getContents --aka stdin aka compatible w/ pipes
    return Tweet { status = content, trim_user = True }
