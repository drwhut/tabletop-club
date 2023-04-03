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

class_name TemplateTextbox
extends Resource

## Metadata for a notebook textbox.
##
## Image-based notebook pages contain these textboxes, which the player can then
## type into. See [AssetEntryTemplateImage] for more information.


## The minimum width of a textbox.
const MIN_WIDTH := 10.0

## The minimum height of a textbox.
const MIN_HEIGHT := 10.0


## The position and size of the textbox, relative to the image.
export(Rect2) var rect := Rect2(0.0, 0.0, MIN_WIDTH, MIN_HEIGHT) setget set_rect

## The rotation of the textbox around it's top-left corner in degrees.
export(float) var rotation := 0.0 setget set_rotation

## The number of lines of text shown in the textbox. Note that there is a
## maximum allowed value based on [method get_max_lines], so you should probably
## set [member rect] first before setting this value.
export(int) var lines := 1 setget set_lines

## The starting text in the textbox.
export(String) var text := ""


## Get the maximum number of allowed lines of text that can be shown based on
## the textbox's current size.
func get_max_lines() -> int:
	return int(floor(rect.size.y / MIN_HEIGHT))


func set_lines(value: int) -> void:
	if value < 1:
		value = 1
	
	var max_lines := get_max_lines()
	if value > max_lines:
		value = max_lines
	
	lines = value


func set_rect(value: Rect2) -> void:
	if not SanityCheck.is_valid_rect2(value):
		return
	
	value.position.x = max(0.0, value.position.x)
	value.position.y = max(0.0, value.position.y)
	value.size.x = max(MIN_WIDTH, value.size.x)
	value.size.y = max(MIN_HEIGHT, value.size.y)
	
	rect = value
	
	# Changing the size may also change the maximum number of allowed lines.
	var max_lines := get_max_lines()
	if lines > max_lines:
		lines = max_lines


func set_rotation(value: float) -> void:
	if not SanityCheck.is_valid_float(value):
		return
	
	rotation = value
