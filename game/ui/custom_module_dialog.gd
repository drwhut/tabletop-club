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

extends AttentionPanel

## A dialog that appears when the custom module has not been loaded, letting the
## player know how they can get a compatible build of Godot.


onready var _releases_link_label := $MarginContainer/MainContainer/LabelContainer/ReleasesLinkLabel
onready var _compile_link_label := $MarginContainer/MainContainer/LabelContainer/CompileLinkLabel


func _ready():
	_releases_link_label.bbcode_text = "[center][url]https://github.com/drwhut/godot/releases[/url][/center]"
	_compile_link_label.bbcode_text = "[center][url]https://tabletop-club.readthedocs.io/en/stable/general/download/compiling_from_source.html[/url][/center]"
	
	if not CustomModule.is_loaded():
		# Defer the call so that we get keyboard focus naturally.
		call_deferred("popup_centered")


func _on_ReleasesLinkLabel_meta_clicked(meta: String):
	OS.shell_open(meta)


func _on_CompileLinkLabel_meta_clicked(meta: String):
	OS.shell_open(meta)


func _on_CloseButton_pressed():
	visible = false
