module Handler.Journal where

import Import as I
import Data.List as L
import Handler.Common

getJournalR :: Handler Html
getJournalR = do
  master <- getYesod
  rawEntries <- runDB $ selectList [] [Desc TransactionId]
  entries <- return $ L.reverse $ L.take 30 rawEntries
  total <- return $ L.sum $ I.map (transactionAmount . entityVal) rawEntries
  timeLimit <- case L.null entries of
    False -> return $ transactionTime $ entityVal $ L.head $ entries
    True -> liftIO getCurrentTime
  cashChecks <- runDB $ selectList [CashCheckTime >=. timeLimit] [Asc CashCheckId]
  list <- return $ merge entries cashChecks
  cashBalance <- getCashierBalance
  defaultLayout $ do
    $(widgetFile "journal")

merge :: [Entity Transaction] -> [Entity CashCheck] -> [Either Transaction CashCheck]
merge [] [] = []
merge [] (c:cs) = (Right $ entityVal c) : merge [] cs
merge (t:ts) [] = (Left $ entityVal t) : merge ts []
merge (t:ts) (c:cs)
  | transactionTime (entityVal t) < cashCheckTime (entityVal c) = (Left $ entityVal t)  : merge ts (c:cs)
  | transactionTime (entityVal t) > cashCheckTime (entityVal c) = (Right $ entityVal c) : merge (t:ts) cs
