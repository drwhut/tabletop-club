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

class_name AssetEntryAudio
extends AssetEntrySingle

## An entry that represents an audio track.
##
## Audio tracks can be played in-game by loading them into either a
## [PieceSpeaker] or a [PieceTimer].


## A path to an [AudioStream] resource.
export(String, FILE, "*.mp3,*.ogg,*.wav") var audio_path := "" setget set_audio_path

## Determines if the audio stream is a music track.
export(bool) var music := false


## Load the [AudioStream] at [member audio_path], or [code]null[/code] if no
## audio stream exists at that location, or it failed to load.
func load_audio() -> AudioStream:
	if audio_path.empty():
		return null
	
	var audio_stream := load(audio_path) as AudioStream
	if audio_stream == null:
		return null
	
	# Prevent the track from looping, since we can just start the stream again
	# if we want to loop it anyways.
	if audio_stream is AudioStreamMP3:
		audio_stream.loop = false
	elif audio_stream is AudioStreamOGGVorbis:
		audio_stream.loop = false
	elif audio_stream is AudioStreamSample:
		audio_stream.loop_mode = AudioStreamSample.LOOP_DISABLED
	
	return audio_stream


func set_audio_path(value: String) -> void:
	if not SanityCheck.is_valid_res_path(value, SanityCheck.VALID_EXTENSIONS_AUDIO):
		return
	
	audio_path = value.simplify_path()
