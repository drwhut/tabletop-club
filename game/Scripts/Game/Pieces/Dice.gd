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

extends Piece

class_name Dice

# TODO: export(RandomAudioSample)
# See: https://github.com/godotengine/godot/pull/44879
export(Resource) var shake_sounds

var _rng = RandomNumberGenerator.new()

# Get the value of the face that is currently pointed upwards.
# Returns: The top face's value, the empty string if no values are configured.
func get_face_value() -> String:
	var face_values: Dictionary = piece_entry["face_values"]
	if face_values.empty():
		return ""
	
	var max_dot = -1.0
	var closest_value: String = "0"
	for value in face_values:
		var normals: Array = face_values[value]
		for normal in normals:
			var dot = transform.basis.xform(normal).dot(Vector3.UP)
			if dot > max_dot:
				max_dot = dot
				closest_value = value
	
	return closest_value

func _ready():
	_rng.randomize()

func _physics_process(_delta):
	if is_being_shaked():
		if get_tree().is_network_server():
			var new_angles = 2 * PI * Vector3(_rng.randf(), _rng.randf(), _rng.randf())
			srv_set_hover_rotation(Quat(new_angles))
		
		if shake_sounds != null:
			play_effect(shake_sounds.random_stream())
