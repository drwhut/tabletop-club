====================
Asset pack structure
====================

Locations for asset packs
-------------------------

At the start of the game, Tabletop Club will scan a set of given folders for
asset packs. If you want the game to import your asset pack, it needs to be
put into one of the following locations:

* ``<TABLETOPCLUB_INSTALL_FOLDER>/assets/``
* ``<DOWNLOADS>/TabletopClub/assets/``
* ``<DOCUMENTS>/TabletopClub/assets/``
* ``<DESKTOP>/TabletopClub/assets/``


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
| ``containers/``          | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-container` |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``dice/d4/``             | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-dice`      |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``dice/d6/``             | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-dice`      |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``dice/d8/``             | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-dice`      |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``dice/d10/``            | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-dice`      |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``dice/d12/``            | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-dice`      |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``dice/d20/``            | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-dice`      |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``games/``               | :ref:`file-type-save`  | :ref:`asset-type-game`   | N/A                          |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``music/``               | :ref:`file-type-audio` | :ref:`asset-type-music`  | N/A                          |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``pieces/``              | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-piece`     |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``skyboxes/``            | :ref:`file-type-image` | :ref:`asset-type-skybox` | N/A                          |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``sounds/``              | :ref:`file-type-audio` | :ref:`asset-type-sound`  | N/A                          |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``speakers/``            | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-speaker`   |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``tables/``              | :ref:`file-type-3d`    | :ref:`asset-type-table`  | N/A                          |
+--------------------------+------------------------+--------------------------+------------------------------+
| ``timers/``              | :ref:`file-type-3d`    | :ref:`asset-type-object` | :ref:`object-type-timer`     |
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

   ; You can create new objects that inherit the properties of another object,
   ; which you can then overwrite.
   [Light Object]
   parent = "Heavy Object"

   mass = 1.0 ; = 1.0g

Here is the full list of properties you can modify in ``config.cfg``:

+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Property Name      | Data Type  | Used By          | Default Value              | Description                                                                                                                                                                       |
+====================+============+==================+============================+===================================================================================================================================================================================+
| ``author``         | Text       | All              | ``""``                     | The name of the author(s) of the asset.                                                                                                                                           |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``back_face``      | Text       | Cards            | ``""``                     | The file name of the back face of the card. The texture must be in the same folder. If blank, no back face texture is applied.                                                    |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``bounce``         | Number     | Tables           | ``0.5``                    | Defines how high objects bounce off the table. Must be a value between ``0.0`` (no bounce) and ``1.0`` (full bounce).                                                             |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``collision_mode`` | Number     | Objects, Tables  | ``0``                      | Determines the collision shape of the object. See :ref:`file-type-3d` for more details.                                                                                           |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``color``          | String     | Objects          | ``#ffffff``                | Multiply the color of the texture by this value.                                                                                                                                  |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``default``        | Boolean    | Skyboxes, Tables | ``false``                  | If ``true``, the asset is loaded before the game starts. If ``true`` for multiple assets, one is loaded at random.                                                                |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``desc``           | Text       | All              | ``""``                     | Describes the asset in more detail.                                                                                                                                               |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``face_values``    | Dictionary | Dice             | ``{}``                     | Specifies which rotations correspond to what values on the faces of the die. See :ref:`object-type-dice` for more information.                                                    |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``hands``          | Array      | Tables           | ``[]``                     | The positions of player's hands around the table. See :ref:`asset-type-table` for more information.                                                                               |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``ignore``         | Boolean    | All              | ``false``                  | If ``true``, it tells the game to ignore this asset when importing the asset pack.                                                                                                |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``license``        | Text       | All              | ``""``                     | The license the asset is distributed under.                                                                                                                                       |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``main_menu``      | Boolean    | Music, Objects   | ``false``                  | If ``true``, objects will have a chance of spawning in the main menu, and music will have a chance of playing in the main menu.                                                   |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``mass``           | Number     | Objects          | ``1.0``                    | The mass of the object in grams (g) when it is spawned in-game. It is recommended to set this value for more realistic physics collisions.                                        |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``modified_by``    | Text       | All              | ``""``                     | The name(s) of the people who have modified the asset.                                                                                                                            |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``name``           | Text       | All              | ``<FILE_NAME>``            | The name of the asset. Must be unique among its type.                                                                                                                             |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``paint_plane``    | Vector2    | Tables           | ``Vector2(100.0, 100.0)``  | The length and width of the plane in which players can paint on the table. The centre of the plane is at the origin.                                                              |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``rotation``       | Vector3    | Skyboxes         | ``Vector3(0.0, 0.0, 0.0)`` | Rotates the skybox a number of degrees in the X, Y and Z axes.                                                                                                                    |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``scale``          | Vector3    | Objects          | ``Vector3(1.0, 1.0, 1.0)`` | Scales the object in the X, Y and Z axes in centimeters (cm). Note that for objects that use custom 3D models, this value most likely won't reflect the final size of the object. |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``sfx``            | Text       | Objects          | ``"generic"``              | Determines what the object sounds like when it collides with the table. Possible values are: ``"generic"``, ``"glass"``, ``"glass_heavy"``, ``"glass_light"``, ``"metal"``,       |
|                    |            |                  |                            | ``"metal_heavy"``, ``"metal_light"``, ``"soft"``, ``"soft_heavy"``, ``"tin"``, ``"wood"``, ``"wood_heavy"``, ``"wood_light"``.                                                    |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``shakable``       | Boolean    | Containers       | ``false``                  | If ``true``, when the container is being shaken upside down, it will randomly drop items out.                                                                                     |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``strength``       | Number     | Skyboxes         | ``1.0``                    | The strength of the ambient light coming from the skybox.                                                                                                                         |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``suit``,          | Number,    | Cards, Tokens    | ``null``                   | A value given to a stackable object that allows it to be sorted in a stack.                                                                                                       |
| ``value``          | Text       |                  |                            |                                                                                                                                                                                   |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ``url``            | Text       | All              | ``""``                     | The URL where the asset originally came from.                                                                                                                                     |
+--------------------+------------+------------------+----------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+


.. _stacks-cfg:

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
       "Card 1",
       "Card 2",
       "Card 3"
   ]

   ; This is the name of another stack.
   [My Friends Stack]

   desc = "My friend's stack isn't as good as my stack!"

   ; It doesn't matter if each object is on a new line.
   items = ["Trading Card 1", "Trading Card 2"]


Translations
^^^^^^^^^^^^

You can also provide translations for the names and descriptions of assets in
the asset pack! This is done using separate configuration files for each
language. The name of the file should be ``config.<locale>.cfg``, where
``<locale>`` is the `locale code
<https://docs.godotengine.org/en/stable/tutorials/i18n/locales.html>`_ for your
language.

.. note::

   The list of languages supported by the game is shown in the `README
   <https://github.com/drwhut/tabletop-club#languages>`_ file of the project.

   If the language you are translating to is not on this list, unfortunately
   you will not be able to see the results in-game. However, you can help to
   translate the project as a whole so your languages does become supported!
   See :ref:`translating-the-project` for more information.

.. note::

   These translation files are treated differently to other configuration files.
   You can only edit the ``name`` and ``desc`` properties of assets in these
   files. You also cannot apply translations to multiple assets at the same
   time with wildcards.

Here is an example of a Norwegian translation file, called ``config.nb.cfg``:

.. code-block:: ini

   ; The name here refers to the name of the asset in-game, NOT the name of
   ; the file. This should just be the file name, without the extension.
   [Chess]

   ; The name "Chess" in Norwegian.
   name = "Sjakk"

   ; A description in Norwegian, "A game for two people."
   desc = "Et spill for to personer."
