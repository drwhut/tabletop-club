# Configuration file for the Sphinx documentation builder.
#
# This file only contains a selection of the most common options. For a full
# list see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Path setup --------------------------------------------------------------

# If extensions (or modules to document with autodoc) are in another directory,
# add these directories to sys.path here. If the directory is relative to the
# documentation root, use os.path.abspath to make it absolute, like shown here.
#
# import os
# import sys
# sys.path.insert(0, os.path.abspath('.'))


# -- Project information -----------------------------------------------------

project = 'Tabletop Club'

# TODO: Sphinx now supports multiple entries for the copyright, but the theme
# does not display them properly. Edit once the issue has been fixed.
copyright = "2020-2024, Benjamin 'drwhut' Beddows, Tabletop Club contributors"

# The major and minor version, excluding the patch number.
version = 'master'

# The full version, including the patch number, and any alpha/beta/rc tags.
release = 'master'


# -- General configuration ---------------------------------------------------

# Add any Sphinx extension module names here, as strings. They can be
# extensions coming with Sphinx (named 'sphinx.ext.*') or your custom
# ones.
extensions = [
    "sphinx.ext.todo"
]

# Add any paths that contain templates here, relative to this directory.
templates_path = []

# List of patterns, relative to source directory, that match files and
# directories to ignore when looking for source files.
# This pattern also affects html_static_path and html_extra_path.
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

# Show warnings for all references where the target could not be found.
nitpicky = True

# Show TODOs in the documentation.
todo_include_todos = True


# -- Options for HTML output -------------------------------------------------

# The theme to use for HTML and HTML Help pages.  See the documentation for
# a list of builtin themes.
#
html_theme = 'sphinx_book_theme'

html_theme_options = {
    "logo": {
        "alt_text": "Tabletop Club Documentation - Home"
    },

    # TODO: Reconsider these links, add instructions for virtual environment.
    "icon_links": [
        {
            "name": "Website",
            "url": "https://tabletopclub.net",
            "icon": "fa-solid fa-house",
            "type": "fontawesome"
        },
        {
            "name": "Ko-fi",
            "url": "https://ko-fi.com/drwhut",
            # TODO: Use brand icon when it becomes available.
            "icon": "fa-solid fa-mug-hot",
            "type": "fontawesome"
        },
        {
            "name": "YouTube",
            "url": "https://www.youtube.com/channel/UCPTl-dLnUOuyKWC7y8005jA",
            "icon": "fa-brands fa-youtube",
            "type": "fontawesome"
        },
        {
            "name": "Twitter",
            "url": "https://twitter.com/drwhutt",
            "icon": "fa-brands fa-x-twitter",
            "type": "fontawesome"
        },
        {
            "name": "Mastodon",
            "url": "https://fosstodon.org/@drwhut",
            "icon": "fa-brands fa-mastodon",
            "type": "fontawesome"
        },
        {
            "name": "Discord",
            "url": "https://discord.gg/GqYkGV4WwX",
            "icon": "fa-brands fa-discord",
            "type": "fontawesome"
        },
        {
            "name": "Matrix",
            "url": "https://matrix.to/#/#tabletop-club:matrix.org",
            "icon": "fa-solid fa-comments",
            "type": "fontawesome"
        }
    ],

    "repository_url": "https://github.com/drwhut/tabletop-club",
    "repository_branch": "master",
    "path_to_docs": "docs/",
    "use_repository_button": True,

    "use_edit_page_button": True,
    "use_issues_button": True,
    "use_source_button": True,

    "show_toc_level": 2
}

# Add the project logo and icon to the docs.
html_logo = "../game/tabletop_club_logo.png"
html_favicon = "../game/tabletop_club_icon.ico"

# Add any paths that contain custom static files (such as style sheets) here,
# relative to this directory. They are copied after the builtin static files,
# so a file named "default.css" will overwrite the builtin "default.css".
html_static_path = []


# -- Options for internationalization ----------------------------------------

locale_dirs = ['translations/']
gettext_compact = True
