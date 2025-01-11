# tabletop-club
# Copyright (c) 2020-2024 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2024 Tabletop Club contributors (see game/CREDITS.tres).
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

## Manage the lamps that light the room scene.


## The colour of the light being emitted from the lamp.
var light_color := Color.white setget set_light_color, get_light_color

## Set how intense the current lamp is.
var light_intensity := 1.0 setget set_light_intensity, get_light_intensity

## If [code]true[/code], the sun lamp will be the currently active lamp. Else,
## it will be the spot lamp.
var sun_light_enabled := true setget set_sun_light_enabled, get_sun_light_enabled


onready var _sun_light := $SunLight
onready var _spot_light := $SpotLight


func get_light_color() -> Color:
	# Both lamps should have the same light colour.
	return _sun_light.light_color


func get_light_intensity() -> float:
	# Both lamps should have the same energy value.
	return _sun_light.light_energy


func get_sun_light_enabled() -> bool:
	return _sun_light.visible


func set_light_color(value: Color) -> void:
	_sun_light.light_color = value
	_spot_light.light_color = value


func set_light_intensity(value: float) -> void:
	_sun_light.light_energy = value
	_spot_light.light_energy = value


func set_sun_light_enabled(value: bool) -> void:
	_sun_light.visible = value
	_spot_light.visible = not value
