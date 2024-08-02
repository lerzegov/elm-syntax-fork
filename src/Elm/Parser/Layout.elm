module Elm.Parser.Layout exposing
    ( layoutStrict
    , maybeAroundBothSides
    , maybeLayout
    , maybeLayoutUntilIgnored
    , moduleLevelIndentation
    , onTopIndentation
    , optimisticLayout
    , positivelyIndentedFollowedBy
    , positivelyIndentedPlusFollowedBy
    )

import Elm.Parser.Comments as Comments
import Elm.Parser.Node as Node
import Elm.Syntax.Node exposing (Node)
import Parser exposing ((|.), (|=), Parser)
import ParserWithComments exposing (Comments, WithComments)
import Rope
import Set


maybeLayoutUntilIgnored : Parser () -> Parser.Parser Comments
maybeLayoutUntilIgnored end =
    let
        fromSingleLineCommentUntilEnd : Parser (Rope.Rope (Node String))
        fromSingleLineCommentUntilEnd =
            Parser.map
                (\comment ->
                    \commentsAfter ->
                        Rope.one comment |> Rope.filledPrependTo commentsAfter
                )
                Comments.singleLineCommentCore
                |= Parser.lazy (\() -> maybeLayoutUntilIgnored end)

        endNoComments : Parser Comments
        endNoComments =
            positivelyIndented Rope.empty |. end |> Parser.backtrackable

        endOrFromCommentElseEmptyThenEnd : Parser Comments
        endOrFromCommentElseEmptyThenEnd =
            Parser.oneOf
                [ endNoComments
                , fromSingleLineCommentUntilEnd
                , fromMultilineCommentNode
                ]
    in
    Parser.oneOf
        [ whitespace
            |> Parser.andThen (\_ -> endOrFromCommentElseEmptyThenEnd)
        , endNoComments
        , fromSingleLineCommentUntilEnd
        , fromMultilineCommentNode
        ]


whitespaceAndCommentsOrEmpty : Parser.Parser Comments
whitespaceAndCommentsOrEmpty =
    Parser.oneOf
        [ whitespace
            |> ParserFast.andThen (\_ -> endOrFromCommentElseEmptyThenEnd)
        , end
        , fromSingleLineCommentUntilEnd
        , fromMultilineCommentNodeUntilEnd
        ]


whitespaceAndCommentsOrEmpty : Parser Comments
whitespaceAndCommentsOrEmpty =
    ParserFast.oneOf2
        (whitespace
            -- whitespace can't be followed by more whitespace
            |> ParserFast.andThen (\_ -> fromCommentElseEmpty)
        )
        fromCommentElseEmpty


whitespace : Parser String
whitespace =
    ParserFast.variable
        { inner = \c -> c == ' ' || c == '\n' || c == '\u{000D}'
        , reserved = Set.empty
        , start = \c -> c == ' ' || c == '\n' || c == '\u{000D}'
        }


fromCommentElseEmpty : Parser Comments
fromCommentElseEmpty =
    -- since comments are comparatively rare
    -- but expensive to check for, we allow shortcutting to dead end
    ParserFast.offsetSourceAndThen
        (\offset source ->
            case source |> String.slice offset (offset + 2) of
                "--" ->
                    -- this will always succeed from here, so no need to fall back to Rope.empty
                    fromSingleLineCommentNode

                "{-" ->
                    fromMultilineCommentNodeOrEmptyOnProblem

                _ ->
                    succeedRopeEmpty
        )


succeedRopeEmpty : Parser Comments
succeedRopeEmpty =
    ParserFast.succeed Rope.empty


fromMultilineCommentNodeOrEmptyOnProblem : Parser Comments
fromMultilineCommentNodeOrEmptyOnProblem =
    ParserFast.orSucceed fromMultilineCommentNode Rope.empty


fromMultilineCommentNode : Parser Comments
fromMultilineCommentNode =
    ParserFast.map2
        (\comment commentsAfter ->
            Rope.one comment |> Rope.filledPrependTo commentsAfter
        )
        (Node.parserCore Comments.multilineCommentString)
        whitespaceAndCommentsOrEmpty


fromSingleLineCommentNode : Parser Comments
fromSingleLineCommentNode =
    ParserFast.map2
        (\content commentsAfter ->
            Rope.one content |> Rope.filledPrependTo commentsAfter
        )
        (Node.parserCore Comments.singleLineCommentCore)
        whitespaceAndCommentsOrEmpty


maybeLayout : Parser Comments
maybeLayout =
    whitespaceAndCommentsOrEmpty
        |. positivelyIndented ()


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


positivelyIndented : res -> Parser.Parser res
positivelyIndented res =
    let
        succeedRes : Parser res
        succeedRes =
            Parser.succeed res
    in
    Parser.getCol
        |> Parser.andThen
            (\column ->
                Parser.andThen
                    (\indent ->
                        if column > indent then
                            succeedRes

            else
                problemPositivelyIndented
        )


problemPositivelyIndented : Parser a
problemPositivelyIndented =
    Parser.problem "must be positively indented"


optimisticLayout : Parser Comments
optimisticLayout =
    whitespaceAndCommentsOrEmpty


layoutStrictFollowedByComments : Parser Comments -> Parser Comments
layoutStrictFollowedByComments nextParser =
    ParserFast.map2
        (\commentsBefore afterComments ->
            commentsBefore |> Rope.prependTo afterComments
        )
        optimisticLayout
        (onTopIndentationFollowedBy nextParser)


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


layoutStrictFollowedBy : Parser syntax -> Parser (WithComments syntax)
layoutStrictFollowedBy nextParser =
    ParserFast.map2
        (\commentsBefore after ->
            { comments = commentsBefore, syntax = after }
        )
        optimisticLayout
        (onTopIndentationFollowedBy nextParser)


layoutStrict : Parser Comments
layoutStrict =
    ParserFast.map2 (\commentsBefore () -> commentsBefore)
        optimisticLayout
        (onTopIndentationFollowedBy (ParserFast.succeed ()))


moduleLevelIndentationFollowedBy : Parser a -> Parser a
moduleLevelIndentationFollowedBy nextParser =
    ParserFast.columnAndThen
        (\column ->
            if column == 1 then
                nextParser

            else
                problemModuleLevelIndentation
        )


problemModuleLevelIndentation : Parser a
problemModuleLevelIndentation =
    ParserFast.problem "must be on module-level indentation"


onTopIndentationFollowedBy : Parser a -> Parser a
onTopIndentationFollowedBy nextParser =
    ParserFast.columnIndentAndThen
        (\column indent ->
            if column - indent == 0 then
                nextParser

            else
                problemTopIndentation
        )


problemTopIndentation : Parser a
problemTopIndentation =
    ParserFast.problem "must be on top indentation"


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
