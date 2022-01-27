# tabletop-club
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021 Tabletop Club contributors (see game/CREDITS.tres).
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

# TODO: export(RandomAudioSample)
# See: https://github.com/godotengine/godot/pull/44879
export(Resource) var shake_sounds

var _rng = RandomNumberGenerator.new()

func _ready():
	_rng.randomize()

func _physics_process(_delta):
	if is_being_shaked():
		if get_tree().is_network_server():
			var new_basis = hover_basis
			new_basis = new_basis.rotated(Vector3.RIGHT, 2 * PI * _rng.randf())
			new_basis = new_basis.rotated(Vector3.UP, 2 * PI * _rng.randf())
			new_basis = new_basis.rotated(Vector3.BACK, 2 * PI * _rng.randf())
			rpc_id(1, "request_set_hover_basis", new_basis)
		
		if shake_sounds != null:
			play_effect(shake_sounds.random_stream())
