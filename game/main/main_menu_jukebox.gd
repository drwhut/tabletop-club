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

extends Control

## Play music from the default asset pack in the main menu.


## The list of music tracks to play, in the form of asset entries.
## TODO: Make array typed in 4.x
var _playlist_entry_arr: Array = []

## The number of tracks that have been played - used to decide the next track.
var _num_tracks_played := 0

## The label showing the name of the track that is currently playing.
onready var _now_playing_label := $NowPlayingLabel

## The audio stream player for the music.
onready var _music_player := $MusicPlayer

## The animation player responsible for fading out the music smoothly.
onready var _fade_out_player := $FadeOutPlayer


func _ready():
	_playlist_entry_arr = AssetDB.get_all_entries("music")
	
	randomize()
	_playlist_entry_arr.shuffle()


## Check if the jukebox is currently playing a track.
func is_playing_track() -> bool:
	return _music_player.playing and (not _fade_out_player.is_playing())


## Play the track that is currently at the front of the queue.
## NOTE: Ideally, this should be called after the game volume has been set.
func play_current_track() -> void:
	visible = true
	
	# If the music is currently fading out as we are trying to play it again,
	# stop the fade out effect.
	if _fade_out_player.is_playing():
		_fade_out_player.stop()
	
	# Reset the volume in case it was in the middle of fading out.
	_music_player.volume_db = 0.0
	
	if _music_player.playing:
		return
	
	_now_playing_label.text = tr("Now Playing: Nothing")
	
	if _playlist_entry_arr.empty():
		push_error("Unable to play current track, playlist is empty")
		return
	
	var current_index := _num_tracks_played % _playlist_entry_arr.size()
	var music_entry: AssetEntryAudio = _playlist_entry_arr[current_index]
	var music_stream := music_entry.load_audio()
	if music_stream == null:
		push_error("Failed to load audio stream at '%s'" % music_entry.audio_path)
		return
	
	_music_player.stream = music_stream
	_music_player.play()
	
	_now_playing_label.text = tr("Now Playing: %s") % music_entry.name


## Start fading out the music until it stops.
func start_fading_out() -> void:
	visible = false
	_fade_out_player.play("FadeOutMusic")


func _on_MusicPlayer_finished():
	_num_tracks_played += 1
	
	if _music_player.volume_db >= 0.0:
		play_current_track()


func _on_FadeOutPlayer_animation_finished(_anim_name: String):
	_music_player.stop()
