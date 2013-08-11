{-# LANGUAGE OverloadedStrings #-}
module Handler.Live where

import           Import
import           Yesod.Auth
import qualified Data.Text  as T
import           Data.Maybe (mapMaybe)
-------------------------------------------------------------------------------------------------------------
getLiveR :: Handler Html
getLiveR = do
  muser    <- maybeAuth
  mgroup   <- getMaybeGroup muser
  let permissions = getPermissions mgroup
      group       = (groupName . entityVal) <$> mgroup
  -------------------------------------------------------------------------------------------------------------------      
  showPosts <- getConfig configShowLatestPosts
  boards    <- runDB $ selectList ([]::[Filter Board]) []
  let f (Entity _ b) | boardHidden b ||
                       ( (isJust (boardViewAccess b) && isNothing group) ||
                         (isJust (boardViewAccess b) && notElem (fromJust group) (fromJust $ boardViewAccess b))
                       ) = Just $ boardName b
                     | otherwise = Nothing
      boards'  = mapMaybe f boards
  posts     <- runDB $ selectList [PostDeletedByOp ==. False, PostBoard /<-. boards', PostDeleted ==. False] [Desc PostDate, LimitTo showPosts]
  postFiles <- forM posts $ \e -> runDB $ selectList [AttachedfileParentId ==. entityKey e] []
  let postsAndFiles = zip posts postFiles
  -------------------------------------------------------------------------------------------------------------------
  geoIpEnabled' <- runDB $ mapM (getBy . BoardUniqName) $ nub $ map (postBoard . entityVal) posts
  let geoIpEnabled = map (boardName . entityVal) $ filter (boardEnableGeoIp . entityVal) $ catMaybes geoIpEnabled' 
  geoIps <- getCountries $ filter ((`elem`geoIpEnabled) . postBoard . entityVal . fst) postsAndFiles
  -------------------------------------------------------------------------------------------------------------------
  nameOfTheBoard  <- extraSiteName <$> getExtra
  msgrender       <- getMessageRender
  timeZone       <- getTimeZone  
  defaultLayout $ do
    setUltDestCurrent
    setTitle $ toHtml $ T.concat [nameOfTheBoard, " — ", msgrender MsgLatestPosts]
    $(widgetFile "live")
  
