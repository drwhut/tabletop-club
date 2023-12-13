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

extends AttentionPanel

## A pop-up panel showing version and licensing information about the game.


onready var _license_label := $SplitContainer/LicenseLabel
onready var _version_label := $SplitContainer/VersionContainer/VersionLabel


func _ready():
	_version_label.text = ProjectSettings.get_setting("application/config/name")
	if ProjectSettings.has_setting("application/config/version"):
		_version_label.text += " " + ProjectSettings.get_setting("application/config/version")
	
	# The label will already contain the copyright and license for the project
	# itself.
	_license_label.bbcode_text = _license_label.text
	_license_label.bbcode_enabled = true
	if not _license_label.bbcode_text.ends_with("\n"):
		_license_label.bbcode_text += "\n"
	
	# Include copyright and license information about the resources that this
	# project uses.
	_license_label.bbcode_text += "\n[center][u]Resources[/u][/center]\n\n\n"
	_license_label.bbcode_text += preload("res://LICENSES.txt").text
	if not _license_label.bbcode_text.ends_with("\n"):
		_license_label.bbcode_text += "\n"
	
	# Include copyright and license information about Godot, and the third-party
	# libraries it uses.
	_license_label.bbcode_text += "\n[center][u]Godot Engine & Libraries[/u][/center]"
	var copyright_info = Engine.get_copyright_info()
	
	for component in copyright_info:
		var component_name: String = component["name"]
		_license_label.bbcode_text += "\n\n\n- %s" % component_name
		
		for subcomponent in component["parts"]:
			var files: Array = subcomponent["files"]
			var copyright: Array = subcomponent["copyright"]
			var license: String = subcomponent["license"]
			
			_license_label.bbcode_text += "\n\n\tFiles:\n"
			for file in files:
				_license_label.bbcode_text += "\t\t" + file + "\n"
			for copyright_line in copyright:
				_license_label.bbcode_text += "\t(c) " + copyright_line + "\n"
			_license_label.bbcode_text += "\tLicense: " + license
	
	# Include all of the license information at the end.
	_license_label.bbcode_text += "\n\n[center][u]Licenses[/u][/center]"
	var license_info = Engine.get_license_info()
	
	# Include any licenses that are not used by the engine.
	license_info["CC-BY-SA-4.0"] = preload("res://LICENSE_CC_BY-SA_4.0.txt").text
	var license_names_sorted = license_info.keys()
	license_names_sorted.sort()
	
	for license_name in license_names_sorted:
		var display_name: String = license_name
		if "Expat" in display_name:
			display_name += " / MIT"
		var license_data: String = license_info[license_name]
		
		if not _license_label.text.ends_with("\n"):
			_license_label.bbcode_text += "\n"
		
		_license_label.bbcode_text += "\n\n- %s\n\n[indent]%s[/indent]" % [
				display_name, license_data]


func _on_BackButton_pressed():
	visible = false
