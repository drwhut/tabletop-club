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

extends PanelContainer


var _catalog_interactive := AssetCatalogInteractive.new()


onready var _loading_circle := $HBoxContainer/LoadingCircle
onready var _pack_label := $HBoxContainer/ProgressContainer/PackLabel
onready var _pack_progress := $HBoxContainer/ProgressContainer/PackProgress
onready var _file_label := $HBoxContainer/ProgressContainer/FileLabel
onready var _file_progress := $HBoxContainer/ProgressContainer/FileProgress


func _ready():
	connect("tree_exiting", self, "_on_tree_exiting")
	
	_catalog_interactive.start()


func _process(_delta):
	if _catalog_interactive.is_done():
		var imported_packs := _catalog_interactive.get_packs()
		
		for pack in imported_packs:
			AssetDB.add_pack(pack)
		
		AssetDB.commit_changes()
		
		visible = false
		set_process(false)
		_loading_circle.set_process(false)
	else:
		var progress := _catalog_interactive.get_progress()
		match progress.import_stage:
			AssetCatalogInteractive.STAGE_IDLE:
				_pack_label.text = tr("Waiting…")
			
			AssetCatalogInteractive.STAGE_SCANNING:
				_pack_label.text = tr("Scanning asset packs…")
			
			AssetCatalogInteractive.STAGE_IMPORTING:
				_pack_label.text = tr("Importing %s …") % progress.pack_name
				if progress.pack_count != 0:
					var pack_prog := float(progress.pack_index) / progress.pack_count
					_pack_progress.value = 100.0 * pack_prog
				
				if progress.file_path.empty():
					_file_label.visible = false
					_file_progress.visible = false
				else:
					_file_label.visible = true
					_file_progress.visible = true
					
					_file_label.text = progress.file_path
					if progress.file_count != 0:
						var file_prog := float(progress.file_index) / progress.file_count
						_file_progress.value = 100.0 * file_prog
			
			AssetCatalogInteractive.STAGE_CLEANING:
				_pack_label.text = tr("Cleaning internal directory…")
				_pack_progress.value = 100.0
				_file_label.visible = false
				_file_progress.visible = false


func _on_tree_exiting():
	# Force the import thread to end as quickly as possible.
	ImportAbortFlag.enable()
	
	# Join the import thread with the main thread before the game exits.
	_catalog_interactive.get_packs()
