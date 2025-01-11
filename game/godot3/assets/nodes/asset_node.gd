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

class_name AssetNode
extends Reference

## A node within the asset tree.
##
## This acts as an asset directory, which can contain other directories, as well
## as a list of [AssetEntry] which are analogous to files.


## The ID of the node.
##
## This is used as part of the tree's path to reference this node.
var id := ""


## The list of [AssetEntry] this node contains.
## TODO: Make typed in 4.x.
##
## [b]NOTE:[/b] For optimisation purposes, this array may be a direct reference
## to an array in the AssetDB. Therefore, this array should NOT be modified
## directly. Instead, duplicate the array if you wish to e.g. sort it.
var entry_list: Array = []


# The node's children, where the keys are the IDs, and the values are the nodes.
var _children := {}


func _init(new_id: String):
	self.id = new_id


## Add another node to be this node's child.
##
## An error occurs if the ID already exists as a child.
func add_child(child: AssetNode) -> void:
	if _children.has(child.id):
		push_error("Child with ID '%s' already exists for node '%s'" % [child.id, id])
		return
	
	_children[child.id] = child


## Get the [AssetNode] for the child with the given ID.
##
## [code]null[/code] is returned if the child does not exist.
func get_child(child_id: String) -> AssetNode:
	return _children.get(child_id, null)


## Get the number of children this node contains.
func get_child_count() -> int:
	return _children.size()


## Get all children of this node as a list of [AssetNode].
## TODO: Make typed in 4.x.
func get_children() -> Array:
	return _children.values()


## Check if a child with the given ID exists for this node.
func has_child(child_id: String) -> bool:
	return _children.has(child_id)


## Remove one of this node's children.
##
## An error occurs if the ID does not exist as a child.
func remove_child(child_id: String) -> void:
	if not _children.erase(child_id):
		push_error("Child with ID '%s' does not exist for node '%s'" % [child_id, id])
