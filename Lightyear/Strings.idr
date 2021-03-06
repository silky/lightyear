module Lightyear.Strings

-- This code is distributed under the BSD 2-clause license.
-- See the file LICENSE in the root directory for its full text.

import Control.Monad.Identity

import Lightyear.Core
import Lightyear.Combinators
import Lightyear.Errmsg

%access public

private
nat2int : Nat -> Int
nat2int  Z    = 0
nat2int (S x) = 1 + nat2int x

instance Layout String where
  lineLengths = map (nat2int . Prelude.Strings.length) . lines

||| Parsers, specialised to Strings
Parser : Type -> Type
Parser = ParserT Identity String

||| Run a parser against an input string
parse : Parser a -> String -> Either String a
parse f s = let Id r = execParserT f s in case r of
  Success _ x => Right x
  Failure es  => Left $ formatError s es

private
uncons : String -> Maybe (Char, String)
uncons s with (strM s)
  uncons ""             | StrNil       = Nothing
  uncons (strCons x xs) | StrCons x xs = Just (x, xs)

||| Matches a single character that satisfies some condition
satisfy : Monad m => (Char -> Bool) -> ParserT m String Char
satisfy = satisfy' (St uncons)

||| Matches a single character that satsifies some condition, accepting a transformation of successes
satisfyMaybe : Monad m => (Char -> Maybe out) -> ParserT m String out
satisfyMaybe = satisfyMaybe' (St uncons)

||| A parser that matches some particular character
char : Monad m => Char -> ParserT m String ()
char c = skip (satisfy (== c)) <?> "character '" ++ singleton c ++ "'"

||| A parser that matches a particular string
string : Monad m => String -> ParserT m String ()
string s = traverse_ char (unpack s) <?> "string " ++ show s

||| A parser that skips whitespace
space : Monad m => ParserT m String ()
space = skip (many $ satisfy isSpace) <?> "whitespace"

||| A parser that matches a specific string, then skips following whitespace
token : Monad m => String -> ParserT m String ()
token s = skip (string s) <$ space <?> "token " ++ show s

||| Matches whatever its argument matches, but wrapped in parentheses
parens : Monad m => ParserT m String a -> ParserT m String a
parens p = char '(' $> p <$ char ')'

||| Matches a single digit
digit : Monad m => ParserT m String (Fin 10)
digit = satisfyMaybe fromChar
  where fromChar : Char -> Maybe (Fin 10)
        fromChar '0' = Just fZ
        fromChar '1' = Just (fS (fZ))
        fromChar '2' = Just (fS (fS (fZ)))
        fromChar '3' = Just (fS (fS (fS (fZ))))
        fromChar '4' = Just (fS (fS (fS (fS (fZ)))))
        fromChar '5' = Just (fS (fS (fS (fS (fS (fZ))))))
        fromChar '6' = Just (fS (fS (fS (fS (fS (fS (fZ)))))))
        fromChar '7' = Just (fS (fS (fS (fS (fS (fS (fS (fZ))))))))
        fromChar '8' = Just (fS (fS (fS (fS (fS (fS (fS (fS (fZ)))))))))
        fromChar '9' = Just (fS (fS (fS (fS (fS (fS (fS (fS (fS (fZ))))))))))
        fromChar _   = Nothing

||| Matches an integer literal
integer : (Num n, Monad m) => ParserT m String n
integer = do minus <- opt (char '-')
             ds <- some digit
             let theInt = getInteger ds
             case minus of
               Nothing => pure (fromInteger theInt)
               Just () => pure (fromInteger ((-1) * theInt))
  where getInteger : List (Fin 10) -> Integer
        getInteger = foldl (\a => \b => 10 * a + cast b) 0

testParser : Parser a -> String -> IO (Maybe a)
testParser p s = case parse p s of
  Left  e => putStrLn e $> pure Nothing
  Right x => pure (Just x)
