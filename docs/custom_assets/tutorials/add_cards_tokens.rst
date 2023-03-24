.. _tutorial-adding-images:

Adding images as cards and tokens
=================================

This tutorial will teach you how to add images to an asset pack to make cards
and tokens, which are in-game objects that can stack on top of each other.
If you wish to add another kind of object to the game, see
:ref:`tutorial-adding-3d-models`.


Cards or tokens?
----------------

Cards and tokens, while both are able to stack, differ slightly in extra
functionality. If you're not sure which type of object you want to create, see
:ref:`object-type-card` and :ref:`object-type-token`.


Preparing the image
-------------------

Before we add the image to the asset pack, we will first need to make sure it
is set up properly so it will appear correctly in-game.


Preparing card images
^^^^^^^^^^^^^^^^^^^^^

Luckily, there is not much to do to set up card images, since the image will be
shown as-is in-game! The only requirement is that each card will need it's own
image (this includes the back face of the cards).


Preparing token images
^^^^^^^^^^^^^^^^^^^^^^

For tokens, since the image will be mapped to a 3D shape (either a cube, or a
cylinder), you'll need to modify the image to fit what is called a "UV mapping".
This means your final image needs to look like this:

**Cube:**

.. image:: ../asset_packs/uv_mappings/cube.svg

**Cylinder:**

.. image:: ../asset_packs/uv_mappings/cylinder.svg

.. note::

   The resolution of the final image does not matter, only the *proportions* do.
   See :ref:`file-type-image` for more information.


Adding the images to the asset pack
-----------------------------------

With the images set up, we can now add them to the asset pack! If you do not
already have one, see :ref:`tutorial-creating-asset-pack`.

In your asset pack, create a folder named either ``cards`` or ``tokens``. If you
are adding tokens, you'll need to create a sub-folder named either ``cube`` or
``cylinder`` depending on what shape the token will be. Once the folders are
created, it's just a matter of copying the images to their respective folders,
like so:

.. code-block::

   MyAssetPack
   ├── cards
   │   ├── Back.png
   │   ├── Card1.png
   │   └── Card2.png
   └── tokens
       ├── cube
       │   └── CubeToken.jpg
       └── cylinder
           ├── CylinderToken1.png
           └── CylinderToken2.png


Configuring the object size
---------------------------

At this point, you can launch the game and see that there are now objects
in-game with your images on them, except they they are probably the wrong size.
This is because without telling the game otherwise, it will assume the object is
1cm x 1cm x 1cm.

We can tell the game what size the object should actually be by creating a
:ref:`config-cfg` file next to our images in the asset folder. Create a file
with this name in your file manager, then open it with a text editor of your
choice! Here are a few examples of how to set the size of your objects:

.. code-block:: ini

   ; MyAssetPack/tokens/cylinder/config.cfg
   
   ; You can set the size of each object individually:
   [CylinderToken1.png]

   ; Object is 5.0cm wide, 2.5cm tall, 3.0cm deep.
   scale = Vector3(5.0, 2.5, 3.0)

   [CylinderToken2.png]
   scale = Vector3(10.0, 15.0, 10.0)

.. code-block:: ini

   ; MyAssetPack/cards/config.cfg

   ; You can also set the size of all objects in one go using a wildcard:
   [*]
   scale = Vector2(6.0, 8.0)

.. note::

   Cards are always the same thickness, so the ``scale`` for cards is always a
   ``Vector2`` containing two numbers, rather than a ``Vector3``.


Configuring card backs
----------------------

Using the :ref:`config-cfg` file, you can also tell the game what image to use
for the back face of cards. Using ``Back.png`` as an example:

.. code-block:: ini

   ; MyAssetPack/cards/config.cfg
   
   ; Using the scale from before...
   [*]
   scale = Vector2(6.0, 8.0)

   ; This line adds the back face for all cards, including Back.png!
   back_face = "Back.png"

   ; We can also tell the game to not import Back.png as it's own card:
   [Back.png]
   ignore = true


See more
--------

Congratulations, you now have your own cards and tokens in the game!

If you want to further configure your objects, see :ref:`object-type-card`,
:ref:`object-type-token`, and :ref:`config-cfg`.

If you want to add pre-made stacks of cards and tokens to your asset pack, see
:ref:`stacks-cfg`.
