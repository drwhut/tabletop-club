# tabletop-club
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows
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

tool
extends WindowDialog

class_name SaveDialog

signal load_file(path)
signal save_file(path)

export(String) var save_dir: String = "user://" setget set_save_dir, get_save_dir
export(String) var save_ext: String = "tc"
export(bool) var save_mode: bool = false setget set_save_mode, get_save_mode

var _confirm_dialog: ConfirmationDialog
var _file_name_edit: LineEdit
var _load_save_button: Button
var _save_container: VBoxContainer

var _save_preview = preload("res://Scenes/Game/UI/Previews/GenericPreview.tscn")

# Clear the list of saves.
func clear() -> void:
	for preview in _save_container.get_children():
		_save_container.remove_child(preview)
		preview.queue_free()

# Get the save directory.
# Returns: The save directory.
func get_save_dir() -> String:
	return save_dir

# Get if the dialog is in save mode rather than load mode.
# Returns: If the dialog is in safe mode.
func get_save_mode() -> bool:
	return save_mode

# Refresh the save list.
func refresh() -> void:
	if Engine.is_editor_hint():
		return
	
	var dir = Directory.new()
	if dir.open(save_dir) != OK:
		push_error("Could not open the save directory at '%s'!" % save_dir)
		return
	
	var file_entry_list = []
	dir.list_dir_begin(true, true)
	
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.get_extension() == save_ext:
				var file_path = save_dir + "/" + file_name
				var file = File.new()
				var modified_time = file.get_modified_time(file_path)
				
				var modified_datetime = OS.get_datetime_from_unix_time(modified_time)
				var modified_year     = modified_datetime["year"]
				var modified_month    = modified_datetime["month"]
				var modified_day      = modified_datetime["day"]
				var modified_hour     = modified_datetime["hour"]
				var modified_minute   = modified_datetime["minute"]
				var modified_second   = modified_datetime["second"]
				
				var modified_datetime_str = "%s/%s/%s %d:%d:%d" % [modified_year,
					modified_month, modified_day, modified_hour, modified_minute,
					modified_second]
				
				# Don't display the file extension in the save list.
				var file_ext = file_name.get_extension()
				var ext_index = file_name.length() - file_ext.length()
				var display_name = file_name.substr(0, ext_index - 1)
				
				var file_entry = {
					"description": tr("Created: %s") % modified_datetime_str,
					"modified_time": modified_time,
					"name": display_name
				}
				
				# Check if there is an image file that goes with the save.
				var image_path = save_dir + "/" + display_name + ".png"
				if file.file_exists(image_path):
					file_entry["texture_path"] = image_path
				
				file_entry_list.append(file_entry)
		
		file_name = dir.get_next()
	
	# TODO: Sort the list either by modified time or by name.
	
	clear()
	
	for file_entry in file_entry_list:
		var preview = _save_preview.instance()
		preview.imported_texture = false
		preview.connect("clicked", self, "_on_preview_clicked")
		_save_container.add_child(preview)
		
		preview.set_entry(file_entry)

# Set the save directory.
# new_save_dir: The new save directory.
func set_save_dir(new_save_dir: String) -> void:
	save_dir = new_save_dir
	
	if visible:
		refresh()

# Set if the dialog is in safe mode rather than load mode.
# new_save_mode: If the dialog shoulb be in save mode.
func set_save_mode(new_save_mode: bool) -> void:
	save_mode = new_save_mode
	
	window_title = tr("Save a file") if save_mode else tr("Load a file")
	
	_file_name_edit.editable = save_mode
	_load_save_button.text = tr("Save") if save_mode else tr("Load")

func _init():
	var top_container = VBoxContainer.new()
	top_container.anchor_bottom = ANCHOR_END
	top_container.anchor_right = ANCHOR_END
	add_child(top_container)
	
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = SIZE_EXPAND_FILL
	top_container.add_child(scroll_container)
	
	_save_container = VBoxContainer.new()
	_save_container.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll_container.add_child(_save_container)
	
	var options_container = HBoxContainer.new()
	top_container.add_child(options_container)
	
	_file_name_edit = LineEdit.new()
	_file_name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	options_container.add_child(_file_name_edit)
	
	_load_save_button = Button.new()
	_load_save_button.connect("pressed", self, "_on_load_save_button_pressed")
	options_container.add_child(_load_save_button)
	
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.window_title = tr("Overwrite file?")
	_confirm_dialog.dialog_text = tr("The file already exists. Are you sure you want to overwrite it?")
	_confirm_dialog.dialog_autowrap = true
	_confirm_dialog.rect_size = Vector2(250, 100)
	_confirm_dialog.connect("confirmed", self, "_on_confirmed")
	add_child(_confirm_dialog)
	
	if not is_connected("about_to_show", self, "_on_about_to_show"):
		connect("about_to_show", self, "_on_about_to_show")
	if not is_connected("popup_hide", self, "_on_popup_hide"):
		connect("popup_hide", self, "_on_popup_hide")

# Get the current file path.
# Returns: The current file path.
func _get_file_path() -> String:
	return save_dir + "/" + _file_name_edit.text + "." + save_ext

func _on_about_to_show():
	refresh()
	
	if save_mode:
		# Give the user a default name for the save file that doesn't already
		# exist.
		var file_exists = true
		var file_path = ""
		var index = 0
		
		while file_exists:
			file_path = save_dir + "/New Game"
			if index > 0:
				file_path += " (%d)" % index
			file_path += "." + save_ext
			
			var file = File.new()
			file_exists = file.file_exists(file_path)
			index += 1
		
		# Just use the file name without the extension.
		var ext_index = file_path.length() - save_ext.length()
		var file_name = file_path.substr(0, ext_index - 1).get_file()
		_file_name_edit.text = file_name
	else:
		# Let the player pick a save file to load.
		_file_name_edit.text = ""

func _on_confirmed():
	var path = _get_file_path()
	if save_mode:
		emit_signal("save_file", path)
	else:
		emit_signal("load_file", path)
	
	visible = false

func _on_load_save_button_pressed():
	var path = _get_file_path()
	var file = File.new()
	if save_mode and file.file_exists(path):
		_confirm_dialog.popup_centered()
	else:
		_on_confirmed()

func _on_popup_hide():
	clear()

func _on_preview_clicked(preview: GenericPreview, event: InputEventMouseButton):
	if event.button_index == BUTTON_LEFT:
		var file_entry = preview.get_entry()
		_file_name_edit.text = file_entry["name"]
	else:
		# TODO: Popup a menu with extra options like copy, delete, etc.
		pass
