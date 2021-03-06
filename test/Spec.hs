{-# LANGUAGE OverloadedStrings #-}

import           System.Environment
import           Test.Hspec
import           Web.Tweet.Parser.FastParser
import           Web.Tweet.Sign

main :: IO ()
main = hspec $
    describe "fastParse" $ do
    -- file <- runIO $ BS.readFile "test/data"
    config <- runIO $ (<> "/.cred") <$> getEnv "HOME"
    configToml <- runIO $ (<> "/.cred.toml") <$> getEnv "HOME"
    parallel $ it "parses sample tweets wrong" $
        fastParse "" `shouldBe` Left "Error in $: not enough input"
    parallel $ it "parses a config file the same way with the toml parser" $
        ((==) <$> mkConfigToml configToml <*> mkConfig config) >>= (`shouldBe` True)
