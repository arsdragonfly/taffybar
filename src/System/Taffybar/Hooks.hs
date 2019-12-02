-----------------------------------------------------------------------------
-- |
-- Module      : System.Taffybar.Hooks
-- Copyright   : (c) Ivan A. Malison
-- License     : BSD3-style (see LICENSE)
--
-- Maintainer  : Ivan A. Malison
-- Stability   : unstable
-- Portability : unportable
-----------------------------------------------------------------------------

module System.Taffybar.Hooks
  ( module System.Taffybar.DBus
  , module System.Taffybar.Hooks
  , ChromeTabImageData(..)
  , getChromeTabImageDataChannel
  , getChromeTabImageDataTable
  , getX11WindowToChromeTabId
  , refreshBatteriesOnPropChange
  ) where

import           BroadcastChan
import           Control.Concurrent
import           Control.Monad
import           Control.Monad.Trans.Class
import           Control.Monad.Trans.Reader
import qualified Data.MultiMap as MM
import           System.Log.Logger
import           System.Taffybar.Context
import           System.Taffybar.DBus
import           System.Taffybar.Information.Battery
import           System.Taffybar.Information.Chrome
import           System.Taffybar.Information.Network
import           System.Environment.XDG.DesktopEntry
import           System.Taffybar.LogFormatter
import           System.Taffybar.Util

newtype NetworkInfoChan = NetworkInfoChan (BroadcastChan In [(String, (Rational, Rational))])

buildInfoChan :: Double -> IO NetworkInfoChan
buildInfoChan interval = do
  chan <- newBroadcastChan
  _ <- forkIO $ monitorNetworkInterfaces interval (void . writeBChan chan)
  return $ NetworkInfoChan chan

getNetworkChan :: TaffyIO NetworkInfoChan
getNetworkChan = getStateDefault $ lift $ buildInfoChan 2.0

setTaffyLogFormatter :: String -> IO ()
setTaffyLogFormatter loggerName = do
  handler <- taffyLogHandler
  updateGlobalLogger loggerName $ setHandlers [handler]

withBatteryRefresh :: TaffybarConfig -> TaffybarConfig
withBatteryRefresh = appendHook refreshBatteriesOnPropChange

getDirectoryEntriesByClassName :: TaffyIO (MM.MultiMap String DesktopEntry)
getDirectoryEntriesByClassName =
  getStateDefault readDirectoryEntriesDefault

updateDirectoryEntriesCache :: TaffyIO ()
updateDirectoryEntriesCache = ask >>= \ctx ->
  void $ lift $ foreverWithDelay (60 :: Double) $ flip runReaderT ctx $
       putState readDirectoryEntriesDefault

readDirectoryEntriesDefault :: TaffyIO (MM.MultiMap String DesktopEntry)
readDirectoryEntriesDefault = lift $
  indexDesktopEntriesByClassName <$> getDirectoryEntriesDefault
