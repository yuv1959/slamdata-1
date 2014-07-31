module SlamData.Types where

  import Control.Monad.Eff (Eff(..))
  import Control.Monad.Identity (Identity(..))

  import Data.Argonaut.Combinators
  import Data.Argonaut.Core
  import Data.Argonaut.Decode
  import Data.Argonaut.Encode
  import Data.Either (Either(..))
  import Data.Foldable (foldl, foldMap, foldr, Foldable)
  import Data.Maybe (maybe, Maybe(..))
  import Data.Tuple (uncurry, Tuple(..))
  import Data.Traversable (sequence, traverse, Traversable)

  import qualified Data.Map as M

  -- TODO: These ports should be their own type, not `Number`.
  newtype Settings = Settings SettingsRec
  type SettingsRec =
    { sdConfig :: SDConfig
    , seConfig :: SEConfig
    }

  newtype SDConfig = SDConfig SDConfigRec
  type SDConfigRec =
    { server :: {location :: String, port :: Number}
    , nodeWebkit :: {java :: String}
    }

  newtype SEConfig = SEConfig SEConfigRec
  type SEConfigRec =
    { mountings :: M.Map String Mounting
    , server :: {port :: Number}
    }

  data Mounting = MountMongo MountingRec
  type MountingRec =
    { connectionUri :: String
    , database :: String
    }

  type SaveSettings eff = Settings -> Eff (fsWrite :: FSWrite | eff) Unit

  -- TODO: Move this to the appropriate library.
  foreign import data FS :: *
  foreign import data FSWrite :: !
  type FilePath = String

  instance encodeSDConfig :: EncodeJson Identity Identity SDConfig where
    encodeJson (Identity (SDConfig sdConfig)) = Identity $
      "server" := (  "location" := sdConfig.server.location
                  ~> "port" := sdConfig.server.port
                  ~> jsonEmptyObject
                  )
      ~> "nodeWebkit" := ("java" := sdConfig.nodeWebkit.java ~> jsonEmptyObject)
      ~> jsonEmptyObject

  instance decodeSDConfig :: DecodeJson Identity (Either String) SDConfig where
    decodeJson (Identity json) = maybe (Left "Not SDConfig.") Right $ do
      obj <- toObject json
      server <- M.lookup "server" obj >>= toObject
      location <- M.lookup "location" server >>= toString
      port <- M.lookup "port" server >>= toNumber
      nodeWebkit <- M.lookup "nodeWebkit" obj >>= toObject
      java <- M.lookup "java" nodeWebkit >>= toString
      pure (SDConfig { server: {location: location, port: port}
                     , nodeWebkit: {java: java}
                     })

  instance encodeMounting :: EncodeJson Identity Identity Mounting where
    encodeJson (Identity (MountMongo mounting)) = Identity $
      "mongodb" := (  "connectionUri" := mounting.connectionUri
                   ~> "database" := mounting.database
                   ~> jsonEmptyObject
                   )
      ~> jsonEmptyObject

  instance decodeMounting :: DecodeJson Identity (Either String) Mounting where
    decodeJson (Identity json) = maybe (Left "Not a MongoDB Mounting.") Right $ do
      obj <- toObject json
      mongodb <- M.lookup "mongodb" obj >>= toObject
      connectionUri <- M.lookup "connectionUri" mongodb >>= toString
      database <- M.lookup "database" mongodb >>= toString
      pure $ MountMongo { connectionUri: connectionUri
                        , database: database
                        }

  -- TODO: This should be `uncurry`, but have to wrap that record.
  encodeMounting' :: Tuple String Mounting -> JAssoc
  encodeMounting' (Tuple path mongodb) = path := mongodb

  instance encodeSEConfig :: EncodeJson Identity Identity SEConfig where
    encodeJson (Identity (SEConfig seConfig)) = Identity $
      "server" := ("port" := seConfig.server.port ~> jsonEmptyObject)
      ~> "mountings" := foldr (~>) jsonEmptyObject (encodeMounting' <$> M.toList seConfig.mountings)
      ~> jsonEmptyObject

  instance decodeSEConfig :: DecodeJson Identity (Either String) SEConfig where
    decodeJson (Identity json) = maybe (Left "Not SEConfig.") Right $ do
      obj <- toObject json
      server <- M.lookup "server" obj >>= toObject
      port <- M.lookup "port" server >>= toNumber
      mountings <- M.lookup "mountings" obj >>= toObject
      mountings' <- traverse decodeMaybe mountings
      pure $ SEConfig { server: {port: port}
                      , mountings: mountings'
                      }

  instance decodeMap :: (DecodeJson Identity (Either String) a) => DecodeJson Identity (Either String) (M.Map String a) where
    decodeJson (Identity json) = maybe (Left "Couldn't decode.") Right $ do
      obj <- toObject json
      traverse decodeMaybe obj

  -- Orphans

  instance foldableMap :: Foldable (M.Map k) where
    foldr f z ms = foldr f z $ M.values ms
    foldl f z ms = foldl f z $ M.values ms
    foldMap f ms = foldMap f $ M.values ms

  instance traversableMap :: (Ord k) => Traversable (M.Map k) where
    traverse f ms = foldr (\x acc -> M.union <$> x <*> acc) (pure M.empty) ((\fs -> uncurry M.singleton <$> fs) <$> (traverse f <$> M.toList ms))
    sequence = traverse id
