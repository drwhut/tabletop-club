#!/bin/bash

# Install the Python packages.
python3 -m pip install -r requirements.txt

# Extract the .pot file.
pybabel extract -F babelrc.txt -k text -k LineEdit/placeholder_text -k tr \
    -k load_button_text -k status_text_one -k status_text_multiple -k hint_tooltip \
    -k window_title -o godot-l10n.pot ..
