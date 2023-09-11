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

class_name AssetCatalogInteractive
extends Reference

## Import asset packs in a separate thread.
##
## You can use [method start] to start the import thread, after which you can
## repeatedly check using [method is_done] to see if importing is complete.
## Once that function returns [code]true[/code], you can then use
## [method get_packs] to get the list of [AssetPack] generated by the import
## thread.


enum {
	## The import thread is currently not doing anything.
	STAGE_IDLE,
	
	## The import thread is currently scanning in assets.
	STAGE_SCANNING,
	
	## The import thread is currently importing assets.
	STAGE_IMPORTING,
	
	## The import thread is currently cleaning rogue files.
	STAGE_CLEANING,
	
	## Used for data validation.
	STAGE_MAX
}


## A structure holding information about the progress of the import thread.
class ProgressReport:
	extends Reference
	
	## The stage of the import process the thread is currently at.
	var import_stage := STAGE_IDLE setget set_import_stage
	
	## The name of the asset pack that is being imported currently.
	var pack_name := ""
	
	## The index of the asset pack being imported.
	var pack_index := 0
	
	## The number of asset packs being imported in total.
	var pack_count := 0
	
	## The relative file path of the file being imported currently.
	var file_path := ""
	
	## The index of the file being imported in its asset pack.
	var file_index := 0
	
	## The total number of files to import in the current asset pack.
	var file_count := 0
	
	
	func set_import_stage(value: int) -> void:
		if value < STAGE_IDLE or value >= STAGE_MAX:
			push_error("Invalid value '%d' for import stage" % value)
			return
		
		import_stage = value


# The thread that imports custom assets.
var _import_thread: Thread = null

# The current progress of the import thread.
var _import_progress := ProgressReport.new()

# A mutex for the progress report variable.
var _import_progress_mutex := Mutex.new()


## Start importing assets in a separate thread. If the thread was already
## started and has yet to complete its function, then the main thread is blocked
## until it is done. If [code]scan_dir[/code] is empty, then the default
## external directory is scanned for asset packs.
func start(scan_dir: String = "") -> void:
	if _import_thread != null:
		if _import_thread.is_active():
			_import_thread.wait_to_finish()
	
	_import_progress_mutex.lock()
	_import_progress = ProgressReport.new()
	_import_progress_mutex.unlock()
	
	_import_thread = Thread.new()
	_import_thread.start(self, "_import_assets", scan_dir)


## Check whether the thread is done importing custom assets or not.
func is_done() -> bool:
	if _import_thread == null:
		return false
	
	return not _import_thread.is_alive()


## Get the current progress of the import thread. Can be used to display the
## progress in the UI.
func get_progress() -> ProgressReport:
	# Since the ProgressReport is a reference, we don't want to return the same
	# reference as the one that is written to by the import thread, so duplicate
	# it in the name of thread safety.
	_import_progress_mutex.lock()
	var out := ProgressReport.new()
	out.import_stage = _import_progress.import_stage
	out.pack_name = _import_progress.pack_name
	out.pack_index = _import_progress.pack_index
	out.pack_count = _import_progress.pack_count
	out.file_path = _import_progress.file_path
	out.file_index = _import_progress.file_index
	out.file_count = _import_progress.file_count
	_import_progress_mutex.unlock()
	
	return out


## Get the list of [AssetPack] generated from the import process. Note that this
## function waits for the thread to finish before returning, so you should use
## [method is_done] before calling this function to avoid blocking the main
## thread. If the thread has not been started, then an empty array is returned.
func get_packs() -> Array:
	if _import_thread == null:
		return []
	
	if not _import_thread.is_active():
		return []
	
	return _import_thread.wait_to_finish()


# The thread function that imports the custom assets.
# TODO: Make array typed in 4.x
func _import_assets(scan_dir: String) -> Array:
	var catalog := AssetCatalog.new()
	catalog.connect("about_to_import_pack", self, "_on_catalog_about_to_import_pack")
	catalog.connect("about_to_import_file", self, "_on_catalog_about_to_import_file")
	
	_import_progress_mutex.lock()
	_import_progress.import_stage = STAGE_SCANNING
	_import_progress_mutex.unlock()
	
	if scan_dir.empty():
		catalog.scan_external_dir()
	else:
		var dir := Directory.new()
		var err := dir.open(scan_dir)
		if err == OK:
			catalog.scan_dir_for_packs(dir)
		else:
			push_error("Failed to open scan directory '%s' (error: %d)" % [
					scan_dir, err])
	
	_import_progress_mutex.lock()
	_import_progress.import_stage = STAGE_IMPORTING
	_import_progress_mutex.unlock()
	
	var imported_packs := catalog.import_all()
	
	_import_progress_mutex.lock()
	_import_progress.import_stage = STAGE_CLEANING
	_import_progress_mutex.unlock()
	
	catalog.clean_rogue_files()
	
	_import_progress_mutex.lock()
	_import_progress.import_stage = STAGE_IDLE
	_import_progress_mutex.unlock()
	
	return imported_packs


func _on_catalog_about_to_import_pack(pack_name: String, pack_index: int,
		pack_count: int):
	
	_import_progress_mutex.lock()
	_import_progress.pack_name = pack_name
	_import_progress.pack_index = pack_index
	_import_progress.pack_count = pack_count
	
	# Reset the file progress, as it will be out-of-date with the new pack.
	_import_progress.file_path = ""
	_import_progress.file_index = 0
	_import_progress.file_count = 0
	_import_progress_mutex.unlock()


func _on_catalog_about_to_import_file(file_path: String, file_index: int,
		file_count: int):
	
	_import_progress_mutex.lock()
	_import_progress.file_path = file_path
	_import_progress.file_index = file_index
	_import_progress.file_count = file_count
	_import_progress_mutex.unlock()
