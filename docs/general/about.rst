.. _about-tabletop-club:

*****
About
*****

What is Tabletop Club?
======================

Tabletop Club is a free and open-source tabletop board game simulator! That's a
bit of a mouthful, so I'll break that sentence down a bit:

Free
----

The game is completely free to download and play! You can do so by going to the
:ref:`downloading-binaries` page.

Open-source
-----------

This means a few things:

* The source code of the game is visible to the public (you can see it in the
  `GitHub repository <https://github.com/drwhut/tabletop-club>`_). This also
  means you can compile the game youself from scratch (see
  :ref:`compiling-from-source`).

* Anyone can contribute to the development of Tabletop Club in a number of
  different ways! For more information about how you can help contribute to the
  project, visit the :ref:`contributing` page.

* The game is licensed under the `MIT License
  <https://github.com/drwhut/tabletop-club/blob/master/LICENSE>`_, which is an
  open, permissive license.

  .. note::

     The game's code and project files are licensed under the MIT License, but
     some of the assets are licensed under different open licenses.

     To see the authors and licenses of these assets, you can check the
     ``game/LICENSES.tres`` file, as well as hovering over items in the objects
     menu in-game (which can also be found in the various ``.cfg`` files under
     ``assets/``).

Tabletop board game
-------------------

The game is designed to allow you to play your favourite tabletop board games
by effectively giving you a box of toys to play with (which include things like
cards, dice, game pieces, and more), and it's up to you what you do with what
you're given!

But the coolest thing about the game is that anyone can create assets for the
game! It's as simple as dragging files into a folder and the game will import
them, then you can use them straight away in-game! If you want to learn more
about how to make assets for Tabletop Club, visit the :ref:`asset-packs` page.

Simulator
---------

Not only is the game a simulator of tabletop games, it also has a
fully-simulated 3D physics engine! This means that objects in the game act like
they do in real life, and it also means you can potentially send objects
flying off the edge! Did I also mention you could flip the table?


Frequently Asked Questions
==========================

What platforms can I play Tabletop Club on?
-------------------------------------------

Tabletop Club can be played on any of these platforms:

* Windows
* macOS
* Linux / \*BSD

Currently there are no plans for the game to be supported on mobile devices or
consoles.


Does Tabletop Club support multiplayer?
---------------------------------------

Yes! You don't need to make an account to play multiplayer, you can just host a
game and start playing with friends!

.. hint::

   You can change your name and colour in multiplayer by going to
   :guilabel:`Options` > :guilabel:`Multiplayer`, and changing the relevant
   settings.


Is Tabletop Club on Steam / GOG / itch.io?
------------------------------------------

No. Tabletop Club is a standalone game, meaning when you download the game you
can extract the game files anywhere you want on your computer, and the game
will work.

However, when the game is released, you will be able to download it from
itch.io!


What stage of development is Tabletop Club at?
----------------------------------------------

Tabletop Club is currently in alpha development. This means that core features
of the game are still being implemented (you can see what needs to be added by
going to the `issues page <https://github.com/drwhut/tabletop-club/issues>`_ on
GitHub), and there are no publicly released versions of the game... yet.


What board games can I play in Tabletop Club?
---------------------------------------------

Theoretically, any of them!

Out of the box, the games comes with the default Tabletop Club asset pack which
contains some of the most common objects you'll need, like playing cards, dice,
poker chips, etc.

On GitHub, there is `an issue
<https://github.com/drwhut/tabletop-club/issues/28>`_ listing which objects
still need to be added to the default asset pack. If everything under a game is
ticked, then you can play that game!

On the other hand, if the pieces you need aren't going to be included in the
default asset pack, then you can either download an asset pack that someone
else has already made, or you can create your own! Visit the :ref:`asset-packs`
page if you're interested in making your own assets.


How easy is it to setup a game in Tabletop Club?
------------------------------------------------

For the most popular games, the default asset pack comes with pre-made save
files that you can load instantly (when in-game, click :guilabel:`Games`, then
click on the game you want to play, then click :guilabel:`Load`) to play the
game right away!

If there isn't a pre-made save file for the game you want to play, you can
easily make your own save by setting up the table the way you want to, then by
going to the menu and clicking :guilabel:`Save file`. This way, if you want to
play the game again, you can just load the save you made previously.

See the :ref:`asset-type-game` page for more information about pre-made save
files in asset packs.


Can I add assets other than game pieces to Tabletop Club?
---------------------------------------------------------

Yes! As well as objects, you can also import the following types of assets:

* :ref:`asset-type-game`
* :ref:`asset-type-music`
* :ref:`asset-type-skybox`
* :ref:`asset-type-sound`
* :ref:`asset-type-table`


Can you add my favourite board game to Tabletop Club?
-----------------------------------------------------

For legal safety, Tabletop Club will only ever distribute `public-domain
<https://en.wikipedia.org/wiki/Public_domain>`_ board games in the default
asset pack. But that doesn't stop you from making assets for your favourite
board game for private use!


Can I share assets I've made on the internet?
---------------------------------------------

It depends on a number of factors. In general, it should be safe to share the
assets you've made for the game if the following is all true:

* The assets you've made (textures, 3D models, etc.) are made by you, and are
  not derived from copyrighted material.

  .. note::

     You can distribute other people's creations **if** the license it's under
     allows you to. It's always safer to attribute the original author, and to
     state the license and whether the content was modified. Please read the
     terms of the license first.

     To help with this, the :ref:`config-cfg` file allows you to put the author,
     license, modifier, and URL with the asset, which is then shown in-game.

* If the assets you've made are for playing a game that already exists, then:

  * You cannot use the same name of the game without the owner's explicit
    permission.

  * The mechanics of the game cannot be patented.

    .. tip::
    
       You can `check online <https://worldwide.espacenet.com/advancedSearch>`_
       to see if there are any patents for the game's mechanics.

.. warning::

   This is NOT legal advice. Please go ask the nearest lawyer for advice if you
   are worried about distributing your asset pack on the internet, as this also
   depends on your country's copyright laws.
