# open-tabletop
# Copyright (c) 2020 drwhut
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

extends TextureRect

class_name CardTextureRect

signal clicked_on(card_texture)
signal mouse_over(card_texture, is_over)

var card: Card = null
var front_face: bool = true

var _mouse_over: bool = false
var _sent_mouse_over_signal_true = false
var _sent_mouse_over_signal_false = false

func _draw():
	if not texture:
		return
	
	var src_rect = Rect2(0, 0, texture.get_width() / 2, texture.get_height())
	if not front_face:
		src_rect.position.x += texture.get_width()
	
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, rect_size), src_rect)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.is_pressed() and _mouse_over:
				emit_signal("clicked_on", self)
	
	# Would usually use the signals for this, but we also need to know if the
	# mouse is over the card while holding down the LMB.
	elif event is InputEventMouseMotion:
		var rect = Rect2(rect_global_position, rect_size)
		_mouse_over = rect.has_point(get_viewport().get_mouse_position())
		
		if _mouse_over:
			if not _sent_mouse_over_signal_true:
				emit_signal("mouse_over", self, true)
				_sent_mouse_over_signal_true = true
		else:
			_sent_mouse_over_signal_true = false
		
		if not _mouse_over:
			if not _sent_mouse_over_signal_false:
				emit_signal("mouse_over", self, false)
				_sent_mouse_over_signal_false = true
		else:
			_sent_mouse_over_signal_false = false
