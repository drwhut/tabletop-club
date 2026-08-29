.. _tutorial-creating-asset-pack:

Creating your own asset pack
============================

Before you can add anything to the game, first you'll need to create your own
asset pack for the game to scan when it starts. Luckily, it's super easy!

If you haven't already, launch the game. The game will automatically create a
folder for us to place our asset pack in your Documents, like so:

.. code-block::

   Documents
   └── TabletopClub
       └── assets

Once you've found the ``assets`` folder, to make your own asset pack, you simply
create a folder inside of it, giving it any name you want. In this example, the
name of the asset pack would be ``MyAssetPack``:

.. code-block::

   Documents
   └── TabletopClub
       └── assets
           └── MyAssetPack

And that's it! Note that everything you add will be put under this new folder,
and all the following guides will assume you've created it.

Once you have added what you want to your asset pack, you can either restart the
game, or go to :guilabel:`Options` > :guilabel:`General`, and click
:guilabel:`Reimport Assets` to have the game import everything you've added so
you can use it in-game!

If your asset pack doesn't appear, try restarting the entire game.
If that doesn't help either, an error might have occured when trying to import it.
You can see what went wrong by checking the import log on the main-menu screen,
click the leftmost button on the bottom of the screen, labeled with an exclamation
point ``(!)`` to open it. If all else fails, searching for "ERROR" or your
AssetPack's name in the latest logfile (see :ref:`ways_to_contribute`) can show
more details of what went wrong.
