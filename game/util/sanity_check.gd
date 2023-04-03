# tabletop-club
# Copyright (c) 2020-2023 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2023 Tabletop Club contributors (see game/CREDITS.tres).
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

class_name SanityCheck
extends Reference

## Provides various sanity checks for the project.
##
## Note that if a check fails in any of the functions in this class, then an
## error is thrown.


## A list of valid extensions for audio resources.
const VALID_EXTENSIONS_AUDIO: Array = ["mp3", "ogg", "wav"]

## A list of valid extensions for save files.
const VALID_EXTENSIONS_SAVE: Array = ["tc"]

## A list of valid extensions for scene resources that are imported by the user.
const VALID_EXTENSIONS_SCENE_USER: Array = ["dae", "glb", "gltf", "obj"]

## A list of valid extensions for scene resources from both the user and from
## the res:// directory.
const VALID_EXTENSIONS_SCENE: Array = ["scn", "tscn"] + VALID_EXTENSIONS_SCENE_USER

## A list of valid extensions for texture resources.
## See: https://docs.godotengine.org/en/3.5/tutorials/assets_pipeline/importing_images.html
const VALID_EXTENSIONS_TEXTURE: Array = ["bmp", "dds", "exr", "hdr", "jpeg",
		"jpg", "png", "tga", "svg", "svgz", "webp"]

## A list of valid extensions for text-based templates.
const VALID_EXTENSIONS_TEMPLATE_TEXT: Array = ["txt"]

## A list of valid extensions for image-based templates.
const VALID_EXTENSIONS_TEMPLATE_IMAGE: Array = VALID_EXTENSIONS_TEXTURE


## Check if [code]value[/code] is a valid AABB.
static func is_valid_aabb(value: AABB) -> bool:
	return is_valid_vector3(value.position) and is_valid_vector3(value.size)


## Check if [code]value[/code] is a valid floating-point number.
static func is_valid_float(value: float) -> bool:
	if is_inf(value):
		push_error("INF is an invalid float value")
		return false
	
	if is_nan(value):
		push_error("NAN is an invalid float value")
		return false
	
	return true


## Check if [code]value[/code] is a valid Rect2.
static func is_valid_rect2(value: Rect2) -> bool:
	return is_valid_vector2(value.position) and is_valid_vector2(value.size)


## Check if [code]path[/code] is a valid absolute path to a resource file.
## The file extension must be in [code]valid_ext[/code].
static func is_valid_res_path(path: String, valid_ext: Array) -> bool:
	if not path.is_abs_path():
		push_error("Path is not absolute")
		return false
	
	if path.begins_with("res://assets"):
		if not ResourceLoader.exists(path):
			push_error("Resource at '%s' does not exist" % path)
			return false
	elif path.begins_with("user://assets"):
		var file = File.new()
		if not file.file_exists(path):
			push_error("File at '%s' does not exist" % path)
			return false
	else:
		push_error("Path must begin with 'res://assets' or 'user://assets'")
		return false
	
	if not path.get_extension() in valid_ext:
		push_error("Path contains an invalid extension")
		return false
	
	if ".." in path:
		push_error("Path cannot contain '..'")
		return false
	
	return true


## Check if the components of [code]value[/code] are all valid floating point
## numbers.
static func is_valid_vector2(value: Vector2) -> bool:
	return is_valid_float(value.x) and is_valid_float(value.y)


## Check if the components of [code]value[/code] are all valid floating point
## numbers.
static func is_valid_vector3(value: Vector3) -> bool:
	return is_valid_float(value.x) and is_valid_float(value.y) and \
			is_valid_float(value.z)
