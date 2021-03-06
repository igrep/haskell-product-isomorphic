{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleInstances #-}

-- |
-- Module      : Data.Functor.ProductIsomorphic.TH.Internal
-- Copyright   : 2017 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module defines templates to make product constructors.
module Data.Functor.ProductIsomorphic.TH.Internal (
  defineProductConstructor, defineTupleProductConstructor,

  reifyRecordType,
  ) where

import Language.Haskell.TH
  (Q, Name, tupleTypeName, Info (..), reify,
   TypeQ, arrowT, appT, conT, varT,
   Dec, ExpQ, conE, Con (..), TyVarBndr (..), )
import Language.Haskell.TH.Compat.Data (unDataD)
import Data.List (foldl')

import Data.Functor.ProductIsomorphic.Unsafe (ProductConstructor (..))


recordInfo' :: Info -> Maybe (((TypeQ, [Name]), ExpQ), (Maybe [Name], [TypeQ]))
recordInfo' =  d  where
  d (TyConI tcon) = do
    (_cxt, tcn, bs, _mk, [r], _ds) <- unDataD tcon
    let vns = map getTV bs
    case r of
      NormalC dcn ts   -> Just (((buildT tcn vns, vns), conE dcn), (Nothing, [return t | (_, t) <- ts]))
      RecC    dcn vts  -> Just (((buildT tcn vns, vns), conE dcn), (Just ns, ts))
        where (ns, ts) = unzip [(n, return t) | (n, _, t) <- vts]
      _                -> Nothing
  d _                  =  Nothing
  getTV (PlainTV n)    =  n
  getTV (KindedTV n _) =  n
  buildT tcn vns = foldl' appT (conT tcn) [ varT vn | vn <- vns ]

-- | Low-level reify interface for record type name.
reifyRecordType :: Name -> Q (((TypeQ, [Name]), ExpQ), (Maybe [Name], [TypeQ]))
reifyRecordType recTypeName =
  maybe
  (fail $ "Defined record type constructor not found: " ++ show recTypeName)
  return
  . recordInfo' =<< reify recTypeName

-- | Make template of ProductConstructor instance from type constructor name.
defineProductConstructor :: Name     -- ^ name of product or record type constructor
                         -> Q [Dec]  -- ^ result template
defineProductConstructor tyN = do
  (((tyQ, _), dtQ), (_, colts))  <- reifyRecordType tyN
  [d| instance ProductConstructor $(foldr (appT . (arrowT `appT`)) tyQ colts) where
        productConstructor = $(dtQ)
    |]

-- | Make template of ProductConstructor instance of tuple type.
defineTupleProductConstructor :: Int     -- ^ n-tuple
                              -> Q [Dec] -- ^ result template
defineTupleProductConstructor =
  defineProductConstructor . tupleTypeName
