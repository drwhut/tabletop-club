.. _downloading-binaries:

=================================
Downloading the official binaries
=================================

.. note::

   Currently, the game is in alpha development and there are no official
   binaries to download. Hopefully this will change in the future!

   For now, you'll need to download the source code and compile it to play the
   game. You can follow the instructions in :ref:`compiling-from-source` to
   learn how.

You can download an official binary for your platform by going to the
`releases page <https://github.com/drwhut/open-tabletop/releases>`_  on GitHub
and downloading the compressed file for your platform under the version of the
game you want to play.

In most cases, you'll want to download the latest *non-beta* version of the
game. While beta versions of the game have new features and are very helpful
for player feedback, they are more suseptable to bugs. But if you're feeling a
little experimental, go for the latest version!

If you've downloaded OpenTabletop in the past and want to download a newer
version, follow :ref:`upgrading-installation` before carrying on here.

What happens now depends slightly on which platform you're on:

Downloading for Windows
-----------------------

1. Make sure you have downloaded the compressed file, it should be called
   something like ``OpenTabletop_vX.X.X_Windows_64.zip``.

2. Right-click the downloaded file in File Explorer, and click "Extract all..."

3. There should be a pop-up asking where you want to extract the files to.
   You can put the game files anywhere you like, for example
   ``Desktop/OpenTabletop``. You can then click "Extract" to extract the files
   to that location.

4. Go to the folder where you extracted the files, and double-click the
   ``OpenTabletop.exe`` executable to start the game!

   .. note::

      Currently Windows binaries of the game are not signed, so you'll most
      likely get a warning when you try to run the game saying that the
      publisher can't be trusted. You can get past this by clicking "More info",
      then by clicking "Run anyway".

Downloading for macOS
---------------------

1. Start downloading the compressed file, it should be called something like
   ``OpenTabletop_vX.X.X_OSX_Universal.zip``.

2. When it has downloaded, macOS should automatically extract the files in the
   Downloads folder for you. Go to your downloads folder in Finder, and find
   the extracted folder, it will be called something like ``OpenTabletop_v0``.

3. Re-name the new folder to ``OpenTabletop``.

4. Go into the folder, and launch the game by right-clicking ``OpenTabletop``
   and clicking "Open".

   .. note::

      Currently macOS binaries of the game are not signed, so you'll get a
      warning saying the publisher is unknown. You can get past this warning by
      clicking "Open" in the pop-up. This button won't appear if you
      double-click the application.

Downloading for Linux / \*BSD / Server
--------------------------------------

1. Make sure you have downloaded the compressed file, it should be called
   something like ``OpenTabletop_vX.X.X_Linux_64.tar.gz``, or
   ``OpenTabletop_vX.X.X_Server_64.tar.gz`` if you are downloading the
   dedicated server version of the game.

2. If your Linux/BSD distribution has a GUI, then you can use it to extract the
   files if you have a GUI archive manager installed. If you don't have a GUI,
   then a. I hope you're not trying to run a game with graphics in a terminal
   (unless it's a dedicated server, in which case I forgive you), and b. you
   can use this command to extract the files, where the X's are replaced with
   the numbers of the version you downloaded:

   .. code-block:: bash

      tar -xf OpenTabletop_vX.X.X_Linux_64.tar.gz

3. Either double-click the executable, or go into a terminal and run this
   command in the folder the executable is in:

   .. code-block:: bash

      ./OpenTabletop.x86_64

.. todo::

   Add instructions to check the SHA-256 of the compressed file.


.. _upgrading-installation:

Upgrading an existing installation
----------------------------------

If you have already downloaded the game before, and you want to overwrite the
files that are already there, then before downloading and extracting the new
version of the game, first delete the following files and folders:

* ``OpenTabletop.exe``, or ``OpenTabletop.app``, or ``OpenTabletop.x86_64``
* ``OpenTabletop.pck``
* ``assets/OpenTabletop``

Now you can extract the new version of the game as described above. If the
operating systems asks you if you want to replace any files, say yes to all
files.
