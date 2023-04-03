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

class_name DiceFaceValue
extends Resource

## A resource which assigns a custom value to the face of a die.


## The normal vector of the face whose value is being assigned.
export(Vector3) var normal := Vector3.UP setget set_normal

## The custom value assigned to the face.
## TODO: Make typed in 4.x
export(Resource) var value = CustomValue.new() setget set_value


func set_normal(new_normal: Vector3) -> void:
	if not SanityCheck.is_valid_vector3(new_normal):
		return
	
	if is_zero_approx(new_normal.length_squared()):
		push_error("Face normal cannot be (0, 0, 0)")
		return
	
	normal = new_normal.normalized()


## Set the normal vector using the X and Z rotations needed to make the desired
## face point upwards in radians.
func set_normal_with_euler(x_rot: float, z_rot: float) -> void:
	var euler = Vector3(x_rot, 0.0, z_rot)
	normal = Quat(euler).inverse().xform(Vector3.UP)


func set_value(new_value: CustomValue) -> void:
	value = new_value
