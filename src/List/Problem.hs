module List.Problem
       ( runListProblem
       ) where

import           Builtins (listContext)
import           Data.Text
import qualified Evaluator as Eval
import qualified List.Ast as Ast
import qualified List.Parser as Parse
import qualified Parser as Parse
import qualified System.FilePath as Path
import           Text.Megaparsec
import           Text.Megaparsec.Error (parseErrorPretty)
import qualified Type
import qualified TypeCheck
import qualified Value as V

getInputParser :: Type.Type -> Maybe (Parse.Parser V.Value)
getInputParser Type.Number = Just Parse.integer
getInputParser _ = Nothing

runListProblem :: (String, String) -> IO (Maybe (Type.Type, Type.Type, V.Value, Ast.Problem))
runListProblem (source, text) =
  case runParser Parse.list source $ pack text of
    Left err -> do
      putStrLn "Error parsing aoc code file:"
      putStrLn $ parseErrorPretty err
      pure Nothing
    Right ast ->
      let
        inputPath = Path.takeDirectory source Path.</> unpack (Ast.at ast)
        validations = do
          _ <- TypeCheck.ensureOneFreeOrIdentInEachStep listContext $ Ast.solution ast
          it <- TypeCheck.inferInputType listContext $ Ast.solution ast
          ot <- TypeCheck.unifySolution listContext (Ast.solution ast) (Type.List it)
          pure (it, ot)
      in
        case validations of
          Left err -> do
            print err
            pure Nothing
          Right (inputElementType, outputType) ->
            case getInputParser inputElementType of
              Nothing -> do
                putStrLn $ "Inferred input to have element type " ++ show inputElementType ++ " (only list of integers are supported)"
                pure Nothing
              Just parseInput -> do
                inputText <- readFile inputPath
                case runParser (Parse.listInput (Ast.separator ast) parseInput) inputPath $ strip $ pack inputText of
                  Left err -> do
                    putStrLn "Error parsing input file:"
                    putStrLn $ parseErrorPretty err
                    pure Nothing
                  Right input ->
                    case Eval.eval listContext (V.Vs input) (Ast.solution ast) of
                      Right result -> do
                        print result
                        pure $ Just (Type.List inputElementType, outputType, result, ast)
                      Left err -> do
                        print err
                        pure Nothing
