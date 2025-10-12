# tabletop-club
# Copyright (c) 2020-2025 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2025 Tabletop Club contributors (see game/CREDITS.tres).
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

onready var _animation_player = $CenterContainer/GodotLogo/AnimationPlayer

func _ready():
	# TODO: Try to load all of the options without needing the OptionsMenu scene
	# hidden in the splash screen.
	var locale: String = ""
	var skip_splash_screen: bool = false
	
	var options_file = ConfigFile.new()
	if options_file.load("user://options.cfg") == OK:
		locale = options_file.get_value("general", "language", "")
		skip_splash_screen = options_file.get_value("general",
				"skip_splash_screen", false)
	
	if locale.empty():
		locale = Global.system_locale
	TranslationServer.set_locale(locale)
	
	if skip_splash_screen:
		Global.start_importing_assets()
	else:
		_animation_player.play("FadeInAndOut")

func _unhandled_input(event: InputEvent):
	if event is InputEventJoypadButton or \
		event is InputEventScreenTouch or \
		event is InputEventKey:
			Global.start_importing_assets()

func _on_AnimationPlayer_animation_finished(_anim_name: String):
	Global.start_importing_assets()
