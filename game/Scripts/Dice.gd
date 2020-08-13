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

extends Piece

class_name Dice

var _rng = RandomNumberGenerator.new()

func _ready():
	_mesh_instance = $CollisionShape/MeshInstance
	
	_rng.randomize()

func _physics_process(delta):
	
	# If the dice is being shaked, randomize the basis.
	if get_tree().is_network_server() and is_being_shaked():
		_srv_hover_basis = _srv_hover_basis.rotated(Vector3.RIGHT, 2 * PI * _rng.randf())
		_srv_hover_basis = _srv_hover_basis.rotated(Vector3.UP, 2 * PI * _rng.randf())
		_srv_hover_basis = _srv_hover_basis.rotated(Vector3.BACK, 2 * PI * _rng.randf())
