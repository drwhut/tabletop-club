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

## Load the main game scene while showing a progress bar.


## The maximum duration of each frame while loading the scene.
const LOADING_BLOCK_DURATION_MS := 20

## The file path of the scene to load.
export(String, FILE, "*.tscn,*.scn") var scene_path := ""

## The loader for the scene that can be polled over time.
var _loader: ResourceInteractiveLoader = null

## The progress bar to update while the scene is loading.
onready var progress_bar := $MarginContainer/VBoxContainer/ProgressBar


func _ready():
	_loader = ResourceLoader.load_interactive(scene_path, "PackedScene")
	if _loader == null:
		push_error("Error creating loader for scene at '%s'" % scene_path)
		set_process(false)


func _process(_delta):
	var time := OS.get_ticks_msec()
	while OS.get_ticks_msec() < time + LOADING_BLOCK_DURATION_MS:
		var err := _loader.poll()
		
		if err == ERR_FILE_EOF:
			var scene: PackedScene = _loader.get_resource()
			var scene_err := get_tree().change_scene_to(scene)
			if scene_err != OK:
				push_error("Failed to change to scene at '%s' (error: %d)" % [
						scene_path, scene_err])
			
			set_process(false)
			break
		elif err == OK:
			var current_progress := 0.0
			var num_stages := _loader.get_stage_count()
			if num_stages > 0:
				current_progress = float(_loader.get_stage()) / num_stages
			
			progress_bar.value = current_progress
		else:
			push_error("Error while loading '%s' (error: %d)" % [scene_path, err])
			
			# Delete the loader, and stop _process() from trying to access it.
			_loader = null
			set_process(false)
			break
