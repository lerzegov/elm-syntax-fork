module Elm.Parser.Layout exposing
    ( layoutStrict
    , layoutStrictFollowedBy
    , layoutStrictFollowedByComments
    , layoutStrictFollowedByWithComments
    , maybeAroundBothSides
    , maybeLayout
    , moduleLevelIndentationFollowedBy
    , onTopIndentationFollowedBy
    , optimisticLayout
    , positivelyIndentedFollowedBy
    , positivelyIndentedPlusFollowedBy
    )

{-| @docs layoutStrict, layoutStrictFollowedBy, layoutStrictFollowedByComments, layoutStrictFollowedByWithComments, maybeAroundBothSides, maybeLayout, moduleLevelIndentationFollowedBy, onTopIndentationFollowedBy, optimisticLayout, positivelyIndentedFollowedBy, positivelyIndentedPlusFollowedBy -}
import Elm.Parser.Comments as Comments
import ParserFast exposing (Parser)
import ParserWithComments exposing (Comments, WithComments)
import Rope

{-| functionality -}
whitespaceAndCommentsOrEmpty : Parser Comments
whitespaceAndCommentsOrEmpty =
    ParserFast.skipWhileWhitespaceFollowedBy
        -- whitespace can't be followed by more whitespace
        --
        -- since comments are comparatively rare
        -- but expensive to check for, we allow shortcutting
        (ParserFast.offsetSourceAndThenOrSucceed
            (\offset source ->
                case source |> String.slice offset (offset + 2) of
                    "--" ->
                        -- this will always succeed from here, so no need to fall back to Rope.empty
                        Just fromSingleLineCommentNode

                    "{-" ->
                        Just fromMultilineCommentNodeOrEmptyOnProblem

                    _ ->
                        Nothing
            )
            Rope.empty
        )

{-| functionality -}
fromMultilineCommentNodeOrEmptyOnProblem : Parser Comments
fromMultilineCommentNodeOrEmptyOnProblem =
    ParserFast.map2OrSucceed
        (\comment commentsAfter ->
            Rope.one comment |> Rope.filledPrependTo commentsAfter
        )
        (Comments.multilineComment
            |> ParserFast.followedBySkipWhileWhitespace
        )
        whitespaceAndCommentsOrEmptyLoop
        Rope.empty

{-| functionality -}
fromSingleLineCommentNode : Parser Comments
fromSingleLineCommentNode =
    ParserFast.map2
        (\content commentsAfter ->
            Rope.one content |> Rope.filledPrependTo commentsAfter
        )
        (Comments.singleLineComment
            |> ParserFast.followedBySkipWhileWhitespace
        )
        whitespaceAndCommentsOrEmptyLoop

{-| functionality -}
whitespaceAndCommentsOrEmptyLoop : Parser Comments
whitespaceAndCommentsOrEmptyLoop =
    ParserFast.loopWhileSucceeds
        (ParserFast.oneOf2
            Comments.singleLineComment
            Comments.multilineComment
            |> ParserFast.followedBySkipWhileWhitespace
        )
        Rope.empty
        (\right soFar -> soFar |> Rope.prependToFilled (Rope.one right))
        identity

{-| functionality -}
maybeLayout : Parser Comments
maybeLayout =
    whitespaceAndCommentsOrEmpty |> endsPositivelyIndented

{-| functionality -}
endsPositivelyIndented : Parser a -> Parser a
endsPositivelyIndented parser =
    ParserFast.validateEndColumnIndentation
        (\column indent -> column > indent)
        "must be positively indented"
        parser


{-| Check that the indentation of an already parsed token
would be valid after [`maybeLayout`](#maybeLayout)
-}
positivelyIndentedPlusFollowedBy : Int -> Parser a -> Parser a
positivelyIndentedPlusFollowedBy extraIndent nextParser =
    ParserFast.columnIndentAndThen
        (\column indent ->
            if column > indent + extraIndent then
                nextParser

            else
                problemPositivelyIndented
        )

{-| functionality -}
positivelyIndentedFollowedBy : Parser a -> Parser a
positivelyIndentedFollowedBy nextParser =
    ParserFast.columnIndentAndThen
        (\column indent ->
            if column > indent then
                nextParser

            else
                problemPositivelyIndented
        )

{-| functionality -}
problemPositivelyIndented : Parser a
problemPositivelyIndented =
    ParserFast.problem "must be positively indented"

{-| functionality -}
optimisticLayout : Parser Comments
optimisticLayout =
    whitespaceAndCommentsOrEmpty

{-| functionality -}
layoutStrictFollowedByComments : Parser Comments -> Parser Comments
layoutStrictFollowedByComments nextParser =
    ParserFast.map2
        (\commentsBefore afterComments ->
            commentsBefore |> Rope.prependTo afterComments
        )
        optimisticLayout
        (onTopIndentationFollowedBy nextParser)

{-| functionality -}
layoutStrictFollowedByWithComments : Parser (WithComments syntax) -> Parser (WithComments syntax)
layoutStrictFollowedByWithComments nextParser =
    ParserFast.map2
        (\commentsBefore after ->
            { comments = commentsBefore |> Rope.prependTo after.comments
            , syntax = after.syntax
            }
        )
        optimisticLayout
        (onTopIndentationFollowedBy nextParser)

{-| functionality -}
layoutStrictFollowedBy : Parser syntax -> Parser (WithComments syntax)
layoutStrictFollowedBy nextParser =
    ParserFast.map2
        (\commentsBefore after ->
            { comments = commentsBefore, syntax = after }
        )
        optimisticLayout
        (onTopIndentationFollowedBy nextParser)

{-| functionality -}
layoutStrict : Parser Comments
layoutStrict =
    optimisticLayout |> endsTopIndented

{-| functionality -}
moduleLevelIndentationFollowedBy : Parser a -> Parser a
moduleLevelIndentationFollowedBy nextParser =
    ParserFast.columnAndThen
        (\column ->
            if column == 1 then
                nextParser

            else
                problemModuleLevelIndentation
        )

{-| functionality -}
problemModuleLevelIndentation : Parser a
problemModuleLevelIndentation =
    ParserFast.problem "must be on module-level indentation"

{-| functionality -}
endsTopIndented : Parser a -> Parser a
endsTopIndented parser =
    ParserFast.validateEndColumnIndentation
        (\column indent -> column - indent == 0)
        "must be on top indentation"
        parser

{-| functionality -}
onTopIndentationFollowedBy : Parser a -> Parser a
onTopIndentationFollowedBy nextParser =
    ParserFast.columnIndentAndThen
        (\column indent ->
            if column - indent == 0 then
                nextParser

            else
                problemTopIndentation
        )

{-| functionality -}
problemTopIndentation : Parser a
problemTopIndentation =
    ParserFast.problem "must be on top indentation"

{-| functionality -}
maybeAroundBothSides : Parser (WithComments b) -> Parser (WithComments b)
maybeAroundBothSides x =
    ParserFast.map3
        (\before v after ->
            { comments =
                before
                    |> Rope.prependTo v.comments
                    |> Rope.prependTo after
            , syntax = v.syntax
            }
        )
        maybeLayout
        x
        maybeLayout
