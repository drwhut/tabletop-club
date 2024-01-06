# tabletop-club
# Copyright (c) 2020-2024 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2024 Tabletop Club contributors (see game/CREDITS.tres).
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

class_name AssetEntrySkybox
extends AssetEntrySingle

## An entry representing a skybox.
##
## This entry will be used to set the environment around the room.


## A path to an [ImageTexture] which represents the skybox.
export(String, FILE, "*.exr,*.hdr,*.png,*.jpeg,*.jpg") var texture_path := "" \
		setget set_texture_path

## Defines how bright the skybox is.
export(float) var energy := 1.0 setget set_energy

## Defines how the skybox should be rotated in radians.
export(Vector3) var rotation := Vector3.ZERO setget set_rotation


## Load the skybox texture at [member texture_path], or [code]null[/code] if a
## texture does not exist at that location.
func load_skybox_texture() -> Texture:
	if texture_path.empty():
		return null
	
	return load(texture_path) as Texture


func set_energy(value: float) -> void:
	if not SanityCheck.is_valid_float(value):
		return
	
	energy = max(0.0, value)


func set_rotation(value: Vector3) -> void:
	if not SanityCheck.is_valid_vector3(value):
		return
	
	rotation = value


func set_texture_path(value: String) -> void:
	if not SanityCheck.is_valid_res_path(value, SanityCheck.VALID_EXTENSIONS_TEXTURE):
		return
	
	texture_path = value.simplify_path()
