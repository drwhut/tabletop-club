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

class_name PieceState
extends Resource

## Details the state of a generic piece within a [RoomState].


## The index of the piece within the room. If the value is negative, this is
## seen as 'to-be-determined', and should be assigned when the piece is added
## to the room.
export(int) var index_id := 0

## The [AssetEntryScene] that this piece was built from.
## TODO: Make typed in 4.x
export(Resource) var scene_entry: Resource = null setget set_scene_entry

## Determines if the piece is locked in place or not.
export(bool) var is_locked := false

## The position and rotation of the piece.
export(Transform) var transform := Transform.IDENTITY

## The custom scale of the piece.
## NOTE: This information is not included in the transform, as the scale is
## applied before any rotation occurs.
## TODO: For this and the albedo, double-check if these are the values BEFORE
## or AFTER the entry's scale and albedo from v0.1.x!
export(Vector3) var user_scale := Vector3.ONE

## The custom albedo colour applied to this piece.
export(Color) var user_albedo := Color.white


func set_scene_entry(entry: AssetEntryScene) -> void:
	scene_entry = entry
