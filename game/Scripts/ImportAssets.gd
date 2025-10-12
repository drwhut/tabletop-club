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

onready var _importing_label = $VBoxContainer/ImportingLabel
onready var _missing_assets_popup = $MissingAssetsPopup
onready var _missing_module_popup = $MissingModulePopup
onready var _progress_bar = $VBoxContainer/ProgressBar

func _ready():
	# Create an assets folder in the user's documents folder, so that they have
	# an easy-to-locate place to place custom asset packs.
	var assets_dir = Global.get_output_subdir("assets")
	print("Created assets directory at '%s'." % assets_dir.get_current_dir())
	
	AssetDB.connect("completed", self, "_on_importing_completed")
	AssetDB.connect("importing_file", self, "_on_importing_file")
	
	# Check to see if the TabletopClub Godot module is loaded.
	if Global.tabletop_importer != null:
		AssetDB.start_importing()
	else:
		_missing_module_popup.popup_centered()

func _on_importing_completed(dir_found: bool) -> void:
	# Now that we've imported everything, check to see if we should export the
	# AssetDB to a file...
	var args = OS.get_cmdline_args()
	var db_file_path_index = -1
	for argi in range(args.size()):
		if args[argi] == "--export-asset-db":
			db_file_path_index = argi + 1
			break
	
	if db_file_path_index >= 0:
		if db_file_path_index < args.size():
			var db_file_path: String = args[db_file_path_index]
			if db_file_path.is_abs_path() or db_file_path.is_rel_path():
				var file = File.new()
				var err = file.open(db_file_path, File.WRITE)
				if err == OK:
					file.store_string(JSON.print(AssetDB.get_db(), "\t"))
					file.close()
				else:
					push_error("Failed to open %s: error %d" % [db_file_path, err])
			else:
				push_error("File path argument is not a valid file path!")
		else:
			push_error("No file path argument given for --export-asset-db!")
		
		get_tree().quit()
	
	# Should be safe to get the AssetDB now that it's done importing.
	var no_assets = AssetDB.get_db().empty()
	if (not dir_found) or no_assets:
		var missing_text = ""
		
		if no_assets:
			missing_text += tr("Tabletop Club could not find any asset packs in the following folders:")
		else:
			missing_text += tr("Tabletop Club could not find an assets folder in any of the following places:")
		missing_text += "\n\n"
		for asset_dir in AssetDB.get_asset_paths():
			missing_text += asset_dir + "\n"
		missing_text += "\n"
		if no_assets:
			missing_text += tr("Please place an asset pack into one of these folders, and restart the game.")
		else:
			missing_text += tr("Please create one of these folders and restart the game.")
		
		_missing_assets_popup.dialog_text = missing_text
		_missing_assets_popup.popup_centered()
	else:
		Global.start_main_menu()

func _on_importing_file(file: String, files_imported: int, files_total: int) -> void:
	_importing_label.text = file
	_progress_bar.value = float(files_imported) / files_total

func _on_MissingAssetsPopup_popup_hide():
	Global.start_main_menu()

func _on_MissingModulePopup_popup_hide():
	Global.start_main_menu()
