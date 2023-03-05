.. _tutorial-adding-notebook-templates:

Adding notebook templates
=========================

In Tabletop Club, you can keep track of things like scores or character
attributes using the in-game notebook, which is used to store persistent text
(that is, text that stays there after you exit the game). Using this tutorial,
you will be able to create a template that can be chosen when a new page is
added to the notebook.

There are two kinds of notebook templates: **text-based** and **image-based**.
Text-based pages act a lot like regular text files, where the player is given
an infinite amount of space to type text, but it may not be as intuitive to use.
Image-based pages have an image in the background, and a number of pre-defined
textboxes in the foreground that can be typed into individually.


Adding a text-based template
----------------------------

Text-based templates are very easy to set up: all you need is a text file
(``.txt``) containing the text you want, which is placed in the ``templates``
folder of your asset pack, like so:

.. code-block::

   MyAssetPack
   └── templates
       └── My Template.txt

And that's it! You can then open the Notebook in-game, create a new page using
the template, and you should see the contents of the text file on the page.


Adding an image-based template
------------------------------

There are two steps for adding an image template: the first is to take the image
you want as the background, and place it inside the ``templates`` folder in your
asset pack, like so:

.. code-block::

   MyAssetPack
   └── templates
       └── My Template.png

Secondly, we need to create a :ref:`config-cfg` file to define our textboxes.
Open a text editor, and save a file next to the image in the asset pack as
``config.cfg``. In this file, we'll define the ``textboxes`` property for our
image, like so:

.. code-block:: ini

   ; MyAssetPack/templates/config.cfg
   [My Template.png]

   ; If you want, you can also put a description and other details, but these
   ; are completely optional.
   desc = "This is my first template!"
   author = "Bob"
   license = "CC0"

   ; This is where we define the property - the curly braces are mandatory.
   textboxes = {

   }

For each textbox, we can set a number of details to get the template to look
exactly how we want - but for now, we'll focus on the main ones:

* ``id``: The unique identifier for the textbox.
* ``x``: The horizontal position of the top-left corner of the textbox.
* ``y``: The vertical position of the top-left corner of the textbox.
* ``w``: The width of the textbox.
* ``h``: The height of the textbox.

.. note::

   All of the units are in pixels, and the origin (0, 0) is at the top-left
   corner of the image, so increasing "x" moves the textbox right, and
   increasing "y" moves the textbox down.

As an example, a textbox may be defined like this:

.. code-block:: ini

   "my_textbox": { "x": 100, "y": 100, "w": 500, "h": 200 }

This would create a textbox called ``my_textbox`` that is 100 pixels right, and
100 pixels down from the top-left corner of the image, as well as 500 pixels
wide and 200 pixels high.

In the ``config.cfg`` file, you would have multiple of these textboxes, all of
them seperated by a comma:

.. code-block:: ini

   ; MyAssetPack/templates/config.cfg
   [My Template.png]

   textboxes = {
       ; The example above, but inside the curly braces. Note the comma at the
       ; end, which allows us to define another textbox after it.
       "my_textbox": { "x": 100, "y": 100, "w": 500, "h": 200 },

       ; A second square-shaped textbox, to the right of the first.
       ; Note that the last textbox in the list doesn't need a comma after it.
       "second_textbox": { "x": 700, "y": 100, "w": 300, "h": 300 }
   }

With that saved in ``config.cfg``, if you launch the game, open the notebook and
use the template when creating a new page, not only should you see the image,
but also the two textboxes in the top-left corner of the image!


See more
--------

Now you know how to create templates for the notebook! If you want to know more
about templates, and how to customise textboxes further, see
:ref:`asset-type-template`.
