# OpenTabletop Assets

One of the really cool things about OpenTabletop is that you can create,
modify, and use your own (or someone else's) assets in the game using your
favourite image-editing/3d-modelling/text-editing software, all without having
to edit the game or use Godot!

## Asset Pack Structure

To make the management and sharing of custom assets easier, the assets in this
folder are split up into **packs**. Each pack has a set of assets within it
that are divided into different sub-folders. The game comes with the default
OpenTabletop asset pack included.

### cards/

Cards are flat, rectangular-shaped objects that are stackable, and they have
the unique functionality to be able to be put in a player's hand.

The textures for cards use the following UV mapping:
![Card UV Mapping](OpenTabletop/cards/Template.svg)

### dice/

Dice are objects that, when shaken, randomize their orientation.

#### dice/d4/

The textures for d4 dice use the following UV mapping:
![D4 UV Mapping](OpenTabletop/dice/d4/Template.svg)

#### dice/d6/

The textures for d6 dice use the following UV mapping:
![D6 UV Mapping](OpenTabletop/dice/d6/Template.svg)

#### dice/d8/

The textures for d8 dice use the following UV mapping:
![D8 UV Mapping](OpenTabletop/dice/d8/Template.svg)

### games/

Games are table files that are used to setup the table automatically in order
to start playing a game.

You can create table files by setting up the table the way you want in
singleplayer, then by going to the menu and saving the game into this
directory.

### pieces/

Pieces are generic objects with no special features.

#### pieces/cube/

The textures for cube-shaped pieces use the following UV mapping:
![Cube Piece UV Mapping](OpenTabletop/pieces/cube/Template.svg)

#### pieces/custom/

This subfolder contains custom 3D models, which can be exported from programs
like Blender or Maya.

**NOTE:** Currently, the only accepted formats are glTF 2.0 (.glb, .gltf), and
Wavefront (.obj).

#### pieces/cylinder/

The textures for cylinder-shaped pieces use the following UV mapping:
![Cylinder Piece UV Mapping](OpenTabletop/pieces/cylinder/Template.svg)

### skyboxes/

Skyboxes are special textures that determine what the background looks like.

Skybox textures need to have equirectangular mappings, instead of using cube
mappings. Godot recommends using
[this tool](https://danilw.github.io/GLSL-howto/cubemap_to_panorama_js/cubemap_to_panorama.html)
to convert cube maps to equirectangular maps.

For the best lighting quality, it is recommended to use a HDR panorama.
OpenTabletop supports the Radiance HDR (`.hdr`) and OpenEXR (`.exr`) formats.

Here is an example of a skybox texture:
![Example skybox texture](OpenTabletop/skyboxes/Clouds.png)

### tokens/

Tokens are objects that are stackable.

**NOTE:** Tokens stack vertically, so the top and bottom faces will be
connected end-to-end when they are stacked.

#### tokens/cube

The textures for cube-shaped tokens use the same UV mapping as cube-shaped
pieces (see pieces/cube/).

#### tokens/cylinder

The textures for cylinder-shaped tokens use the same UV mapping as
cylinder-shaped pieces (see pieces/cylinder/).

### config.cfg

Each subfolder has this special file for giving each object it's own
properties.

Here is an example of a `config.cfg` file:

```ini
; The following properties are applied to every object in the subfolder.
[*]

; Setting the description of an object.
desc = "This is an object you can spawn!"

; Setting the mass of an object in grams (g).
mass = 5.0

; Setting the size of an object in centimeters (cm).
scale = Vector3(3.5, 0.5, 5.0)

; The following properties apply only to objects whose name start with
; "Heavy". These properties take precedence over the properties under [*].
[Heavy*]

; Descriptions can be on multiple lines.
desc = "This is one line,

and this is another!"

; This is equivalent to 100g.
mass = 100.0

; The following properties apply only to the given object.
[Temporary.png]

; You can tell the game to not import certain objects.
ignore = true
```

### stacks.cfg

If a subfolder is used for objects that are stackable, you can use this special
file to add pre-filled stacks of those objects to the game. A good example of
this is for adding decks of cards to the game.

Here is an example of a `stacks.cfg` file:

```ini
; This is the name of the stack.
[My Stack]

; You can also give stacks descriptions.
desc = "This is my stack. It's awesome!"

; You then specify which objects are in the stack.
; Note that all of the objects need to be the same size.
items = [
    "Card 1.png",
    "Card 2.png",
    "Card 3.png"
]

; This is the name of another stack.
[My Friends Stack]

desc = "My friend's stack isn't as good as my stack!"

; It doesn't matter if each object is on a new line.
items = ["Trading Card 1.jpg", "Trading Card 2.jpg"]
```
