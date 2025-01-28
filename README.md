# elm-syntax

Elm Syntax in Elm: for parsing and writing Elm in Elm.

## Publishing a new release of elm-syntax-fork
For a new version of your elm package you need to:

Make and test your changes locally
Commit and push to GitHub

Create a new version tag following semantic versioning (e.g., 1.0.1 or 1.1.0):
git tag 1.0.1
git push origin 1.0.1

Update version in elm.json to match new tag
Create the release on GitHub using the new tag
Do git checkout 1.0.1 locally
Run elm publish

The version number should follow semantic versioning:

Patch (1.0.0 -> 1.0.1): for bug fixes
Minor (1.0.0 -> 1.1.0): for new features that don't break existing code
Major (1.0.0 -> 2.0.0): for breaking changes
## How does this work?

When Elm code is parsed, it's converted into an Abstract Syntax Tree (AST).
The AST lets us represent the code in a way that's much easier to work with when programming.

Here's an example of that:
Code: `3 + 4 * 2`
AST:
```elm
OperatorApplication
    (Integer 3)
    "+"
    (OperatorApplication
        (Integer 4)
        "*"
        (Integer 2)
    )
```

Notice how it forms a tree structure where we first multiply together 4 and 2, and then add the result with 3.
That's where the "tree" part of AST comes from.

## Getting Started

```elm
import Elm.Parser
import Html exposing (Html)

src : String
src =
    """module Foo exposing (foo)

foo = 1
"""

parse : String -> String
parse input =
    case Elm.Parser.parseToFile input of
        Err e ->
            "Failed: " ++ Debug.toString e

        Ok v ->
            "Success: " ++ Debug.toString v

main : Html msg
main =
    Html.text (parse src)
```

Used in:

* [`elm-review`](https://elm-review.com/)
* [`elm-codegen`](https://package.elm-lang.org/packages/mdgriffith/elm-codegen/latest/)
* [`elm-analyse`](https://github.com/stil4m/elm-analyse)
* [`elm-xref`](https://github.com/zwilias/elm-xref)
* [`elm-lens`](https://github.com/mbuscemi/elm-lens)
