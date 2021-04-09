.. _running-a-server:

****************
Running a server
****************

OpenTabletop supports both local and online multiplayer through the use of
dedicated servers. This page explains how to set up a dedicated server, and how
players can join the server.


Setting up a server instance
============================

Firstly, we're going to need to configure a server instance of OpenTabletop
that we can run.

We're assuming from now on that you've already downloaded the game - if not,
you should go to the :ref:`download` page first before continuing.

1. Create a new folder for the server files. For this example, we'll call the
   folder ``OTServer``, but you can call the folder anything you want.

2. Copy all of the game files from the folder you extracted the game to
   previously into the new ``OTServer`` folder. After this step, you should
   have an executable either at ``OTServer/OpenTabletop.app``,
   ``OTServer/OpenTabletop.exe``, or ``OTServer/OpenTabletop.x86_64``.

3. Go to `this page
   <https://raw.githubusercontent.com/drwhut/open-tabletop/master/game/server.cfg>`_,
   right-click the page and save the file into the ``OTServer`` folder with the
   name ``server.cfg``.

4. Run the server by double-clicking the executable in ``OTServer``, and make
   sure that after the assets have been imported you can see the table in-game.

5. You can close the server by clicking :guilabel:`Menu` >
   :guilabel:`Quit to desktop`.


From the Godot Editor
---------------------

If you are running the game through the Godot Editor, or you are running a
debug build of the game and have a ``server.cfg`` file next to the executable
as described above, you should see a button on the main menu labeled
:guilabel:`Debug: Start Dedicated Server`. Clicking this button will start the
server.


Testing the server
------------------

To test if the server is accepting connections, you can start a normal version
of OpenTabletop on the same computer, and in the main menu to the left of the
:guilabel:`Join Game` button, you can enter ``127.0.0.1:26271``, then click
:guilabel:`Join Game`.

.. note::

   If you've changed the port number the server is on, replace the number after
   the colon with the port number you put in ``server.cfg``.

If the server is working, then you should be able to see a chat box in the
bottom-left that says ``<PLAYER_NAME> has joined the game.``

If the server is not working, then after a few seconds of trying to connect,
the client will go back to the main menu and show an error saying it was unable
to connect to the server.


Local multiplayer
=================

If you want players to be able to connect to your server from your Local Area
Network (LAN), you need to know the IPv4 address of the computer the server is
running on. If you don't know it, then here's how you can find out what the
address is:

* On Windows, open a command prompt and run the ``ipconfig`` command. You can
  identify the address of the computer by looking for the
  :guilabel:`IPv4 Address` entry.

* On macOS / Linux / \*BSD, open a terminal and run the ``ifconfig`` command.
  You can identify the address of the computer by looking for what comes after
  :guilabel:`inet`, but making sure it isn't ``127.0.0.1`` (that is how your
  computer addresses itself, not how other computers on the network address it).

Once you know this address, you can tell the other players to enter
``<IP_ADDRESS>:<PORT>`` (e.g. ``192.168.1.8:26271``) in the main menu, next to
the :guilabel:`Join game` button. They can then click that button to join your
server!


Online multiplayer
==================

If you want players to be able to connect to your server from the wild west
that is the internet, across hills of memes and valleys of Facebook users, then
you'll need to know your router's IPv4 address. This is easier to find out that
getting your computer's local IP address, you just need to open your web
browser and type into your favourite search engine: "what is my ip address".
If the search engine doesn't tell you, then you can go to the first result and
find out there.

But there's one more step needed to make your server accessible to the world:
you need to do something called **port forwarding**, which tells your router to
forward incoming messages from the outside world on a given port to a
particular computer on the network (the one that's hosting your server).
You can find out how to port forward with your network's router by going to
https://portforward.com/router.htm - you'll want to set it up such that the
external and internal ports are the same as in ``server.cfg``, and the internal
address is the local IP address of the computer running the server.

Once you have port forwarded, players can join the server using the same string
of text as they would in local multiplayer, but instead of using your local IP
address, they should use your router's IP address.

.. note::

   If players still cannot join your server after you have port forwarded, try
   checking your firewall's settings. Make sure that your firewall isn't
   rejecting packets with the server's port number.
