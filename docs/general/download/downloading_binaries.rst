.. _downloading-binaries:

=================================
Downloading the official binaries
=================================

There are multiple ways to download and play the game:


From the itch app
-----------------

This is the recommended way to download and play the game, since you'll get
updates automatically whenever they are released, and you'll also get access to
a huge range of amazing indie games from developers far more talented than I am!

You can download the itch app `here <https://itch.io/app>`_, and once you've
logged in, search for "Tabletop Club" to download and install the game.


From Flathub
------------

If you are on a Linux distribution that supports Flatpaks, you can download the
latest stable version of the game directly from your software manager! Simply
search for "Tabletop Club" to download and install the game. Alternatively, you
can visit the project page on
`Flathub <https://flathub.org/apps/net.tabletopclub.TabletopClub>`_.

If Flathub is not included in your list of Flatpak repositories, the game will
not appear. You can add Flathub as a remote repository by following the
instructions `on their website <https://flatpak.org/setup/>`_.

You can also download the game via the command line instead once Flathub has
been added as a remote repository:

.. code-block:: bash

   flatpak install flathub net.tabletopclub.TabletopClub
   flatpak run net.tabletopclub.TabletopClub


As a standalone executable
--------------------------

You can also download the game as a standalone application that you can run
anywhere on your system from the `itch.io page
<https://drwhut.itch.io/tabletop-club>`_, or from the `GitHub repository
<https://github.com/drwhut/tabletop-club/releases>`_. Once it is downloaded,
there's only a couple of steps needed to run the game (see below)!

In most cases, you'll want to download the latest *stable* version of the game.
While beta versions of the game have new features and are very helpful for
player feedback, they are more suseptable to bugs. But if you're feeling a
little experimental, go for the latest version!

If you've downloaded Tabletop Club in the past and want to download a newer
version, follow :ref:`upgrading-installation` before carrying on here.


Verifying the download
^^^^^^^^^^^^^^^^^^^^^^

This step is completely optional, but it's a good idea to make sure that the
downloaded file's contents are what we expect them to be. We do this by checking
the `SHA512 hash <https://en.wikipedia.org/wiki/SHA-2>`_ of the file, and seeing
if the hash matches the original.

1. Download from the GitHub releases page the ``TabletopClub_vX.X.X_SHA512.txt``
   file. This text file contains the SHA512 hashes of all of the downloads.

2. Open a command prompt or terminal, and navigate to the folder where the
   compressed binary lies.

3. Enter the command for your platform, adjusting the file name where necessary:

   .. code-block:: bash

      # Windows
      certutil -hashfile TabletopClub_vX.X.X_Windows_64.zip SHA512

      # macOS
      shasum -a 512 TabletopClub_vX.X.X_OSX_Universal.zip

      # Linux / *BSD
      sha512sum TabletopClub_vX.X.X_Linux_64.zip

4. Compare the output of the previous command to the corresponding line in the
   SHA512 text file. If the hashes do not match, then you will need to download
   the binary again.


What happens now depends slightly on which platform you're on:

Downloading for Windows
^^^^^^^^^^^^^^^^^^^^^^^

1. Make sure you have downloaded the compressed file, it should be called
   something like ``TabletopClub_vX.X.X_Windows_64.zip``.

2. Right-click the downloaded file in File Explorer, and click
   :guilabel:`Extract all...`

3. There should be a pop-up asking where you want to extract the files to.
   You can put the game files anywhere you like, for example
   ``Desktop/TabletopClub``. You can then click :guilabel:`Extract` to extract
   the files to that location.

4. **(Windows 11 Only)** Right-click the ``TabletopClub`` executable, and go to
   :guilabel:`Properties`. You will need to tick the :guilabel:`Unblock`
   checkbox at the bottom of the window in order to start the game.

5. Go to the folder where you extracted the files, and double-click the
   ``TabletopClub.exe`` executable to start the game!

   .. note::

      Currently Windows binaries of the game are not signed, so you'll most
      likely get a warning when you try to run the game saying that the
      publisher can't be trusted. You can get past this by clicking
      :guilabel:`More info`, then by clicking :guilabel:`Run anyway`.

Downloading for macOS
^^^^^^^^^^^^^^^^^^^^^

1. Start downloading the compressed file, it should be called something like
   ``TabletopClub_vX.X.X_OSX_Universal.zip``.

2. When it has downloaded, go to your downloads folder in Finder, and find
   the compressed file. Double-click the file to extract the application.

3. Launch the game by right-clicking ``TabletopClub`` and clicking
   :guilabel:`Open`.

   .. note::

      Currently macOS binaries of the game are not signed, so you'll get a
      warning saying the publisher is unknown. You can get past this warning by
      clicking :guilabel:`Open` in the pop-up. This button won't appear if you
      double-click the application.

Downloading for Linux / \*BSD
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

1. Make sure you have downloaded the compressed file, it should be called
   something like ``TabletopClub_vX.X.X_Linux_64.zip``.

2. Either use your distribution's archive manager to extract the files, or run
   this command in a terminal:

   .. code-block:: bash

      unzip TabletopClub_vX.X.X_Linux_64.zip

3. Either double-click the executable, or go into a terminal and run this
   command in the folder the executable is in:

   .. code-block:: bash

      ./TabletopClub.x86_64


.. _upgrading-installation:

Upgrading an existing installation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If you have already downloaded the game before, and you want to overwrite the
files that are already there, then before downloading and extracting the new
version of the game, first delete the following files and folders:

* ``TabletopClub.exe``, or ``TabletopClub.app``, or ``TabletopClub.x86_64``
* ``TabletopClub.pck``
* ``assets/TabletopClub``

Now you can extract the new version of the game as described above. If the
operating systems asks you if you want to replace any files, say yes to all
files.
