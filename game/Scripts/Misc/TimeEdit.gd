# tabletop-club
# Copyright (c) 2020-2025 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2025 Tabletop Club contributors (see game/CREDITS.tres).
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

extends HBoxContainer

class_name TimeEdit

var hour: SpinBox = null
var minute: SpinBox = null
var second: SpinBox = null

# Get the number of seconds this TimeEdit currently represents.
# Returns: The current time in seconds.
func get_seconds() -> float:
	return 3600 * hour.value + 60 * minute.value + second.value

func _init():
	hour = SpinBox.new()
	hour.align = LineEdit.ALIGN_CENTER
	hour.max_value = 99
	hour.min_value = 0
	hour.step = 1
	add_child(hour)
	
	var colon_label1 = Label.new()
	colon_label1.text = ":"
	add_child(colon_label1)
	
	minute = SpinBox.new()
	minute.align = LineEdit.ALIGN_CENTER
	minute.max_value = 59
	minute.min_value = 0
	minute.step = 1
	add_child(minute)
	
	var colon_label2 = Label.new()
	colon_label2.text = ":"
	add_child(colon_label2)
	
	second = SpinBox.new()
	second.align = LineEdit.ALIGN_CENTER
	second.max_value = 59
	second.min_value = 0
	second.step = 1
	add_child(second)
	
	# Set the default time to five minutes.
	hour.value = 0
	minute.value = 5
	second.value = 0
