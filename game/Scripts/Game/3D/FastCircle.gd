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

extends Spatial

const ROTATE_SPEED = 0.25

var _fade_offset: float = 0.0

var _inner_material: SpatialMaterial
var _outer_material: SpatialMaterial

# Restart the fade-in animation.
func restart() -> void:
	set_process(true)
	_fade_offset = 0.0
	visible = true
	
	Engine.time_scale = 2.0
	
	$AudioStreamPlayer.play()

func _ready():
	_inner_material = $InnerCircle.get_surface_material(0)
	_outer_material = $OuterCircle.get_surface_material(0)

func _process(delta):
	rotate_y(ROTATE_SPEED * delta)
	
	if _fade_offset < 1.0:
		_set_alpha(_fade_offset)
	elif _fade_offset > 19.0:
		if _fade_offset > 20.0:
			set_process(false)
			visible = false
			
			Engine.time_scale = 1.0
		else:
			_set_alpha(20.0 - _fade_offset)
	else:
		_set_alpha(1.0)
	
	_fade_offset += 0.5 * delta

# Set the alpha transparency of the circle.
# alpha: The transparency value.
func _set_alpha(alpha: float) -> void:
	_inner_material.albedo_color.a = alpha
	_outer_material.albedo_color.a = alpha

func _on_FastCircle_tree_exiting():
	Engine.time_scale = 1.0
