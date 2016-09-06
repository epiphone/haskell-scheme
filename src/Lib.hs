module Lib where

import           Control.Monad
import           Numeric
import           System.Environment
import           Text.ParserCombinators.Parsec hiding (spaces)


data LispVal = Atom String
  | Character Char
  | List [LispVal]
  | DottedList [LispVal] LispVal
  | Number Integer
  | Float Double
  | String String
  | Bool Bool deriving Show


parseAtom :: Parser LispVal
parseAtom = do
  first <- letter <|> symbol
  rest <- many (letter <|> digit <|> symbol)
  let atom = first:rest
  return $ Atom atom

parseBinary :: Parser LispVal
parseBinary = do try $ string "#b"
                 x <- many1 (oneOf "01")
                 return $ Number (bin2dig x)

parseBool :: Parser LispVal
parseBool = do
  char '#'
  (char 't' >> return (Bool True)) <|> (char 'f' >> return (Bool False))

parseCharacter :: Parser LispVal
parseCharacter = do
  string "#\\"
  value <- try (string "newline" <|> string "space")
           <|> do { x <- anyChar; notFollowedBy alphaNum; return [x] }
  return $ Character $ case value of
    "space"   -> ' '
    "newline" -> '\n'
    _         -> head value

parseDecimal :: Parser LispVal
parseDecimal = fmap (Number . read) (many1 digit)
-- parseDecimal = many1 digit >>= (return . Number . read)

parseDottedList :: Parser LispVal
parseDottedList = do
  head <- endBy parseExpr spaces
  tail <- char '.' >> spaces >> parseExpr
  return $ DottedList head tail

parseExpr :: Parser LispVal
parseExpr = parseAtom
  <|> parseString
  <|> try parseFloat
  <|> try parseNumber
  <|> try parseBool
  <|> try parseCharacter
  <|> parseQuoted
  <|> parseQuasiQuoted
  <|> parseUnQuote
  <|> do char '('
         x <- try parseList <|> parseDottedList
         char ')'
         return x

parseFloat :: Parser LispVal
parseFloat = do
  x <- many1 digit
  char '.'
  y <- many1 digit
  return $ (Float . fst . head . readFloat) (x ++ "." ++ y)

parseHex :: Parser LispVal
parseHex = do try $ string "#x"
              x <- many1 (letter <|> digit)
              return $ (Number . fst . head . readHex) x

parseList :: Parser LispVal
parseList = liftM List $ sepBy parseExpr spaces

parseNumber :: Parser LispVal
parseNumber = parseDecimal <|> parseHex <|> parseBinary

parseQuasiQuoted :: Parser LispVal
parseQuasiQuoted = do
  char '`'
  x <- parseExpr
  return $ List [Atom "quasiquote", x]

parseQuoted :: Parser LispVal
parseQuoted = do
  char '\''
  x <- parseExpr
  return $ List [Atom "quote", x]

parseString :: Parser LispVal
parseString = do
  char '"'
  x <- many (noneOf "\"" <|> (char '\\' >> char '"'))
  char '"'
  return $ String x

parseUnQuote :: Parser LispVal
parseUnQuote = do
  char ','
  x <- parseExpr
  return $ List [Atom "unquote", x]

someFunc :: IO ()
someFunc = do
    input <- getLine
    putStrLn (readExpr input)

spaces :: Parser ()
spaces = skipMany1 space

symbol :: Parser Char
symbol = oneOf "!$%&|*+-/:<=>?@^_~"

readExpr :: String -> String
readExpr input = case parse parseExpr "lisp" input of
  Left err -> "No match: " ++ show err
  Right val -> "Found value: " ++ show val

bin2dig :: String -> Integer
bin2dig = bin2dig' 0
bin2dig' digint "" = digint
bin2dig' digint (x:xs) = let old = 2 * digint + (if x == '1' then 1 else 0) in
                         bin2dig' old xs

