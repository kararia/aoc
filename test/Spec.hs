{-# LANGUAGE OverloadedStrings #-}
module Main (main) where

import Test.Hspec
import Test.QuickCheck

import qualified ListProblem
import qualified TypeCheck
import qualified Type
import qualified ListAst
import qualified Ast
import qualified Value as V
import Builtins (listContext)

import qualified ConwayProblem

number = Ast.Inte 42
numTy = Type.Number
boolTy = Type.Boolean

sub a b = Ast.Subtract a b
div' a b = Ast.Divide a b

a &&& b = Ast.And a b

gt = Ast.Gt

ident = Ast.Identifier

lam = Ast.FloatingLambda . Ast.Body

a |> b = Ast.Pipe a b

shouldBeUnificationFailureOf (Left (TypeCheck.UnificationFailure _ _ a b _)) (c, d) =
  (a, b) `shouldBe` (c, d)

shouldBeUnificationFailureOf v _ =
  error $ "Expected unification failure, got " ++ show v

main :: IO ()
main = hspec $ do
  describe "ConwayProblem.runConwayProblem" $ do
    it "solves 2019 D24 P1" $ do
      Just (_, _, V.I result, _) <- ConwayProblem.runConwayProblem "./examples/y2019d24p1.aoc"
      result `shouldBe` 18844281

  describe "ListProblem.runListProblem" $ do
    it "solves 2018 D1 P1" $ do
      Just (_, _, V.I result, _) <- ListProblem.runListProblem "./examples/y2018d1p1.aoc"
      result `shouldBe` 595

    it "solves 2018 D1 P2" $ do
      Just (_, _, V.I result, _) <- ListProblem.runListProblem "./examples/y2018d1p2.aoc"
      result `shouldBe` 80598

    it "solves 2019 D1 P1" $ do
      Just (_, _, V.I result, _) <- ListProblem.runListProblem "./examples/y2019d1p1.aoc"
      result `shouldBe` 3308377

    it "solves 2019 D1 P2" $ do
      Just (_, _, V.I result, _) <- ListProblem.runListProblem "./examples/y2019d1p2.aoc"
      result `shouldBe` 4959709

  describe "TypeCheck.ensureOneFreeOrIdentInEachStep" $ do
    it "finds the identifier in a simple &&" $ do
      TypeCheck.ensureOneFreeOrIdentInEachStep listContext (lam (number &&& ident "x")) `shouldBe` Right ()

    it "finds the identifier some piped together steps" $ do
      TypeCheck.ensureOneFreeOrIdentInEachStep listContext ((lam (number &&& ident "x")) |> (lam (ident "x" `div'` number))) `shouldBe` Right ()

  describe "TypeCheck.unify" $ do
    it "numbers unify with numbers" $ do
      TypeCheck.unify listContext number numTy Nothing `shouldBe` Right Nothing

    it "numbers don't unify with bools" $ do
      TypeCheck.unify listContext number boolTy Nothing `shouldBeUnificationFailureOf` (boolTy, numTy)

    it "simple free variables can be unified" $ do
      TypeCheck.unify listContext (ident "a") numTy Nothing `shouldBe` Right (Just numTy)

    it "mismatches when already unified cause errors" $ do
      TypeCheck.unify listContext (ident "a") numTy (Just boolTy) `shouldBeUnificationFailureOf` (boolTy, numTy)

    it "unifications can successfully match operands" $ do
      TypeCheck.unify listContext (ident "a" `sub` ident "a") numTy Nothing `shouldBe` Right (Just numTy)

    it "unification works on builtin identifiers" $ do
      TypeCheck.unify listContext (ident "true") boolTy Nothing `shouldBe` Right Nothing

    it "when unification fails on builtins the errors make sense" $ do
      TypeCheck.unify listContext (ident "true") numTy Nothing `shouldBeUnificationFailureOf` (numTy, boolTy)

    it "unification flows down the tree and to the right" $ do
      TypeCheck.unify listContext (ident "a" &&& (ident "a" `gt` number)) boolTy Nothing `shouldBeUnificationFailureOf` (boolTy, numTy)

    it "silly fat test" $ do
      TypeCheck.unify listContext ((ident "a" `sub` ident "a") `gt` ident "a") boolTy Nothing `shouldBe` Right (Just numTy)

    it "can unify a left-side variable" $ do
      TypeCheck.unify listContext ((ident "x" `div'` number) `sub` number) numTy Nothing `shouldBe` Right (Just numTy)
