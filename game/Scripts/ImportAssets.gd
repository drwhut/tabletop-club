# tabletop-club
# Copyright (c) 2020-2022 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2022 Tabletop Club contributors (see game/CREDITS.tres).
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

onready var _importing_label = $VBoxContainer/ImportingLabel
onready var _missing_assets_popup = $MissingAssetsPopup
onready var _missing_module_popup = $MissingModulePopup
onready var _progress_bar = $VBoxContainer/ProgressBar

func _ready():
	# TODO: Load ALL options at the start of the game.
	var locale = ""
	var options = ConfigFile.new()
	if options.load("user://options.cfg") == OK:
		locale = options.get_value("general", "language", "")
	if locale.empty():
		locale = Global.system_locale
	TranslationServer.set_locale(locale)
	
	# Create an assets folder in the user's documents folder, so that they have
	# an easy-to-locate place to place custom asset packs.
	var assets_dir = Global.get_output_subdir("assets")
	print("Created assets directory at '%s'." % assets_dir.get_current_dir())
	
	AssetDB.connect("completed", self, "_on_importing_completed")
	AssetDB.connect("importing_file", self, "_on_importing_file")
	
	# Check to see if the TabletopClub Godot module is loaded.
	if AssetDB.importer_exists:
		AssetDB.start_importing()
	else:
		_missing_module_popup.popup_centered()

func _on_importing_completed(dir_found: bool) -> void:
	if dir_found:
		Global.start_main_menu()
	else:
		var missing_text = ""
		missing_text += tr("Tabletop Club couldn't find an assets folder in any of the following places:")
		missing_text += "\n\n"
		for asset_dir in AssetDB.get_asset_paths():
			missing_text += asset_dir + "\n"
		missing_text += "\n"
		missing_text += tr("Please create one of these folders and restart the game.")
		_missing_assets_popup.dialog_text = missing_text
		_missing_assets_popup.popup_centered()

func _on_importing_file(file: String, files_imported: int, files_total: int) -> void:
	_importing_label.text = file
	_progress_bar.value = float(files_imported) / files_total

func _on_MissingAssetsPopup_popup_hide():
	Global.start_main_menu()

func _on_MissingModulePopup_popup_hide():
	Global.start_main_menu()
