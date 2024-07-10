module Combine.Char exposing (anyChar, char)

import Combine exposing (Parser)
import Parser as Core


char : Char -> Parser s Char
char c =
    satisfy
        (\c_ -> c_ == c)
        ("expected '" ++ String.fromChar c ++ "'")


anyChar : Parser s Char
anyChar =
    satisfy
        (always True)
        "expected any character"


satisfy : (Char -> Bool) -> String -> Parser state Char
satisfy pred problem =
    Combine.fromCore
        (Core.getChompedString (Core.chompIf pred)
            |> Core.andThen
                (\s ->
                    case String.toList s of
                        [] ->
                            Core.problem problem

                        c :: _ ->
                            Core.succeed c
                )
        )
