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

extends TextureRect

class_name PlayerCursor

const LERP_SCALE = 100.0

var lerp_position: Vector2

# Set the texture based on a player's Lobby properties.
# id: The ID of the player the cursor represents.
func set_player_cursor_texture(id: int) -> void:
	var cursor_image: Image = preload("res://Cursors/Arrow.png")
	
	# Create a clone of the image, so we don't modify the original.
	var clone_image = Image.new()
	cursor_image.lock()
	clone_image.create_from_data(cursor_image.get_width(),
		cursor_image.get_height(), false, cursor_image.get_format(),
		cursor_image.get_data())
	cursor_image.unlock()
	
	# Get the player's color.
	var mask_color = Color.white
	if Lobby.player_exists(id):
		var player = Lobby.get_player(id)
		if player.has("color"):
			mask_color = player["color"]
			mask_color.a = 1.0
	
	# Perform a multiply operation on the image.
	clone_image.lock()
	for x in range(clone_image.get_width()):
		for y in range(clone_image.get_height()):
			var pixel = clone_image.get_pixel(x, y)
			clone_image.set_pixel(x, y, pixel * mask_color)
	clone_image.unlock()
	
	var new_texture = ImageTexture.new()
	new_texture.create_from_image(clone_image)
	
	texture = new_texture

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta):
	rect_position = rect_position.linear_interpolate(lerp_position, LERP_SCALE * delta)
