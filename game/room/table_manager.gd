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

class_name TableManager
extends Spatial

## Used to manage the table object in the centre of the room.


## The table to use when the game starts, in entry form.
## TODO: Make typed in 4.x.
export(Resource) var default_table = null

## The current transform of the table.
var table_transform := Transform.IDENTITY setget set_table_transform, \
		get_table_transform

# The root node of the current table object.
# TODO: Change to a custom class.
var _table_node: RigidBody = null

# The paint plane situated just above the surface of the table.
var _paint_plane := PaintPlane.new()

# Used to keep track of the last [AssetEntryTable] used to set the table.
var _last_table_entry: AssetEntryTable = null


func _ready():
	if default_table is AssetEntryTable:
		set_table(default_table)
	else:
		push_error("'default_table' is not of type AssetEntryTable")


## Get the paint plane sitting on top of the table. If it is currently not in
## the scene tree, return [code]null[/code].
func get_paint_plane() -> PaintPlane:
	if not _paint_plane.is_inside_tree():
		return null
	
	return _paint_plane


## Get the current table as an [AssetEntryTable].
## [b]NOTE:[/b] If [member default_table] is not set correctly, then this may
## return [code]null[/code].
func get_table() -> AssetEntryTable:
	return _last_table_entry


## Set the table to use with its asset entry.
func set_table(table_entry: AssetEntryTable) -> void:
	# TODO: Check if the table is already in the scene.
	
	if _table_node != null:
		_table_node.remove_child(_paint_plane)
		_table_node.queue_free()
	
	var builder := ObjectBuilder.new()
	_table_node = builder.build_table(table_entry)
	if _table_node == null:
		return
	
	_last_table_entry = table_entry
	
	_paint_plane.transform = table_entry.paint_plane_transform
	_table_node.add_child(_paint_plane)
	add_child(_table_node)
	
	# The table needs to be translated down since its centre-of-mass will be
	# shifted, so make sure the plane sits just on top of the y=0 plane no
	# matter what size the table is.
	_paint_plane.global_transform.origin.y = 0.01
	_paint_plane.reset_physics_interpolation()


func get_table_transform() -> Transform:
	if _table_node == null:
		return Transform.IDENTITY
	
	return _table_node.transform


func set_table_transform(value: Transform) -> void:
	if _table_node == null:
		push_error("Cannot set table transform, table node does not exist")
		return
	
	_table_node.transform = value
	_table_node.reset_physics_interpolation()
