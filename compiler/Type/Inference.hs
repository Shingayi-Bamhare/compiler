module Type.Inference where

import qualified Data.Map as Map

import qualified Type.Type as T
import qualified Type.Environment as Env
import qualified Type.Constrain.Expression as TcExpr
import qualified Type.Constrain.Declaration as TcDecl
import qualified Type.Solve as Solve

import SourceSyntax.Module
import qualified SourceSyntax.Expression as Expr
import SourceSyntax.PrettyPrint
import Text.PrettyPrint
import qualified Type.State as TS
import Control.Monad.State
import Control.Arrow (second)
import Transform.SortDefinitions as Sort

import System.IO.Unsafe  -- Possible to switch over to the ST monad instead of
                         -- the IO monad. Not sure if that'd be worthwhile.


infer :: MetadataModule t v -> Either [Doc] (Map.Map String T.Variable)
infer modul = unsafePerformIO $ do
  env <- Env.initialEnvironment (datatypes modul)
  var <- T.flexibleVar
  ctors <- forM (Map.keys (Env.constructor env)) $ \name ->
               do (_, vars, tipe) <- Env.freshDataScheme env name
                  return (name, (vars, tipe))

  let vars = concatMap (fst . snd) ctors
      header = Map.map snd (Map.fromList ctors)
      environ = T.CLet [ T.Scheme vars [] T.CTrue header ]
  constraint <- environ `fmap` TcExpr.constrain env (program modul) (T.VarN var)
  state <- execStateT (Solve.solve constraint) TS.initialState
  let errors = TS.sErrors state
  if null errors
      then return $ Right (Map.difference (TS.sSavedEnv state) header)
      else Left `fmap` sequence errors

