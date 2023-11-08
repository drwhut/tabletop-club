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

extends Spatial

## Handles all room logic, which mostly consists of 3D elements.


onready var _light_manager := $LightManager
onready var _room_environment := $RoomEnvironment
onready var _table_manager := $TableManager


func _ready():
	var state := StateLoader.load("res://tests/test_pack/games/test_state_v0.1.2.tc")
	set_state(state)


## Set the state of the room with a [RoomState].
func set_state(state: RoomState) -> void:
	_light_manager.light_color = state.lamp_color
	_light_manager.light_intensity = state.lamp_intensity
	_light_manager.sun_light_enabled = state.is_lamp_sunlight
	
	_room_environment.set_skybox(state.skybox_entry)
	
	_table_manager.set_table(state.table_entry)
	_table_manager.set_table_transform(state.table_transform)
