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

class_name ControllerRichTextLabel
extends RichTextLabel

## A [RichTextLabel] that can be scrolled with the right analog stick.


## How fast the label should scroll when the analog stick is moved.
const ANALOG_STICK_SCROLL_SCALAR := 300.0

## The dead zone the axis needs to hit before we start scrolling.
const ANALOG_STICK_DEADZONE := 0.5

## The minimum scroll amount per frame for a [RichTextLabel].
const MIN_SCROLL_PER_FRAME := 1.0
 

# The last recorded axis value for the controller stick.
var _last_axis_value := 0.0


func _init():
	connect("visibility_changed", self, "_on_visibility_changed")


func _process(delta: float):
	# Don't need is_zero_approx here, since it will never be near-zero.
	if _last_axis_value == 0.0:
		return
	
	if not has_focus():
		return
	
	var scroll := ANALOG_STICK_SCROLL_SCALAR * delta * _last_axis_value
	if abs(scroll) < MIN_SCROLL_PER_FRAME:
		if scroll > 0.0:
			scroll = MIN_SCROLL_PER_FRAME
		else:
			scroll = -MIN_SCROLL_PER_FRAME
	get_v_scroll().value += scroll


func _input(event: InputEvent):
	if not visible:
		return
	
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_3: # Right analog stick, up/down.
			_last_axis_value = event.axis_value
			
			if abs(_last_axis_value) > ANALOG_STICK_DEADZONE:
				get_tree().set_input_as_handled()
			else:
				_last_axis_value = 0.0


func _on_visibility_changed() -> void:
	# Reset the recorded axis value if the label is either being shown for the
	# first time, or if it has just been hidden.
	_last_axis_value = 0.0
