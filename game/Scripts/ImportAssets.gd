# open-tabletop
# Copyright (c) 2020 Benjamin 'drwhut' Beddows
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

onready var _importing_label = $CenterContainer/VBoxContainer/ImportingLabel
onready var _missing_assets_popup = $MissingAssetsPopup

func _ready():
	AssetDB.connect("completed", self, "_on_importing_completed")
	AssetDB.connect("importing_file", self, "_on_importing_file")
	
	AssetDB.start_importing()

func _on_importing_completed(dir_found: bool) -> void:
	if dir_found:
		Global.start_main_menu()
	else:
		var missing_text = ""
		missing_text += "OpenTabletop couldn't find an assets folder in any of the following places:"
		missing_text += "\n\n"
		for asset_dir in AssetDB.get_asset_paths():
			missing_text += asset_dir + "\n"
		missing_text += "\n"
		missing_text += "Please create one of these folders and restart the game."
		_missing_assets_popup.dialog_text = missing_text
		_missing_assets_popup.popup_centered()

func _on_importing_file(file: String) -> void:
	_importing_label.text = file

func _on_MissingAssetsPopup_popup_hide():
	Global.start_main_menu()
