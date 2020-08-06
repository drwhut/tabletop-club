# OpenTabletop
An open-source platform for playing tabletop games in a 3D environment, made
with the Godot Engine!

## Compiling

To build the game from source, you'll need to download and compile a slightly
modified version of the Godot Engine - the reason is because the game needs the
ability to import resources like textures at runtime which, firstly, isn't
available in GDScript, and secondly, isn't available outside of the editor.

1. Download the modified version of Godot:

```bash
git clone https://github.com/drwhut/godot.git -b tabletop-3.2.2
cd godot
git submodule update --init
```

2. Compile Godot for your platform (see
[the Godot documentation](https://docs.godotengine.org/en/stable/development/compiling/index.html)
for more information):

```bash
# For the Editor + Debug Export Template, use:
scons -j8 platform=windows/osx/x11/server target=release_debug

# For the Release Export Template, use:
scons -j8 platform=windows/osx/x11/server target=release
```

3. Download the game:

```bash
cd ..
git clone https://github.com/drwhut/open-tabletop.git
cd open-tabletop
```

4. Generate the OpenTabletop assets:

```bash
pip install Pillow
cd assets/OpenTabletop/cards
python generate_cards.py
cd ../chips
python generate_chips.py
```

5. Open the built editor, and import the project at `open-tabletop/game`!

## Contributing

Want to help contribute to the project? Have a look at
[the contributing guide](CONTRIBUTING.md)!
