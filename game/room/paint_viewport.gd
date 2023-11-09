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

extends Viewport

## The internal viewport used by the paint plane to allow players to paint on
## the table.


onready var _image_overwrite := $ImageOverwrite


func _process(_delta: float):
	# Disable all canvas elements so that nothing new is drawn this frame,
	# unless we get a command that says otherwise.
	_image_overwrite.texture = null
	_image_overwrite.visible = false


func set_image(image: Image) -> void:
	# TODO: Ensure no paint is drawn inbetween the viewport being cleared and
	# the new image being displayed.
	
	var viewport_w := int(size.x)
	var viewport_h := int(size.y)
	if image.get_width() != viewport_w or image.get_height() != viewport_h:
		push_error("Image size (%dx%d) does not match viewport size (%dx%d)" %
				[image.get_width(), image.get_height(), viewport_w, viewport_h])
		return
	
	var texture := ImageTexture.new()
	texture.create_from_image(image, 0) # Disable filtering and mipmaps.
	_image_overwrite.texture = texture
	_image_overwrite.visible = true
	
	# Usually the viewport does not clear, but we will need it to in the event
	# that there is transparency in the image.
	render_target_clear_mode = Viewport.CLEAR_MODE_ONLY_NEXT_FRAME
