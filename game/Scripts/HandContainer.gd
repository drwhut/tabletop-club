# open-tabletop
# Copyright (c) 2020 Benjamin 'drwhut' Beddows
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

extends Container

func _notification(what):
	if what == NOTIFICATION_SORT_CHILDREN:
		
		if get_child_count() == 0:
			return
		
		var total_width = 0
		
		for child in get_children():
			if child is Control:
				total_width += child.rect_size.x
		
		var offset_begin = max((rect_size.x - total_width) / 2, 0)
		var offset_other = 0
		if get_child_count() > 1:
			offset_other = min(-(total_width - rect_size.x) / (get_child_count() - 1), 0)
		
		var cumulative_width = 0
		var first_child = get_child(0)
		
		if first_child is Control:
			cumulative_width = floor(first_child.rect_size.x)
			first_child.rect_position.x = floor(offset_begin)
		
		for i in range(1, get_child_count()):
			var child = get_child(i)
			if child is Control:
				var width = child.rect_size.x
				child.rect_position.x = floor(offset_begin + cumulative_width + offset_other)
				cumulative_width += floor(width + offset_other)
