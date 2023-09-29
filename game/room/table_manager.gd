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

class_name TableManager
extends Spatial

## Used to manage the table object in the centre of the room.


## The table to use when the game starts, in entry form.
## TODO: Make typed in 4.x.
export(Resource) var default_table = null

# The root node of the current table object.
# TODO: Change to a custom class.
var _table_node: RigidBody = null


func _ready():
	if default_table is AssetEntryTable:
		set_table(default_table)
	else:
		push_error("'default_table' is not of type AssetEntryTable")


## Set the table to use with its asset entry.
func set_table(table_entry: AssetEntryTable) -> void:
	if _table_node != null:
		_table_node.queue_free()
	
	var builder := PieceBuilder.new()
	_table_node = builder.build_table(table_entry)
	if _table_node == null:
		return
	
	add_child(_table_node)
