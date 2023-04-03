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

class_name AssetEntryScene
extends AssetEntrySingle

## Contains metadata needed to build a scene from custom assets.
##
## This is the base class from which to build in-game physics objects, for
## example, [Piece].


## Define the type of collision shape that is created for a scene.
enum CollisionType {
	COLLISION_NONE,         ## Do not create a new collision shape.
	COLLISION_CONVEX,       ## A single convex collision shape.
	COLLISION_MULTI_CONVEX, ## Multiple convex collision shapes.
	COLLISION_CONCAVE,      ## A single concave collision shape.
	COLLISION_MAX,          ## Used for validation only.
}

## Configure how the centre-of-mass (COM) of the scene is adjusted.
enum ComAdjust {
	COM_ADJUST_OFF,      ## Do not adjust the COM.
	COM_ADJUST_VOLUME,   ## Use the centre of the bounding box.
	COM_ADJUST_GEOMETRY, ## Use the average point of all vertices.
	COM_ADJUST_MAX,      ## Used for validation only.
}


## A path to a [PackedScene] from which to base the scene from.
export(String, FILE, "*.gltf,*.obj,*.scn,*.tscn") var scene_path := "" \
		setget set_scene_path

## A list of paths to textures that will be used when building the scene.
## TODO: Use typed arrays in 4.x
export(Array, String, FILE, "*.bmp,*.jpeg,*.jpg,*.png,*.svg") \
		var texture_overrides := [] setget set_texture_overrides

## Set a custom albedo color for the scene's material. Transparency is not
## supported.
export(Color) var albedo_color := Color.white setget set_albedo_color

## The mass of the scene's object in grams (g).
export(float) var mass := 1.0 setget set_mass

## Used to scale the scene. Note that other properties like [member avg_point]
## should already take this scale into account for simplicity.
export(Vector3) var scale := Vector3.ONE setget set_scale

## The average of all of the vertices in the scene. Can potentially be used
## when adjusting the centre-of-mass.
export(Vector3) var avg_point := Vector3.ZERO setget set_avg_point

## The axis-aligned bounding box of the scene.
export(AABB) var bounding_box := AABB() setget set_bounding_box

## The type of collision shape the scene will use. See [enum CollisionType] for
## possible values.
export(CollisionType) var collision_type := CollisionType.COLLISION_NONE \
		setget set_collision_type

## Defines how the centre-of-mass (COM) of the scene is adjusted. See
## [enum ComAdjust] for possible values.
export(ComAdjust) var com_adjust := ComAdjust.COM_ADJUST_OFF setget set_com_adjust

## The material to use for the scene, which defines certain physics properties.
export(PhysicsMaterial) var physics_material: PhysicsMaterial \
		= preload("res://assets/default_physics_material.tres") \
		setget set_physics_material

## The list of sounds to use when a fast collision occurs.
## TODO: export(RandomAudioStream), make typed in 4.x
export(Resource) var collision_fast_sounds = AudioStreamList.new() \
		setget set_collision_fast_sounds

## The list of sounds to use when a slow collision occurs.
## TODO: export(RandomAudioStream), make typed in 4.x
export(Resource) var collision_slow_sounds = AudioStreamList.new() \
		setget set_collision_slow_sounds


## Load the [PackedScene] at [member scene_path], or [code]null[/code] if there
## is no scene at that location.
func load_scene() -> PackedScene:
	if scene_path.empty():
		return null
	
	return load(scene_path) as PackedScene


## Load an array of [ImageTexture] from the list of paths in
## [member texture_overrides]. If a texture was not found in a given path, or
## it failed to load, [code]null[/code] is used instead.
## TODO: Return a typed array in 4.x
func load_texture_overrides() -> Array:
	var texture_array := []
	for texture_path in texture_overrides:
		var texture: ImageTexture = null
		if not texture_path.empty():
			texture = load(texture_path) as ImageTexture
		texture_array.push_back(texture)
	return texture_array


func set_albedo_color(value: Color) -> void:
	value.a = 1.0
	albedo_color = value


func set_avg_point(value: Vector3) -> void:
	if not SanityCheck.is_valid_vector3(value):
		return
	
	avg_point = value


func set_bounding_box(value: AABB) -> void:
	if not SanityCheck.is_valid_aabb(value):
		return
	
	bounding_box = value.abs()


func set_collision_fast_sounds(value: AudioStreamList) -> void:
	collision_fast_sounds = value


func set_collision_slow_sounds(value: AudioStreamList) -> void:
	collision_slow_sounds = value


func set_collision_type(value: int) -> void:
	if value < 0 or value >= CollisionType.COLLISION_MAX:
		push_error("Invalid value for CollisionType")
		return
	
	collision_type = value


func set_com_adjust(value: int) -> void:
	if value < 0 or value >= ComAdjust.COM_ADJUST_MAX:
		push_error("Invalid value for ComAdjust")
		return
	
	com_adjust = value


func set_mass(value: float) -> void:
	mass = max(0.0, value)


func set_physics_material(value: PhysicsMaterial) -> void:
	if not SanityCheck.is_valid_float(value.friction):
		return
	
	if not SanityCheck.is_valid_float(value.bounce):
		return
	
	physics_material = value


func set_scale(value: Vector3) -> void:
	if not SanityCheck.is_valid_vector3(value):
		return
	
	scale = value


func set_scene_path(value: String) -> void:
	if not SanityCheck.is_valid_res_path(value, SanityCheck.VALID_EXTENSIONS_SCENE):
		return
	
	scene_path = value.simplify_path()


func set_texture_overrides(value: Array) -> void:
	for subvalue in value:
		if not subvalue is String:
			push_error("Value in array is not a String")
			return
		
		if not SanityCheck.is_valid_res_path(subvalue,
				SanityCheck.VALID_EXTENSIONS_TEXTURE):
			return
	
	texture_overrides = value
