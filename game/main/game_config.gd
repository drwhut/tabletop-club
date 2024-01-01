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

extends Node

## Stores configurable properties for the game, accessed by the options menu.
##
## NOTE: All floating-point properties are standardised to be between 0 and 1,
## it is up to other sections of code to determine how to transform that number.
## TODO: Test this class once it is complete.


## Fired when the current configuration is being applied to the entire game.
signal applying_settings()


## The path to the file containing these saved properties.
const CONFIG_FILE_PATH := "user://options.cfg"


## The volume of the master audio bus.
## NOTE: This value will need to be converted into dB in order to be useable by
## the [AudioServer].
var audio_master_volume := 0.5 setget set_audio_master_volume

## The volume of the music audio bus.
## NOTE: This value will need to be converted into dB in order to be useable by
## the [AudioServer].
var audio_music_volume := 1.0 setget set_audio_music_volume

## The volume of the sounds audio bus.
## NOTE: This value will need to be converted into dB in order to be useable by
## the [AudioServer].
var audio_sounds_volume := 1.0 setget set_audio_sounds_volume

## The volume of the effects audio bus.
## NOTE: This value will need to be converted into dB in order to be useable by
## the [AudioServer].
var audio_effects_volume := 1.0 setget set_audio_effects_volume


## Load the previously saved configuration from the disk.
func load_from_file() -> void:
	var dir := Directory.new()
	if not dir.file_exists(CONFIG_FILE_PATH):
		return
	
	var config_file := AdvancedConfigFile.new()
	var err := config_file.load(CONFIG_FILE_PATH)
	if err != OK:
		push_error("Failed to load game settings from '%s' (error: %d)" % [
				CONFIG_FILE_PATH, err])
		return
	
	set_audio_master_volume(config_file.get_value_strict("audio",
			"master_volume", audio_master_volume))
	set_audio_music_volume(config_file.get_value_strict("audio",
			"music_volume", audio_music_volume))
	set_audio_sounds_volume(config_file.get_value_strict("audio",
			"sounds_volume", audio_sounds_volume))
	set_audio_effects_volume(config_file.get_value_strict("audio",
			"effects_volume", audio_effects_volume))


## Save the current configuration to disk.
func save_to_file() -> void:
	var config_file := ConfigFile.new()
	
	config_file.set_value("audio", "master_volume", audio_master_volume)
	config_file.set_value("audio", "music_volume", audio_music_volume)
	config_file.set_value("audio", "sounds_volume", audio_sounds_volume)
	config_file.set_value("audio", "effects_volume", audio_effects_volume)
	
	var err := config_file.save(CONFIG_FILE_PATH)
	if err != OK:
		push_error("Failed to save game settings to '%s' (error: %d)" % [
				CONFIG_FILE_PATH, err])


## Apply the current configuration to the entire game.
## NOTE: This will emit [signal applying_settings].
func apply_all() -> void:
	apply_audio()
	
	emit_signal("applying_settings")


## Apply only the current audio configuration.
func apply_audio() -> void:
	set_audio_bus_volume("Master", audio_master_volume)
	set_audio_bus_volume("Music", audio_music_volume)
	set_audio_bus_volume("Sounds", audio_sounds_volume)
	set_audio_bus_volume("Effects", audio_effects_volume)


## Set the volume level (from 0-1) of the given audio bus.
func set_audio_bus_volume(bus_name: String, bus_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_error("Cannot set volume of audio bus '%s', does not exist" % bus_name)
		return
	
	var mute_bus := is_zero_approx(bus_volume)
	AudioServer.set_bus_mute(bus_index, mute_bus)
	
	if not mute_bus:
		var volume_db := convert_volume_to_db(bus_volume)
		AudioServer.set_bus_volume_db(bus_index, volume_db)


## Converts a volume level (from 0-1) into a dB level (from -INF to -6) that
## can be used by the [AudioServer] to set the dB level of an audio bus.
func convert_volume_to_db(volume: float) -> float:
	return 8.656170245 * log(0.5 * volume)


func set_audio_master_volume(value: float) -> void:
	if not SanityCheck.is_valid_float(value):
		return
	
	# TODO: Replace instances of max(..., min(...)) with clamp().
	audio_master_volume = clamp(value, 0.0, 1.0)


func set_audio_music_volume(value: float) -> void:
	if not SanityCheck.is_valid_float(value):
		return
	
	audio_music_volume = clamp(value, 0.0, 1.0)


func set_audio_sounds_volume(value: float) -> void:
	if not SanityCheck.is_valid_float(value):
		return
	
	audio_sounds_volume = clamp(value, 0.0, 1.0)


func set_audio_effects_volume(value: float) -> void:
	if not SanityCheck.is_valid_float(value):
		return
	
	audio_effects_volume = clamp(value, 0.0, 1.0)
