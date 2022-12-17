.. _tutorial-adding-3d-models:

Adding 3D models as objects
===========================

This tutorial will teach you how to export 3D models from `Blender
<https://www.blender.org/>`_ and add them to the game. If you wish to
specifically add stackable objects like cards or tokens to the game, see
:ref:`tutorial-adding-images`.


Note about Blender
------------------

This tutorial will be using Blender as an example to export a model ready for
the game to use. It is worth noting however that if you already use another
application for 3D-modelling, then it's okay as long as the application can
export the model into one of the supported formats outlined in
:ref:`file-type-3d`.

If you do not have a 3D-modelling application installed, then I very highly
recommend Blender in general, not only for this tutorial, but because it is
free, and it is (in my humble opinion) one of the best open-source applications
ever made! You can download it `on their website
<https://www.blender.org/download/>`_.


Setting up the model
--------------------

For the start of this tutorial, we're going to assume you have a 3D model in
Blender already. If this is not the case, you can either create one, or you can
import a model from the game's ``assets`` folder by going to :guilabel:`File` >
:guilabel:`Import`!

.. note::

   This is the ``assets`` folder next to the game executable, not the one under
   your Documents.

Once you can see your model in Blender, the first thing we will do is scale it
to match the in-game dimensions we want. The golden rule is as follows:

**One unit in Blender = 1cm in Tabletop Club.**

Select your object in Object Mode. From here, there are two ways you can set the
scale of an object in Blender:

* Pressing :guilabel:`S`, then moving the mouse of typing a number to adjust the
  size. You can then also press :guilabel:`X`, :guilabel:`Y` or :guilabel:`Z` to
  set the scale of the object on a specific axis.

* In the main viewport, drag out the arrow on the right-hand side by the axis
  gizmo to bring out the Transform menu. At the bottom there should be three
  numbers representing the Dimensions of the object, which you can change.

  .. note::

     The units in the transform menu don't affect the size of the exported
     model.


Further setup for tables
^^^^^^^^^^^^^^^^^^^^^^^^

Lastly, if the model is a :ref:`asset-type-table`, we will need to adjust it's
position in the scene.

.. note::

   Positioning only matters for tables. Objects can be in any position in the
   scene, since the game will automatically center them when importing the
   model.

To position the table, select it in object mode, then you can use :guilabel:`G`,
then either :guilabel:`X`, :guilabel:`Y` or :guilabel:`Z` before moving the
mouse to move it in that respective axis. You'll want to position it with these
points in mind:

* The table should be in the centre of the scene.
* The surface of the table should as close to ``z = 0`` as possible.


Exporting the model
-------------------

When exporting models, there are multiple different formats to choose from.
The recommended format for Tabletop Club is glTF 2.0, with both binary
(``.glb``) and seperate (``.gltf``) formats supported. However, it is not the
only supported option - see :ref:`file-type-3d` for all supported formats.

To export the model, click on :guilabel:`File` > :guilabel:`Export` >
:guilabel:`glTF 2.0 (.glb/.gltf)`, and in the dialog, go to your asset pack
folder (if you do not have one, see :ref:`tutorial-creating-asset-pack`). From
here, you have a choice as to what folder you can create and put the exported
model in, depending on what functionality the object should have:

* :ref:`object-type-board`: ``MyAssetPack/boards``
* :ref:`object-type-container`: ``MyAssetPack/containers``
* :ref:`object-type-dice`: ``MyAssetPack/dice`` - then depending on how many
  sides the die has, a further subfolder named: ``d4``, ``d6``, ``d8``, ``d10``,
  ``d12``, or ``d20``.
* :ref:`object-type-piece`: ``MyAssetPack/pieces``
* :ref:`object-type-speaker`: ``MyAssetPack/speakers``
* :ref:`asset-type-table`: ``MyAssetPack/tables``
* :ref:`object-type-timer`: ``MyAssetPack/timers``

If you are not sure what type of object the model should be, then a safe default
is :ref:`object-type-piece`, since it has no special functionality.


See more
--------

And with that, the next time you launch the game, you should be able to spawn in
your 3D model in-game through the :guilabel:`Objects` menu!

If you want to configure your new objects, feel free to have a look at
:ref:`file-type-3d` and :ref:`config-cfg`.
