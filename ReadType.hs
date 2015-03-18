{-# LANGUAGE LambdaCase #-}
module ReadType where

import GHC
import GhcMonad
import TcRnMonad(setXOptM)
import TcType (UserTypeCtxt(GhciCtxt))
import DynFlags(ExtensionFlag(Opt_PolyKinds))
import RnTypes (rnLHsType)
import RnEnv (HsDocContext(GHCiCtx), bindLocatedLocalsRn)
import CoAxiom(Role(Nominal))
import FamInst (tcGetFamInstEnvs)
import FamInstEnv (normaliseType)
import TcHsType (tcHsSigType)
import TcEnv (tcExtendTyVarEnv)
import Parser (parseType)
import UniqSet (uniqSetToList)
import Var (mkTyVar)
import Kind (anyKind)
import HsTypes
import Util
import Control.Monad.Error
import Types
import GhcUtil (withTyVarsInScope)

-- useful things
-- RnTypes/rnHsTyKi
-- RnTypes/extractHsTysRdrTyVars
-- consider adding undbound type vars to environment

-- c/f TcRnDriver.hs/tcRnType. I just removed the failIfErrsM.
rdrTypeToTypeWithTyVarsInScope tvNames rdr_type = do
  hsc_env <- getSession
  liftIO
    . runTcInteractive hsc_env
    . setXOptM Opt_PolyKinds
    . withTyVarsInScope tvNames
    $ tcRdrTypeToType rdr_type

tcRdrTypeToType rdr_type = do
  (rn_type, _fvs) <- rnLHsType GHCiCtx (noLoc $ mkImplicitHsForAllTy (noLoc []) rdr_type)
  ty <- tcHsSigType GhciCtxt rn_type
  fam_envs <- tcGetFamInstEnvs
  let (_, ty') = normaliseType fam_envs Nominal ty
  return ty'

-- any kind quantifications should ideally be pushed in all the way.
-- for now I'm happy to replace  

readTypeWithTyVarsInScope :: [Name] -> String -> M Type
readTypeWithTyVarsInScope tvNames str =
  lift (runParserM parseType str) >>= \case
    Left s  -> throwError s
    Right t -> do
      let errMsg = "Could not make sense of type in current env."
      (_, mt) <- lift (rdrTypeToTypeWithTyVarsInScope tvNames t)
      maybe (throwError errMsg) return mt

readType :: String -> M Type
readType = readTypeWithTyVarsInScope []

-- getTypeQuantified str =
