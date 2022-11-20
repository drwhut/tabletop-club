Adding saved games
==================

If you are creating your asset pack to be able to play a certain game, then it
may be worth adding a pre-made save file to the asset pack so players can get
started straight away, without them having to spawn each object and place them
individually.

Firstly, you'll need to setup the table in-game the way you want players to see
it, then go to :guilabel:`Menu` > :guilabel:`Save game`, enter an appropiate
name, then click :guilabel:`Save`. This will create two files in your ``saves``
folder as shown:

.. code-block::

   Documents
   └── TabletopClub
       └── saves
           ├── My Game.png
           └── My Game.tc

The ``.png`` file is a thumbnail created by the game at the time of saving,
which is displayed alongside the save file. The ``.tc`` file is what contains
the save data.

.. tip::

   You can improve how the thumbnail looks by pre-positioning the camera before
   saving, as well as by hiding the UI (:guilabel:`F9` by default).

To add these files to your asset pack, it's as simple as creating a ``games``
folder, and copying the thumbnail and save file inside, like so:

.. code-block::
   
   MyAssetPack
       └── games
           ├── My Game.png
           └── My Game.tc

Once the save file has been imported, you can then load it in-game by clicking
on :guilabel:`Games`, selecting it from the menu, and clicking :guilabel:`Load`.

.. tip::

   You don't necessarily have to use the thumbnail the game generates!
   In theory, you can have any image alongside the save, and it will be
   displayed next to the save file in-game. The only requirement is that the
   name of the image *must* be the same name as the save file.

For more information, see :ref:`file-type-save`.
