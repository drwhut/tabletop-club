===========
Asset types
===========

.. _asset-type-object:

Object
------

An object in OpenTabletop refers to anything in-game that is dynamic (that is,
it is driven by the physics engine). There are many different types of objects,
each with their own special functionality:

.. todo::

   Add images of each of the different types of objects.


.. _object-type-card:

Card
^^^^

Cards are flat, rectangular-shaped objects that are stackable, and they have
the unique functionality to be able to be put in a player's hand, where only
the player whose hand it is can see the front face of the card.

Unlike other objects, you need two separate textures for cards - one for the
front face, and one for the back face. The game registers each of the textures
in the ``cards/`` folder as the front face of a card, but you need to tell the
game where to find the back face in the ``config.cfg`` file.

Here is a simple example that will apply a back face texture (in this example,
``BackFace.png``) to all of the cards in the folder:

.. code-block:: ini

   ; cards/config.cfg
   [*]

   back_face = "BackFace.png"

   [BackFace.png]

   ; If we don't ignore the back face, then a card with both sides being the
   ; back face will be imported.
   ignore = true


.. _object-type-container:

Container
^^^^^^^^^

Containers are special objects that can hold an unlimited amount of other
objects inside themselves (including other containers)! Containers are opaque,
meaning you cannot see the objects physically inside of them, but you can peek
inside a container by right-clicking it and pressing :guilabel:`Peek inside`,
which will open a pop-up showing the contents of the container.

Objects can be placed inside containers by dropping them on top of the
container, and objects can be randomly removed from the container by quickly
dragging from the container. You can also shake the contents of the container
out by flipping the container upside-down and shaking it with your mouse.


.. _object-type-dice:

Dice
^^^^

Dice are objects that, when shaken, randomize their orientation.


.. _object-type-piece:

Piece
^^^^^

Pieces are generic objects with no special functionality.


.. _object-type-speaker:

Speaker
^^^^^^^

Speakers are objects that can play audio tracks. They emit sound positionally,
so the audio will vary depending on the position of the speaker relative to the
camera.


.. _object-type-timer:

Timer
^^^^^

Timers are objects that can be used as countdowns, stopwatches, or to display
the system time. If an audio track is loaded, it will automatically play when
the countdown reaches 0.


.. _object-type-token:

Token
^^^^^

Tokens are objects that are vertically stackable, meaning they join together
when their top and bottom faces touch, similar to cards.


.. _asset-type-sound:

Sound
-----

Sounds can be played through either a :ref:`object-type-speaker` or a
:ref:`object-type-timer`.


.. _asset-type-music:

Music
-----

Music tracks are the same as sounds, but they can also be configured to play
in the main menu. See the ``main_menu`` property in :ref:`config-cfg`.


.. _asset-type-game:

Game
----

A game is a :ref:`file-type-save` that has been pre-made such that players can
instantly setup the table to play a particular game.


.. _asset-type-skybox:

Skybox
------

Skyboxes are special textures that determine what the environment around the
table looks like.

Skybox textures in OpenTabletop use equirectangular mappings, as opposed to
six-image cube mappings. Godot recommends using `this tool
<https://danilw.github.io/GLSL-howto/cubemap_to_panorama_js/cubemap_to_panorama.html>`_
to convert cube-mapped skyboxes to equirectangular skyboxes.

For the best lighting quality, it is recommended to use a HDR panorama.
OpenTabletop supports the Radiance HDR (``.hdr``) and OpenEXR (``.exr``)
formats.
