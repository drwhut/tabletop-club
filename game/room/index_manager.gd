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

class_name IndexManager
extends Node

## Manage a list of nodes with unique indices assigned to them.
##
## By default, when getting a specific child of a node in Godot, it will scan
## through its list of children linearly until it finds a node with the given
## name.
##
## This class optimises that process by placing all of the child nodes in one
## big array, where its position in the array matches the index it has been
## assigned. That way, if the requested index is known, the node can be gotten
## almost instantly.
##
## TODO: Child management is much improved in Godot 4.x, consider removing this
## class once the migration has happened - maybe benchmark both systems?


# The indexed list of child nodes.
var _child_arr := []

# The index that the first element of the array points to.
var _arr_offset := 0

# The number of children currently being referenced in the array.
var _num_children_in_arr := 0


## Add a child to this node under the given index - the node will automatically
## be renamed. If a node already exists with that index, an error is thrown.
func add_child_with_index(index: int, node: Node) -> void:
	# Ideally this should never happen, but we'll account for it just in case.
	if index < _arr_offset:
		var prefix := []
		prefix.resize(_arr_offset - index)
		_child_arr = prefix + _child_arr
		_arr_offset = index
	
	elif index >= _arr_offset + _child_arr.size():
		_child_arr.resize(index - _arr_offset + 1)
	
	else:
		var current = _child_arr[index - _arr_offset]
		if current != null:
			push_error("Cannot add node with index '%d', already exists" % index)
			return
	
	node.name = str(index)
	add_child(node)
	
	_child_arr[index - _arr_offset] = node
	_num_children_in_arr += 1


## Return the child node with the given index. If it does not exist,
## [code]null[/code] is returned.
func get_child_with_index(index: int) -> Node:
	if index < _arr_offset:
		return null
	
	if index >= _arr_offset + _child_arr.size():
		return null
	
	return _child_arr[index - _arr_offset]


## Get the next index along that is guaranteed to be available.
func get_next_index() -> int:
	return _arr_offset + _child_arr.size()


## Check if a node with the given index exists.
func has_child_with_index(index: int) -> bool:
	return get_child_with_index(index) != null


## Remove the child node with the given index. This will queue the node for
## deletion. If it does not exist, an error is thrown.
func remove_child_with_index(index: int) -> void:
	var node_to_remove := get_child_with_index(index)
	if node_to_remove == null:
		push_error("Cannot remove node with index '%s', does not exist" % index)
		return
	
	_child_arr[index - _arr_offset] = null
	node_to_remove.queue_free()
	
	_num_children_in_arr -= 1
	if _num_children_in_arr <= 0:
		_arr_offset += _child_arr.size()
		_child_arr.clear()


## Queue all child nodes for deletion.
func remove_all_children() -> void:
	for child in get_children():
		child.queue_free()
	
	_arr_offset += _child_arr.size()
	_child_arr.clear()


## Get the number of elements in the internal index array. This function is
## mainly used for testing purposes.
func get_capacity() -> int:
	return _child_arr.size()
