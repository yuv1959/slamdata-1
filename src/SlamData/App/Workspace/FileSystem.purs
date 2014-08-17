module SlamData.App.Workspace.FileSystem
  ( filesystem
  , FileSystemProps()
  , FileSystemState()
  ) where

  import Control.Lens ((^.), (..))
  import Control.Monad.Eff (Eff())

  import Data.Array (sort)
  import Data.Function (mkFn3)
  import Data.String (charAt, length)

  import React (coerceThis, createClass, eventHandler, spec)
  import React.TreeView (treeView)
  import React.Types
    ( Component()
    , ComponentClass()
    , ReactSyntheticEvent()
    , ReactThis()
    )

  import SlamData.Components (dirOpenIcon, fileIcon)
  import SlamData.Lens (_children, _fileTypeRec, _name)
  import SlamData.Types (SlamDataEventTy(..), SlamDataRequest(), SlamDataRequestEff())
  import SlamData.Types.Workspace.FileSystem (FileType(..), FileTypeRec())

  import qualified React.DOM as D

  type FileSystemProps eff =
    { files :: FileType
    , request :: SlamDataRequest eff
    }
  type FileSystemState = {}
  type FileSystemTreeState =
    {collapsed :: Boolean}

  filesystem :: forall eff. ComponentClass (FileSystemProps eff) FileSystemState
  filesystem = createClass spec
    { displayName = "FileSystem"
    , shouldComponentUpdate = mkFn3 \this props _ -> pure $
      this.props.files /= props.files
    , render = \this -> pure $ D.div {className: "slamdata-panel"}
      [fsTab, fsContent this.props.files this.props.request]
    }

  fsTab :: Component
  fsTab = D.dl {className: "tabs", "data-tab": "true"}
    [D.dd {className: "tab active"}
      [D.a {} [D.rawText "FileSystem"]]
    ]

  fsContent :: forall eff. FileType -> SlamDataRequest eff -> Component
  fsContent files request = D.div {className: "tabs-content"}
    [D.div {className: "content active"}
      [ D.div {className: "toolbar button-bar"}
        [ D.ul {className: "button-group"} []
        , D.ul {className: "button-group"} []
        ]
      , D.hr {} []
      , D.div {className: "actual-content"}
        [reify {files: files, request: request} []]
      ]
    ]

  reify :: forall eff. ComponentClass (FileSystemProps eff) FileSystemTreeState
  reify = createClass spec
    { displayName = "FileSystemTree"
    , getInitialState = \_ -> pure {collapsed: true}
    , render = \this -> case this.props.files of
      (FileType {"type" = "file", name = n}) -> pure $ D.div {} [D.rawText n]
      (FileType {"type" = "directory", name = n, children = c}) -> pure $
        treeView { collapsed: this.state.collapsed
                 , defaultCollapsed: true
                 , nodeLabel: D.span
                    {onClick: eventHandler (coerceThis this) toggleTree}
                    [D.rawText (this.props.files^._fileTypeRec.._name)]
                 , onClick: eventHandler (coerceThis this) toggleTree

                 }
          ((\f -> reify {files: f, request: this.props.request} []) <$> sort (this.props.files^._fileTypeRec.._children))
    }

  toggleTree :: forall fields eff eff' event
             .  ReactThis fields (FileSystemProps eff) FileSystemTreeState
             -> ReactSyntheticEvent event
             -> Eff (SlamDataRequestEff eff) Unit
  toggleTree this _ =
    if this.state.collapsed then do
      this.props.request $ ReadFileSystem $ normalize (this.props.files^._fileTypeRec.._name)
      pure $ this.setState {collapsed: not this.state.collapsed}
    else
      pure $ this.setState {collapsed: not this.state.collapsed}

  normalize path | length path > 0 && charAt 0 path /= "/" = "/" ++ path ++ "/"
  normalize path | length path == 0                        = "/"
  normalize path                                           =        path ++ "/"
