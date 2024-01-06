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

class_name SpeakerState
extends PieceState

## Describes the state of a speaker object within a [RoomState].


## If [code]true[/code], the speaker is currently outputting to the music bus.
## Otherwise, it is outputting to the sounds bus.
## TODO: Is this necessary if we know [member track_entry] is a music track?
export(bool) var is_using_music_bus := true

## Determines if the speaker is currently playing audio.
## TODO: Combine this with is_paused to make an enum of values? Decide once we
## re-write the Speaker class?
export(bool) var is_playing := false

## Determines if the track being played is currently paused.
export(bool) var is_paused := false

## Determines if the speaker is playing audio positionally (i.e. in 3D space).
export(bool) var is_positional := false

## How far along the speaker is in playing the current track in seconds.
export(float) var playback_position := 0.0

## If the speaker is playing audio positionally, how far away can the audio be
## heard from?
export(float) var unit_size := 1.0

## The [AssetEntryAudio] corresponding to the currently loaded track. If set to
## [code]null[/code], no track is loaded.
## TODO: Make typed in 4.x.
export(Resource) var track_entry: Resource = null setget set_track_entry


func set_track_entry(entry: AssetEntryAudio) -> void:
	track_entry = entry
