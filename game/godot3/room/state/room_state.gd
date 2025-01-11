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

class_name RoomState
extends Resource

## Fully describes the state of the room at a given point in time.
##
## This is the main resource used when creating and loading save files, when
## pushing states to the undo stack, and for syncing the clients with the
## server.
##
## TODO: Test this resource, as well as the loading and saving of it (including
## loading save files from v0.1.x).


## The colour of the light being emitted from the lamp.
export(Color) var lamp_color := Color.white setget set_lamp_color

## The intensity of the light being emitted from the lamp.
export(float) var lamp_intensity := 1.0 setget set_lamp_intensity

## If [code]true[/code], the lamp is a sun light. Otherwise, it is a spot light.
export(bool) var is_lamp_sunlight := true

## The [AssetEntrySkybox] corresponding to the current background.
## TODO: Make typed in 4.x
export(Resource) var skybox_entry = \
	preload("res://assets/default_pack/skyboxes/park.tres") \
	setget set_skybox_entry

## The [AssetEntryTable] corresponding to the current table.
## TODO: Make typed in 4.x
export(Resource) var table_entry = \
	preload("res://assets/default_pack/tables/poker_table.tres") \
	setget set_table_entry

## The table's current transform. This should only be used if the table has been
## flipped, otherwise the table should always be in the same position, as
## defined by it's centre-of-mass.
##
## NOTE: In v0.1.x, this transform was used regardless of whether the table was
## flipped or not. The reason for this change is because the centre-of-mass of
## the default asset pack tables have been adjusted, so if this value were to
## be used before the table is flipped, the position of the table would be
## incorrect.
## TODO: The default table's COM were changed to fix a physics issue, but this
## may still be an issue with custom tables. Should tables have a standard COM,
## e.g. (0, -10, 0) or (0, 0, 0)? Test with radio that is scaled.
export(Transform) var table_transform := Transform.IDENTITY

## If [code]true[/code], the table is currently in motion (from being flipped),
## otherwise it is static.
export(bool) var is_table_rigid := false

## The image data for the table's paint plane. If [code]null[/code], this is
## equivalent to a transparent image (which saves memory).
export(Image) var table_paint_image: Image = null

## The list of hidden areas active within the state.
## TODO: Make array typed in 4.x
export(Array, Resource) var hidden_area_states := []

## The list of pieces active within the state.
## TODO: Make array typed in 4.x
export(Array, Resource) var piece_states := []


func set_lamp_color(value: Color) -> void:
	lamp_color = value
	lamp_color.a = 1.0


func set_lamp_intensity(value: float) -> void:
	if not SanityCheck.is_valid_float(value):
		return
	
	lamp_intensity = max(0.0, value)


func set_skybox_entry(entry: AssetEntrySkybox) -> void:
	skybox_entry = entry


func set_table_entry(entry: AssetEntryTable) -> void:
	table_entry = entry
