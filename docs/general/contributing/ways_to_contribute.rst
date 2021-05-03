==================
Ways to contribute
==================

Reporting a bug
---------------

Before reporting a bug on GitHub, make sure of the following:

* The bug is reproducible. If you can't get the bug to happen again, then
  chances are that we won't be able to either, then we can't fix it!

* The bug hasn't already been reported - you can check by going to the `issues
  page`_ on GitHub and searching for it there.

To report a bug, please `post an issue`_ on GitHub with the bug report template.

.. note::

   If you come across multiple bugs, please post one issue for each bug! This
   way, we can easily reference individual bugs.

Make sure to include as much information as you can in the post, including how
to reproduce the bug, the platform you're running the game on, and if possible,
provide the latest log so we can check if there were any errors thrown. You can
find the game logs in the following folders:

* Windows: ``%APPDATA%/TabletopClub/logs/``
* macOS / Linux: ``~/.local/share/godot/app_userdata/TabletopClub/logs/``

.. hint::

   If you want to provide an in-game screenshot showing the bug, you can press
   :guilabel:`F3` to display debug information on the screen, then you can
   press :guilabel:`F12` to take a screenshot! Screenshots are saved to the
   ``user://`` directory, next to the logs.


Suggesting a feature
--------------------

Have you got an idea to make the game better? If someone else hasn't had the
same idea (you can check by searching the `issues page`_ on GitHub), then you
can `post an issue`_ on GitHub explaining your idea, what problem it solves,
and any alternative ideas you've thought of. We want to make the game as good
as it can possibly be, so don't hesistate to let us know your idea!


Changing the documentation
--------------------------

If there is a part of the documentation that you don't understand, or that you
think is missing, then please don't hesistate to suggest a change to the
documentation:

* You can `post an issue`_ with the documentation change template
  describing the edit you want.

* You can click on the GitHub icon at the top of the page, click the
  :guilabel:`suggest edit` button, and create a pull request with the changes
  you give!


Translating the project
-----------------------

If you know a language other than English, you can help to translate the game
and it's documentation by going to the project's `Hosted Weblate
<https://hosted.weblate.org/engage/tabletop-club/>`_ page and suggest
translations for the project's strings in your language!

If you don't see your language in a component, you can add it by scrolling to
the bottom of the component page and pressing :guilabel:`Start new translation`.

.. note::

   Manual pull requests for translations will be closed, as Weblate keeps it's
   own fork of the project, and we want to avoid having merge requests occur.

.. image:: https://hosted.weblate.org/widgets/tabletop-club/-/287x66-white.png
   :alt: Translation status
   :target: https://hosted.weblate.org/engage/tabletop-club/


Creating a pull request
-----------------------

If you see an issue on the `GitHub repository`_ that you think you can fix, and
you want to directly contribute to the project by modifying the game code, you
can create a pull request on GitHub to merge your changes in! See the
:ref:`pull-request-workflow` page for more information.


Proposing assets
----------------

If you see an issue on the `GitHub repository`_ that needs game assets to fix
(like textures, 3D models, sound effects, music, etc.), then you can reply to
that issue with either an asset you've found online, or one that you've made
yourself!

If the asset doesn't solve an issue, but you still think Tabletop Club would
benefit from having it, then you can `post an issue`_ with the asset submission
template instead!

However you propose the asset, you need to provide the following information:

* The name of the asset.
* The name of the author.
* The license the asset is under - keep in mind that we will only include
  assets with open licenses, e.g. `CC BY-SA 3.0
  <https://creativecommons.org/licenses/by-sa/3.0/>`_.
* The URL where the asset can be downloaded from. The URL must be publically
  accessible, and it must lead to a trusted website.


.. _GitHub repository: https://github.com/drwhut/tabletop-club
.. _issues page: https://github.com/drwhut/tabletop-club/issues
.. _post an issue: https://github.com/drwhut/tabletop-club/issues/new/choose
