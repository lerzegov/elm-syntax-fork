module Elm.Parser.Comments exposing (declarationDocumentation, moduleDocumentation, multilineComment, singleLineComment)

{-| @docs declarationDocumentation, moduleDocumentation, multilineComment, singleLineComment-}
import Char.Extra
import Elm.Syntax.Documentation exposing (Documentation)
import Elm.Syntax.Node exposing (Node(..))
import ParserFast exposing (Parser)


{-| singleLineComment functionality-}
singleLineComment : ParserFast.Parser (Node String)
singleLineComment =
    ParserFast.symbolFollowedBy "--"
        (ParserFast.whileMapWithRange
            (\c ->
                case c of
                    '\u{000D}' ->
                        False

                    '\n' ->
                        False

                    _ ->
                        not (Char.Extra.isUtf16Surrogate c)
            )
            (\range content ->
                Node
                    { start = { row = range.start.row, column = range.start.column - 2 }
                    , end =
                        { row = range.start.row
                        , column = range.end.column
                        }
                    }
                    ("--" ++ content)
            )
        )


{-| multilineComment functionality-}
multilineComment : ParserFast.Parser (Node String)
multilineComment =
    ParserFast.offsetSourceAndThen
        (\offset source ->
            case String.slice (offset + 2) (offset + 3) source of
                "|" ->
                    problemUnexpectedDocumentation

                _ ->
                    multiLineCommentNoCheck
        )


problemUnexpectedDocumentation : Parser a
problemUnexpectedDocumentation =
    ParserFast.problem "unexpected documentation comment"


multiLineCommentNoCheck : Parser (Node String)
multiLineCommentNoCheck =
    ParserFast.nestableMultiCommentMapWithRange Node
        ( '{', "-" )
        ( '-', "}" )


{-| moduleDocumentation functionality-}
moduleDocumentation : Parser (Node String)
moduleDocumentation =
    declarationDocumentation


{-| declarationDocumentation functionality-}
declarationDocumentation : ParserFast.Parser (Node Documentation)
declarationDocumentation =
    -- technically making the whole parser fail on multi-line comments would be "correct"
    -- but in practice, all declaration comments allow layout before which already handles
    -- these.
    multiLineCommentNoCheck
