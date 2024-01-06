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

extends GutTest

## Test the [IndexManager] class.


func test_index_manager() -> void:
	var index_manager: IndexManager = autofree(IndexManager.new())
	
	var node_a: Node = autofree(Node.new())
	var node_b: Node = autofree(Node.new())
	var node_c: Node = autofree(Node.new())
	var node_d: Node = autofree(Node.new())
	var node_e: Node = autofree(Node.new())
	
	assert_eq(index_manager.get_capacity(), 0)
	assert_eq(index_manager.get_next_index(), 0)
	
	index_manager.add_child_with_index(0, node_a)
	assert_eq(index_manager.get_child_with_index(0), node_a)
	assert_true(index_manager.has_child_with_index(0))
	assert_eq(index_manager.get_capacity(), 1)
	assert_eq(index_manager.get_next_index(), 1)
	
	assert_true(index_manager.is_a_parent_of(node_a))
	assert_eq(node_a.name, "0")
	
	assert_false(index_manager.has_child_with_index(1))
	assert_false(index_manager.has_child_with_index(5))
	assert_false(index_manager.has_child_with_index(-10))
	assert_false(index_manager.has_child_with_index(2))
	
	index_manager.add_child_with_index(1, node_b)
	assert_eq(index_manager.get_child_with_index(1), node_b)
	assert_true(index_manager.has_child_with_index(1))
	assert_eq(index_manager.get_capacity(), 2)
	assert_eq(index_manager.get_next_index(), 2)
	
	assert_true(index_manager.is_a_parent_of(node_b))
	assert_eq(node_b.name, "1")
	
	index_manager.add_child_with_index(5, node_c)
	assert_eq(index_manager.get_child_with_index(5), node_c)
	assert_true(index_manager.has_child_with_index(5))
	assert_eq(index_manager.get_capacity(), 6)
	assert_eq(index_manager.get_next_index(), 6)
	
	index_manager.add_child_with_index(-10, node_d)
	assert_eq(index_manager.get_child_with_index(-10), node_d)
	assert_true(index_manager.has_child_with_index(-10))
	assert_eq(index_manager.get_capacity(), 16)
	assert_eq(index_manager.get_next_index(), 6)
	
	index_manager.add_child_with_index(2, node_e)
	assert_eq(index_manager.get_child_with_index(0), node_a)
	assert_eq(index_manager.get_child_with_index(1), node_b)
	assert_eq(index_manager.get_child_with_index(5), node_c)
	assert_eq(index_manager.get_child_with_index(-10), node_d)
	assert_eq(index_manager.get_child_with_index(2), node_e)
	
	# Capacity should not change, as the new node is in the middle of the array.
	assert_eq(index_manager.get_capacity(), 16)
	
	# The next recommended index should not change either.
	assert_eq(index_manager.get_next_index(), 6)
	
	# Cannot add a node with an index that already exists.
	var invalid_node: Node = autofree(Node.new())
	index_manager.add_child_with_index(2, invalid_node)
	assert_eq(index_manager.get_child_with_index(2), node_e)
	assert_true(index_manager.is_a_parent_of(node_e))
	
	index_manager.remove_child_with_index(-10)
	assert_false(index_manager.has_child_with_index(-10))
	assert_true(node_d.is_queued_for_deletion())
	assert_eq(index_manager.get_capacity(), 16)
	assert_eq(index_manager.get_next_index(), 6)
	
	index_manager.remove_child_with_index(2)
	assert_eq(index_manager.get_child_with_index(2), null)
	assert_true(node_e.is_queued_for_deletion())
	assert_eq(index_manager.get_capacity(), 16)
	assert_eq(index_manager.get_next_index(), 6)
	
	index_manager.remove_child_with_index(1)
	assert_false(index_manager.has_child_with_index(1))
	assert_true(node_b.is_queued_for_deletion())
	assert_eq(index_manager.get_capacity(), 16)
	assert_eq(index_manager.get_next_index(), 6)
	
	index_manager.remove_child_with_index(5)
	assert_eq(index_manager.get_child_with_index(5), null)
	assert_true(node_c.is_queued_for_deletion())
	assert_eq(index_manager.get_capacity(), 16)
	assert_eq(index_manager.get_next_index(), 6)
	
	index_manager.remove_child_with_index(0)
	assert_eq(index_manager.get_child_with_index(0), null)
	assert_true(node_a.is_queued_for_deletion())
	
	# Only when the last living node is removed, is the array cleared.
	assert_eq(index_manager.get_capacity(), 0)
	
	# The next recommended index stays as is, however.
	assert_eq(index_manager.get_next_index(), 6)
	
	# The array offset shouldn't reset back to 0, instead, it should start where
	# the old array left off.
	var node_f: Node = autofree(Node.new())
	index_manager.add_child_with_index(6, node_f)
	assert_eq(index_manager.get_child_with_index(6), node_f)
	assert_true(index_manager.has_child_with_index(6))
	assert_eq(index_manager.get_capacity(), 1)
	assert_eq(index_manager.get_next_index(), 7)
	
	assert_true(index_manager.is_a_parent_of(node_f))
	assert_eq(node_f.name, "6")
	
	var node_g: Node = autofree(Node.new())
	index_manager.add_child_with_index(7, node_g)
	assert_eq(index_manager.get_child_with_index(7), node_g)
	assert_true(index_manager.has_child_with_index(7))
	assert_eq(index_manager.get_capacity(), 2)
	assert_eq(index_manager.get_next_index(), 8)
	
	assert_true(index_manager.is_a_parent_of(node_g))
	assert_eq(node_g.name, "7")
	
	index_manager.remove_all_children()
	assert_false(index_manager.has_child_with_index(6))
	assert_false(index_manager.has_child_with_index(7))
	assert_true(node_f.is_queued_for_deletion())
	assert_true(node_g.is_queued_for_deletion())
	assert_eq(index_manager.get_capacity(), 0)
	assert_eq(index_manager.get_next_index(), 8)
