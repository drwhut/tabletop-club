Adding audio tracks
===================

Adding your own audio files to an asset pack is really simple, all you need to
do is create a folder named either ``music`` or ``sounds``, and place your audio
files inside. Afterwards, your asset pack may look something like this:

.. code-block::
   
   MyAssetPack
       ├── music
       │   ├── Music1.mp3
       │   └── Music2.mp3
       └── sounds
           ├── SoundEffect1.wav
           ├── SoundEffect2.wav
           └── SoundEffect3.wav

.. note::

   There is a slight difference between ``music`` and ``sounds``: Tracks placed
   in ``music`` will repeat once the track ends, whereas ones in ``sounds``
   won't.

Once the tracks have been imported, you can then play them in-game through
either a :ref:`object-type-speaker` or a :ref:`object-type-timer`.

For more information, see :ref:`file-type-audio`.
