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

class_name PieceBuilder
extends Reference

## Used to build piece and table objects from their respective asset entries.
##
## TODO: Test this class once it is complete.


## Build a table object from its given entry.
## TODO: Switch to custom class instead of RigidBody.
func build_table(table_entry: AssetEntryTable) -> RigidBody:
	var scene := table_entry.load_scene()
	if scene == null:
		# TODO: Maybe instead of returning null, use an "error" object?
		push_error("Failed to load scene for table '%s'" % table_entry.get_path())
		return null
	
	var instance := scene.instance()
	var table: RigidBody = null
	
	if instance is RigidBody:
		table = instance
	else:
		# TODO: Make table objects from custom scenes.
		pass
	
	table.mass = 100000 # = 10kg
	table.mode = RigidBody.MODE_STATIC
	table.physics_material_override = table_entry.physics_material
	
	# TODO: Should we adjust the centre of mass for tables?
	
	return table
