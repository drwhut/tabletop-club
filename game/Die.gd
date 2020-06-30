# OpenTabletop
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

extends Piece

class_name Die

onready var _meshInstance = $MeshInstance

var _rng = RandomNumberGenerator.new()

func apply_texture(texture: Texture):
	_meshInstance.get_surface_material(0).albedo_texture = texture

func _ready():
	_rng.randomize()

func _physics_process(delta):
	
	# If the dice is being shaked, set the up and forward directions randomly,
	# as if one were actually shaking a die.
	if is_being_shaked():
		
		var vec_list = [Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN,
			Vector3.FORWARD, Vector3.BACK]
		
		var up_index = _rng.randi() % vec_list.size()
		var up_vec = vec_list[up_index]
		vec_list.remove(up_index)
		
		# Remove the opposite direction, as for the forward direction, we need
		# to pick one that is at a right angle to the one we just picked out.
		vec_list.remove(up_index - (up_index % 2))
		
		var forward_index = _rng.randi() % vec_list.size()
		var forward_vec = vec_list[forward_index]
		
		hover_up = up_vec
		hover_forward = forward_vec
