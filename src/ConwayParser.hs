{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module ConwayParser
       ( conway
       , twoDimensionalConwayInput
       , oneDimensionalConwayInput
       ) where

import qualified Ast as Conway
import qualified ConwayAst as Conway
import qualified Data.Map.Strict as M
import           Data.Text hiding (zip, maximum, length)
import qualified Parser as P
import           Text.Megaparsec
import           Text.Megaparsec.Char
import qualified Value as V

conway :: P.Parser Conway.Problem
conway = do
  _ <- P.ws *> P.lstr "conway" *> P.lstr "of"
  dim <- dimensions
  statePath <- initialStatePath
  aliases <- cellAliases
  transitions <- cellTransitions aliases
  oob <- optional $ outOfBoundsCells aliases
  _ <- P.lstr "solution"
  code <- P.code
  eof
  pure $ Conway.ConwayProblem
    { Conway.initialStateAt=statePath
    , Conway.dimensions=dim
    , Conway.cellAliases=aliases
    , Conway.cellTransitions=transitions
    , Conway.solution=Conway.Solution code
    , Conway.outOfBoundsCellsAre=oob
    }

outOfBoundsCells :: Conway.CellAliases -> P.Parser Conway.CellIdent
outOfBoundsCells aliases =
  P.lstr "an" *> P.lstr "out-of-bounds" *> P.lstr "cell" *> P.lstr "is" *> alias aliases

oneDimensionalConwayInput :: Conway.CellTransitions -> Conway.CellAliases -> P.Parser V.Value
oneDimensionalConwayInput transitions aliases = do
  r <- row
  let cells = (\(x, v) -> ((x, 0), v)) <$> zip [0..] r
  pure $ V.Grid transitions (V.WidthHeight{ V.width=toInteger $ length r, V.height=1 }) $ M.fromList cells

  where
    row :: P.Parser [Char]
    row = some cellState

    cellState :: P.Parser Char
    cellState = choice ((\(Conway.CellIdent c, _) -> char c) <$> aliases)

twoDimensionalConwayInput :: Conway.CellTransitions -> Conway.CellAliases -> P.Parser V.Value
twoDimensionalConwayInput transitions aliases = do
  rows <- grid
  let cells = positionCells rows
  let width = maximum $ fmap ((+ 1) . fst . fst) cells
  let height = maximum $ fmap ((+ 1) . snd . fst) cells
  pure $ V.Grid transitions (V.WidthHeight{ V.width=width, V.height=height }) $ M.fromList cells

  where
    positionCells rows = do
      (y, line) <- zip [0..] rows
      (x, cell) <- zip [0..] line
      [((x, y), cell)]

    grid :: P.Parser [[Char]]
    grid = endBy1 row (P.ws <|> eof)

    row :: P.Parser [Char]
    row = some cellState

    cellState :: P.Parser Char
    cellState = choice ((\(Conway.CellIdent c, _) -> char c) <$> aliases)

alias :: Conway.CellAliases -> P.Parser Conway.CellIdent
alias aliases = choice $ identFromAlias <$> aliases
  where
    identFromAlias (ident, Conway.CellAlias al) =
      ident <$ P.lstr al

cellTransitions :: Conway.CellAliases -> P.Parser Conway.CellTransitions
cellTransitions aliases = do
  _ <- P.lstr "cells" *> P.lstr "transition"
  transitions <- some cellTransition
  _ <- P.lstr "otherwise" *> P.lstr "a" *> P.lstr "cell" *> P.lstr "is"
  cellDefault <- alias aliases
  pure $ Conway.CellTransitions
    { Conway.cases = transitions,
      Conway.otherwiseCellIs = cellDefault
    }

  where
    cellTransition :: P.Parser (Conway.CellIdent, Conway.CellIdent, Conway.Value)
    cellTransition = do
      _ <- P.lstr "from"
      previous <- alias aliases
      _ <- P.lstr "to"
      next <- alias aliases
      _ <- P.lstr "if"
      cond <- P.value
      pure (previous, next, cond)

dimensions :: P.Parser Conway.SolvableConwayDimensions
dimensions =
  P.lstr "2" *> P.lstr "dimensions" *> pure Conway.TwoD <|>
  P.lstr "1" *> P.lstr "dimension" *> pure Conway.OneD

initialStatePath :: P.Parser Text
initialStatePath =
  P.lstr "initial" *> P.lstr "state" *> P.lstr "at" *> P.filePath

cellAliases :: P.Parser [(Conway.CellIdent, Conway.CellAlias)]
cellAliases = do
  P.lstr "where" *> sepBy1 cellAlias (P.lstr "and")

cellAlias :: P.Parser (Conway.CellIdent, Conway.CellAlias)
cellAlias = P.lexeme $ do
  character <- Conway.CellIdent <$> P.lexeme (char '\'' *> asciiChar <* char '\'')
  _ <- P.lexeme "means"
  aliasAs <- Conway.CellAlias <$> P.simpleQuoted
  pure (character, aliasAs)
