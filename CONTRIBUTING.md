# Contributing to OpenTabletop

## Reporting a bug

If you've found a problem with the game, or the game crashes when you try to do
something, then if there isn't already an issue posted for it, please post an
issue on the project's GitHub page with the bug report template - make sure you
fill in the template with as much information as you can, including how to
reproduce the bug or crash, so we can identify what is going wrong! If possible,
it would also help us a lot if you include any error messages that come up.

## Suggesting a feature

Got an idea of how to make OpenTabletop better? If it hasn't already been
suggested, don't hesitate to open up an issue on the GitHub page with the
feature request template - we want to make the game as good and as accessible
as possible, and you might have an idea that we haven't thought of yet!

## Creating a pull request

If you want to help the project directly, whether it is fixing a bug or
implementing a feature, then feel free to create a fork of the project on GitHub
and make the changes you want! However, we recommend following these guidelines
for consistency and to make everyone's lives easier:

* If you are writing code in the editor, then make sure your editor is set to
use tabs instead of spaces (this is the default setting).

* If you are creating a script in the editor, make sure you use the "Copyright
Notice" template.

* If you are adding functions that aren't built-in functions (e.g. `_ready()`),
or functions that are called by signals (e.g. `_on_*`) then please add a
comment above the function that describes what it does, what it returns and
what the arguments are!

* If you are adding scenes, then make sure to write editor descriptions for the
nodes!

* When creating a fork or a pull request, make sure it is from and to the
`master` branch! Everything is merged onto the `master` branch, which is always
working towards the next minor release. If there is a bug fix that applies to a
previously released version, then it will be cherry-picked from the `master`
branch to that release's branch.

* When you are merging from the project's `master` branch to your fork's branch
(e.g. when there is a merge conflict), then please use `merge` instead of
`rebase`! In the grand scheme of things, this is a relatively small project, and
we want the git history to be intact!

## Submitting assets

Have you made, or found, assets that OpenTabletop would benefit from, like:

* Textures
* 3D Models
* Sound Effects
* Music

If so, then post an issue on the GitHub page with the asset submission template,
and fill in all of the details such as the author's name and the asset license.
Note that we will only accept assets with standard, open licenses, like the
[CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) license, for
example.

## Code of conduct

By participating in the project, you agree to abide by the project's
[code of conduct](CODE_OF_CONDUCT.md).
