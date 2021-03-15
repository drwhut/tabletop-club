====================
Asset pack structure
====================

Locations for asset packs
-------------------------

At the start of the game, OpenTabletop will scan a set of given folders for
asset packs. If you want the game to import your asset pack, it needs to be
put into one of the following locations:

* ``<OPENTABLETOP_INSTALL_FOLDER>/assets/``
* ``<DOWNLOADS>/OpenTabletop/assets/``
* ``<DOCUMENTS>/OpenTabletop/assets/``
* ``<DESKTOP>/OpenTabletop/assets/``


Creating an asset pack
----------------------

Creating an asset pack is really easy! All you need to do is create a folder
in one of the folders mentioned above, and you're done! The name of the folder
will be the name of the asset pack.


Sub-folders
-----------

Every asset pack divides its assets into different sub-folders, depending on
what type of asset it is, and what the file type needed for that asset type is.
Note that asset packs don't need to have all of these sub-folders.

+--------------------------+------------------------+--------------------------+------------------------------+
| Sub-folder               | File Type              | Asset Type               | Object Type                  |
+==========================+========================+==========================+==============================+
| ``cards/``               | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-card`      |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``containers/cube/``     | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-container` |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``containers/custom/``   | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-container` |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``containers/cylinder/`` | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-container` |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``dice/d4/``             | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-dice`      |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``dice/d6/``             | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-dice`      |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``dice/d8/``             | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-dice`      |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``games/``               | :ref:`file-type-save`  | :ref:`asset-type-game`   | N/A                          |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``music/``               | :ref:`file-type-audio` | :ref:`asset-type-music`  | N/A                          |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``pieces/cube/``         | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-piece`     |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``pieces/custom/``       | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-piece`     |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``pieces/cylinder/``     | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-piece`     |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``skyboxes/``            | :ref:`file-type-image` | :ref:`asset-type-skybox` | N/A                          |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``sounds/``              | :ref:`file-type-audio` | :ref:`asset-type-sound`  | N/A                          |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``speakers/cube/``       | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-speaker`   |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``speakers/custom/``     | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-speaker`   |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``speakers/cylinder/``   | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-speaker`   |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``tables/``              | :ref:`file-type-3d`    | :ref:`asset-type-table`  | N/A                          |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``timers/cube/``         | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-timer`     |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``timers/custom/``       | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-timer`     |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``timers/cylinder/``     | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-timer`     |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``tokens/cube/``         | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-token`     |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``tokens/cylinder/``     | :ref:`file-type-image` | :ref:`asset-type-object` | :ref:`object-type-token`     |
+--------------------------+------------------------+--------------------------+------------------------------+


Configuration files
-------------------

.. _config-cfg:

config.cfg
^^^^^^^^^^

Every sub-folder can have this file, which allows you to modify the properties
of assets in the subfolder.

Here is an example of a ``config.cfg`` file:

.. code-block:: ini

   ; The following properties are applied to every object in the subfolder.
   [*]

   ; Setting the description of an object.
   desc = "This is an object you can spawn!"

   ; Setting the mass of an object in grams (g).
   mass = 5.0

   ; Setting the size of an object in centimeters (cm).
   scale = Vector3(3.5, 0.5, 5.0)

   ; The following properties apply only to objects whose name start with
   ; "Heavy". These properties take precedence over the properties under [*].
   [Heavy*]

   ; Descriptions can be on multiple lines.
   desc = "This is one line,

   and this is another!"

   ; This is equivalent to 100g.
   mass = 100.0

   ; The following properties apply only to the given object.
   [Temporary.png]

   ; You can tell the game to not import certain objects.
   ignore = true

Here is the full list of properties you can modify in ``config.cfg``:

+-------------------+-----------+------------------+----------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Property Name     | Data Type | Used By          | Default Value              | Description                                                                                                                                                                                                                                                      |
+===================+===========+==================+============================+==================================================================================================================================================================================================================================================================+
| ``back_face``     | Text      | Cards            | ``""``                     | The file name of the back face of the card. The texture must be in the same folder. If blank, no back face texture is applied.                                                                                                                                   |
+-------------------+-----------+------------------+----------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``bounce``        | Number    | Tables           | ``0.5``                    | Defines how high objects bounce off the table. Must be a value between ``0.0`` (no bounce) and ``1.0`` (full bounce).                                                                                                                                            |
+-------------------+-----------+------------------+----------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``default``       | Boolean   | Skyboxes, Tables | ``false``                  | If ``true``, the asset is loaded before the game starts.                                                                                                                                                                                                         |
+-------------------+-----------+------------------+----------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``desc``          | Text      | All              | ``""``                     | Describes the asset in more detail.                                                                                                                                                                                                                              |
+-------------------+-----------+------------------+----------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``hands``         | Array     | Tables           | ``[]``                     | The positions of player's hands around the table. See :ref:`asset-type-table` for more information.                                                                                                                                                              |
+-------------------+-----------+------------------+----------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``ignore``        | Boolean   | All              | ``false``                  | If ``true``, it tells the game to ignore this asset when importing the asset pack.                                                                                                                                                                               |
+-------------------+-----------+------------------+----------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``main_menu``     | Boolean   | Music            | ``false``                  | If ``true``, the music will have a chance of playing in the main menu.                                                                                                                                                                                           |
+-------------------+-----------+------------------+----------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``mass``          | Number    | Objects          | ``1.0``                    | The mass of the object in grams (g) when it is spawned in-game. It is recommended to set this value for more realistic physics collisions.                                                                                                                       |
+-------------------+-----------+------------------+----------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``opening_angle`` | Number    | Containers       | ``30.0``                   | The maximum angle in degrees at which objects can enter the top of the container. A lower value means the object needs to be directly on top of the container, and a higher value means the object can be further away and still be able to enter the container. |
+-------------------+-----------+------------------+----------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``scale``         | Vector3   | Objects          | ``Vector3(1.0, 1.0, 1.0)`` | Scales the object in the X, Y and Z axes in centimeters (cm). Note that for objects that use custom 3D models, this value most likely won't reflect the final size of the object.                                                                                |
+-------------------+-----------+------------------+----------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``shakable``      | Boolean   | Containers       | ``false``                  | If ``true``, when the container is being shaken upside down, it will randomly drop items out.                                                                                                                                                                    |
+-------------------+-----------+------------------+----------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``strength``      | Number    | Skyboxes         | ``1.0``                    | The strength of the ambient light coming from the skybox.                                                                                                                                                                                                        |
+-------------------+-----------+------------------+----------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+


stacks.cfg
^^^^^^^^^^

For :ref:`object-type-card` and :ref:`object-type-token` objects, you can add
this file to add pre-filled stacks of those objects to the asset pack. A good
example of this is for adding pre-filled decks of cards to the game.

Here is an example of a ``stacks.cfg`` file:

.. code-block:: ini

   ; This is the name of the stack.
   [My Stack]

   ; You can also give stacks descriptions.
   desc = "This is my stack. It's awesome!"

   ; You then specify which objects are in the stack.
   ; Note that all of the objects need to be the same size.
   items = [
       "Card 1.png",
       "Card 2.png",
       "Card 3.png"
   ]

   ; This is the name of another stack.
   [My Friends Stack]

   desc = "My friend's stack isn't as good as my stack!"

   ; It doesn't matter if each object is on a new line.
   items = ["Trading Card 1.jpg", "Trading Card 2.jpg"]
