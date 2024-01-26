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

extends AnimationPlayer

## The splash screen for the game, which shows the Godot Engine logo.


## The next scene to show once the splash screen is finished.
export(PackedScene) var next_scene: PackedScene


func _ready():
	connect("animation_finished", self, "_on_animation_finished")
	
	# Load any saved settings now so that, for example, the game will enter
	# fullscreen mode as soon as possible. Note that settings for scenes like
	# the camera controller cannot be loaded yet, so we'll apply these settings
	# again a second time once the main game scene has been loaded.
	GameConfig.load_from_file()
	GameConfig.apply_all()
	
	# If the configuration file is using the old v0.1.x binding system, then we
	# want to switch to using the new v0.2.0+ system as soon as possible, so
	# that we can try to prevent the default bindings from v0.1.x from
	# overwriting any new defaults.
	if GameConfig.flag_using_old_binding_system:
		print("GameConfig: Old config file format detected, saving with new format...")
		GameConfig.save_to_file()
	
	# Load the default asset pack as register it as early as possible.
	var ttc_pack := preload("res://assets/default_pack/ttc_pack.tres")
	ttc_pack.reset_dictionary()
	AssetDB.add_pack(ttc_pack)
	AssetDB.commit_changes()
	
	if GameConfig.general_skip_splash_screen:
		_goto_next_scene()
	else:
		play("FadeInAndOut")


func _unhandled_input(event: InputEvent):
	if event is InputEventJoypadButton or \
		event is InputEventScreenTouch or \
		event is InputEventKey:
			_goto_next_scene()


func _goto_next_scene() -> void:
	var err := get_tree().change_scene_to(next_scene)
	if err != OK:
		push_error("Failed to change to scene at '%s' (error: %d)" % [
				next_scene.resource_path, err])


func _on_animation_finished(_anim_name: String):
	_goto_next_scene()
