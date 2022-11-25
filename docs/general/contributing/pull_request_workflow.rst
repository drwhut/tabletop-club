.. _pull-request-workflow:

=====================
Pull request workflow
=====================

If you want to help contribute to the project directly, by either fixing a bug
or implementing a feature, then you'll need to create a **pull request** on
the project's `GitHub repository`_. This page explains the steps needed to do
exactly that!


Creating a fork
---------------

The way to think about forks is by thinking about going down a side road on a
fork in the road - you'll be doing your own think on the side road (your
"fork") while the main road (the repository's ``master`` branch) goes on.
Eventually, the side road will join back in with the main road later on (the
"merge").

To create a fork of the Tabletop Club repository on GitHub, you can go to the
`GitHub repository`_ and click on the :guilabel:`Fork` button on the top-right.
You should now have your own copy of the repository at that point in time.
You can then clone the repository to your computer with ``git clone``.

In this cloned repository, ``origin`` will point to your forked repository,
which will not automatically update with the original repository. To make sure
you can get updates from the original repository, you can add the original
as a remote repository with this command:

.. code-block:: bash

   git remote add upstream https://github.com/drwhut/tabletop-club.git

Now, if you ever need to update the ``master`` branch on your local repository,
you can run the following commands:

.. code-block:: bash

   git checkout master
   git pull upstream master

You can then update your fork on GitHub with these changes:

.. code-block:: bash

   git push origin master


Downloading and compiling Godot
-------------------------------

Now that you have made a local copy of the fork on your computer, there's one
more step that's needed to be able to play, edit, and test the game - you'll
need to download and compile the modified version of Godot the game runs on.
You can follow the instructions in :ref:`compiling-from-source` up until the
section where you download the game (you already did that just!) to get Godot
up and running.


Making changes
--------------

Before you start making the changes you want to make, it is highly advised that
you create a branch on the local repository for the bug/feature you're going to
solve:

.. code-block:: bash

   git branch <branch_name>
   git checkout <branch_name>

Now you can start working on the code! See :ref:`coding-guidelines` for
guidelines as to how you should write your code.

.. note::

   When you are done, you should commit your changes and push them to your fork
   with these commands:

   .. code-block:: bash

      git add .
      git commit
      git push -u origin <branch_name>


Creating a pull request
-----------------------

Once you've made the changes you wanted to make, and you've thoroughly tested
them, you can push them to the custom branch on your forked repository and
create a pull request!

To start, go to the original `GitHub repository`_ and click
:guilabel:`Pull requests` > :guilabel:`New pull request`. Make sure you are
merging from your fork's custom branch to ``drwhut/tabletop-club`` on the
``master`` branch. If GitHub is happy, then you can click
:guilabel:`Create pull request`, and fill in the details for the pull request.

.. note::

   If the pull request was to fix an issue, then please put the issue number in
   the pull request! For example, if the issue fixes issue number ``69``, then
   say in the pull request: ``This PR fixes #69``.

Once you're done filling in the PR, you can submit it!

.. note::

   If we ask you to make changes to the pull request, you can do so by making
   the changes locally on your computer and pushing the commits to your fork's
   custom branch. These new commits will appear automatically in the PR.


Resolving merge conflicts
-------------------------

There is a chance that GitHub will not let us merge the pull request into the
``master`` branch because of a merge conflict between the ``master`` branch and
the branch on your fork. In this case, you should take the following steps:

1. Update the fork's ``master`` branch so it is up-to-date with the original's:

   .. code-block:: bash

      git checkout master
      git pull upstream master
      git push origin master

2. Merge the ``master`` branch on your local repository into your custom branch:
   
   .. code-block:: bash

      git checkout <branch_name>
      git merge master
    
   .. note::

      You can also use ``rebase`` here instead of ``merge``, but we don't mind
      whichever command you use. Use whichever one you're most comfortable
      with!
    
   At this point you'll get the same merge conflicts that stopped the pull
   request from being merged. You need to resolve them before continuing.

3. Test that the changes you've made still work after the merge.

4. Push the merge commit, plus any other commits you make, to your fork.

5. Go back to the pull request on GitHub, and ensure that there are no merge
   merge conflicts.


.. _GitHub repository: https://github.com/drwhut/tabletop-club
