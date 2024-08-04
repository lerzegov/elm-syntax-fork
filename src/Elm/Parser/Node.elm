module Elm.Parser.Node exposing (parser, parserCore, parserMapWithComments)

import CustomParser exposing (Parser)
import Elm.Syntax.Node exposing (Node(..))
import Elm.Syntax.Range exposing (Location, Range)
import ParserWithComments exposing (WithComments)


parserMapWithComments : (WithComments (Node a) -> b) -> Parser (WithComments a) -> Parser b
parserMapWithComments valueNodeChange p =
    CustomParser.map
        (\( startRow, startColumn ) v ( endRow, endColumn ) ->
            { comments = v.comments
            , syntax =
                Node
                    { start = start
                    , end = end
                    }
                    v.syntax
            }
                |> valueNodeChange
        )
        CustomParser.getPosition
        |> CustomParser.keep p
        |> CustomParser.keep CustomParser.getPosition


parserMap : (Node a -> b) -> Parser (WithComments a) -> Parser (WithComments b)
parserMap valueNodeChange p =
    CustomParser.map
        (\( startRow, startColumn ) v ( endRow, endColumn ) ->
            { comments = v.comments
            , syntax =
                Node
                    { start = { row = startRow, column = startColumn }
                    , end = { row = endRow, column = endColumn }
                    }
                    v.syntax
                    |> valueNodeChange
            }
        )
        CustomParser.getPosition
        |> CustomParser.keep p
        |> CustomParser.keep CustomParser.getPosition


parser : Parser (WithComments a) -> Parser (WithComments (Node a))
parser p =
    CustomParser.map
        (\( startRow, startColumn ) v ( endRow, endColumn ) ->
            { comments = v.comments
            , syntax =
                Node { start = start, end = end } v.syntax
            }
        )
        CustomParser.getPosition
        |> CustomParser.keep p
        |> CustomParser.keep CustomParser.getPosition


{-| Internally saves 1 CustomParser.map compared to parserCore |> CustomParser.map
-}
parserCoreMap : (Node a -> b) -> CustomParser.Parser a -> CustomParser.Parser b
parserCoreMap valueNodeChange p =
    CustomParser.map
        (\( startRow, startColumn ) ->
            \v ->
                \( endRow, endColumn ) ->
                    Node
                        { start = { row = startRow, column = startColumn }
                        , end = { row = endRow, column = endColumn }
                        }
                        v
                        |> valueNodeChange
        )
        CustomParser.getPosition
        |> CustomParser.keep p
        |> CustomParser.keep CustomParser.getPosition


parserCore : CustomParser.Parser a -> CustomParser.Parser (Node a)
parserCore p =
    CustomParser.map
        (\( startRow, startColumn ) ->
            \v ->
                \( endRow, endColumn ) ->
                    Node
                        { start = { row = startRow, column = startColumn }
                        , end = { row = endRow, column = endColumn }
                        }
                        v
        )
        CustomParser.getPosition
        |> CustomParser.keep p
        |> CustomParser.keep CustomParser.getPosition
