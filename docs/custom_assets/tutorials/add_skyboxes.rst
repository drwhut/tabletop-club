Adding skyboxes
===============

To add your own skybox to the game, simply create a ``skyboxes`` folder inside
your asset pack, then place your skybox image into that folder, like this:

.. code-block::
   
   MyAssetPack
       └── skyboxes
           └── My Skybox.png

Once the skybox has been imported, you can go in-game and press :guilabel:`Room`
> :guilabel:`Skybox` > :guilabel:`Change skybox`, select the skybox from your
asset pack, then click :guilabel:`Apply`.

.. note::

   The only format that the game accepts are equirectangular images like this
   one:

   .. image:: example_skybox.jpg
      :alt: A 360 degree image of an urban park, projected onto a rectangular
         image.

   If the skybox you want to add is cube-mapped, you can find more information
   about how to convert it in :ref:`asset-type-skybox`.
