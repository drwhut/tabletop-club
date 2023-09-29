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

class_name MainMenuCamera
extends Camera

## A cinematic camera used to show the room when the main menu is active.


## The height at which the camera orbits above the horizontal plane.
export(float) var height := 0.0

## The radius at which the camera orbits around the origin.
export(float) var radius := 1.0

## The speed at which the camera orbits around the origin.
export(float) var speed := 1.0

# How much time has passed since the camera started moving.
var _time_passed_sec := 0.0


func _process(delta: float):
	_time_passed_sec += delta
	var angle := speed * _time_passed_sec
	var new_pos := radius * Vector3(sin(angle), 0.0, cos(angle))
	new_pos.y = height
	
	var centre := Vector3(0.0, height, 0.0)
	look_at_from_position(new_pos, centre, Vector3.UP)
