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

tool
extends WindowDialog

class_name SaveDialog

signal load_file(path)
signal save_file(path)

enum {
	CONTEXT_RENAME,
	CONTEXT_DUPLICATE,
	CONTEXT_DELETE
}

enum {
	SORT_LAST_MODIFIED,
	SORT_NAME
}

export(String) var save_dir: String = "user://" setget set_save_dir, get_save_dir
export(String) var save_ext: String = "tc"
export(bool) var save_mode: bool = false setget set_save_mode, get_save_mode

var _confirm_delete_dialog: ConfirmationDialog
var _confirm_overwrite_dialog: ConfirmationDialog
var _context_menu: PopupMenu
var _file_name_edit: LineEdit
var _invalid_name_dialog: AcceptDialog
var _load_save_button: Button
var _rename_line_edit: LineEdit
var _rename_window: WindowDialog
var _save_container: VBoxContainer
var _sort_by_button: OptionButton

var _context_file_entry: Dictionary = {}

var _save_preview = preload("res://Scenes/Game/UI/Previews/GenericPreview.tscn")

func _ready():
	connect("gui_input", self, "_on_gui_input")
	
func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.doubleclick and event.button_index == BUTTON_LEFT:
		_on_load_save_button_pressed()

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
				
				var modified_datetime_str = "%02d/%02d/%02d %02d:%02d:%02d" % [
					modified_year, modified_month, modified_day, modified_hour,
					modified_minute, modified_second]
				
				# Don't display the file extension in the save list.
				var display_name = file_name.get_basename()
				
				var file_entry = {
					"desc": tr("Modified: %s") % modified_datetime_str,
					"modified_time": modified_time,
					"name": display_name
				}
				
				# Check if there is an image file that goes with the save.
				var image_path = save_dir + "/" + display_name + ".png"
				if file.file_exists(image_path):
					file_entry["texture_path"] = image_path
				
				file_entry_list.append(file_entry)
		
		file_name = dir.get_next()
	
	match _sort_by_button.get_selected_id():
		SORT_LAST_MODIFIED:
			file_entry_list.sort_custom(self, "_sort_modified_time")
		SORT_NAME:
			file_entry_list.sort_custom(self, "_sort_name")
	
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
	
	var filter_container = HBoxContainer.new()
	filter_container.alignment = HALIGN_RIGHT
	top_container.add_child(filter_container)
	
	var sort_by_label = Label.new()
	sort_by_label.text = tr("Sort:")
	filter_container.add_child(sort_by_label)
	
	_sort_by_button = OptionButton.new()
	_sort_by_button.add_item(tr("Last Modified"), SORT_LAST_MODIFIED)
	_sort_by_button.add_item(tr("Name"), SORT_NAME)
	_sort_by_button.connect("item_selected", self, "_on_sort_by_selected")
	filter_container.add_child(_sort_by_button)
	
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = SIZE_EXPAND_FILL
	scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
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
	
	_confirm_delete_dialog = ConfirmationDialog.new()
	_confirm_delete_dialog.window_title = tr("Delete file?")
	# The dialog text is set on popup.
	_confirm_delete_dialog.dialog_autowrap = true
	_confirm_delete_dialog.rect_size = Vector2(250, 100)
	_confirm_delete_dialog.connect("confirmed", self, "_on_delete_confirmed")
	add_child(_confirm_delete_dialog)
	
	_confirm_overwrite_dialog = ConfirmationDialog.new()
	_confirm_overwrite_dialog.window_title = tr("Overwrite file?")
	# The dialog text is set on popup.
	_confirm_overwrite_dialog.dialog_autowrap = true
	_confirm_overwrite_dialog.rect_size = Vector2(250, 100)
	_confirm_overwrite_dialog.connect("confirmed", self, "_on_save_confirmed")
	add_child(_confirm_overwrite_dialog)
	
	_context_menu = PopupMenu.new()
	_context_menu.add_item(tr("Rename"), CONTEXT_RENAME)
	_context_menu.add_item(tr("Duplicate"), CONTEXT_DUPLICATE)
	_context_menu.add_item(tr("Delete"), CONTEXT_DELETE)
	_context_menu.connect("id_pressed", self, "_on_context_menu_id_pressed")
	add_child(_context_menu)
	
	_invalid_name_dialog = AcceptDialog.new()
	_invalid_name_dialog.window_title = tr("Invalid name!")
	# We use String.is_valid_filename() to determine invalid characters.
	_invalid_name_dialog.dialog_text = tr("File names cannot contain any of the following characters:\n%s") % ": / \\ ? * \" | % < >"
	_invalid_name_dialog.dialog_autowrap = true
	_invalid_name_dialog.rect_size = Vector2(250, 100)
	add_child(_invalid_name_dialog)
	
	_rename_window = WindowDialog.new()
	_rename_window.window_title = tr("Rename file...")
	_rename_window.rect_size = Vector2(300, 50)
	add_child(_rename_window)
	
	var rename_vbox_container = VBoxContainer.new()
	rename_vbox_container.anchor_bottom = ANCHOR_END
	rename_vbox_container.anchor_right = ANCHOR_END
	_rename_window.add_child(rename_vbox_container)
	
	var rename_label = Label.new()
	rename_label.text = tr("Please enter a new name for the file:")
	rename_vbox_container.add_child(rename_label)
	
	var rename_hbox_container = HBoxContainer.new()
	rename_vbox_container.add_child(rename_hbox_container)
	
	_rename_line_edit = LineEdit.new()
	_rename_line_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	rename_hbox_container.add_child(_rename_line_edit)
	
	var rename_button = Button.new()
	rename_button.text = tr("Rename")
	rename_button.connect("pressed", self, "_on_rename_pressed")
	rename_hbox_container.add_child(rename_button)
	
	if not is_connected("about_to_show", self, "_on_about_to_show"):
		connect("about_to_show", self, "_on_about_to_show")
	if not is_connected("popup_hide", self, "_on_popup_hide"):
		connect("popup_hide", self, "_on_popup_hide")

# Get the current file path.
# Returns: The current file path.
func _get_file_path() -> String:
	var file_name = _file_name_edit.text.strip_edges().strip_escapes()
	return save_dir + "/" + file_name + "." + save_ext

# Sort an array of file entries by modified time, descending.
# a: The first element.
# b: The second element.
func _sort_modified_time(a: Dictionary, b: Dictionary) -> bool:
	return a["modified_time"] > b["modified_time"]

# Sort an array of file entries by name, ascending.
# a: The first element.
# b: The second element.
func _sort_name(a: Dictionary, b: Dictionary) -> bool:
	return a["name"] < b["name"]

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
		var file_name = file_path.get_basename().get_file()
		_file_name_edit.text = file_name
	else:
		# Let the player pick a save file to load.
		_file_name_edit.text = ""

func _on_delete_confirmed():
	if _context_file_entry.empty():
		return
	
	var save_path = save_dir + "/" + _context_file_entry["name"] + "." + save_ext
	
	var paths_to_delete = [save_path]
	if _context_file_entry.has("texture_path"):
		paths_to_delete.append(_context_file_entry["texture_path"])
	
	var dir = Directory.new()
	for path in paths_to_delete:
		if dir.file_exists(path):
			if dir.remove(path) != OK:
				push_error("Failed to delete the file '%s'!" % path)
		else:
			push_warning("File '%s' cannot be deleted, as it doesn't exist!" % path)
	
	refresh()

func _on_save_confirmed():
	var path = _get_file_path()
	if save_mode:
		emit_signal("save_file", path)
	else:
		emit_signal("load_file", path)
	
	visible = false

func _on_context_menu_id_pressed(id: int):
	if _context_file_entry.empty():
		return
	
	var file_name = _context_file_entry["name"]
	
	match id:
		CONTEXT_RENAME:
			_rename_line_edit.text = file_name
			_rename_window.popup_centered()
		
		CONTEXT_DUPLICATE:
			var old_base = save_dir + "/" + file_name
			var new_base = old_base + " (Copy)"
			
			var dir = Directory.new()
			for ext in [save_ext, "png"]:
				var old_path = old_base + "." + ext
				var new_path = new_base + "." + ext
				if dir.file_exists(old_path):
					if dir.copy(old_path, new_path) != OK:
						push_error("Failed to copy '%s' to '%s'!" % [old_path, new_path])
			
			refresh()
		
		CONTEXT_DELETE:
			_confirm_delete_dialog.dialog_text = tr("Are you sure you want to delete '%s'?") % file_name
			_confirm_delete_dialog.popup_centered()

func _on_load_save_button_pressed():
	var file_name = _file_name_edit.text + "." + save_ext
	if not file_name.is_valid_filename():
		_invalid_name_dialog.popup_centered()
		return
	
	var path = _get_file_path()
	var file = File.new()
	if save_mode and file.file_exists(path):
		var file_name_no_ext = path.get_basename().get_file()
		_confirm_overwrite_dialog.dialog_text = tr("The file '%s' already exists. Are you sure you want to overwrite it?") % file_name_no_ext
		_confirm_overwrite_dialog.popup_centered()
	else:
		_on_save_confirmed()

func _on_popup_hide():
	clear()

func _on_preview_clicked(preview: GenericPreview, event: InputEventMouseButton):
	if event.button_index == BUTTON_LEFT:
		var file_entry = preview.get_entry()
		_file_name_edit.text = file_entry["name"]
	elif event.button_index == BUTTON_RIGHT:
		_context_file_entry = preview.get_entry()
		_context_menu.rect_position = get_viewport().get_mouse_position()
		_context_menu.popup()

func _on_rename_pressed():
	var file_name = _rename_line_edit.text
	if not file_name.is_valid_filename():
		_invalid_name_dialog.popup_centered()
		return
	
	_rename_window.visible = false
	
	if _context_file_entry.empty():
		return
	
	var old_name = _context_file_entry["name"]
	var new_name = _rename_line_edit.text.strip_edges().strip_escapes()
	if new_name.empty():
		return
	
	var old_base = save_dir + "/" + old_name
	var new_base = save_dir + "/" + new_name
	
	var dir = Directory.new()
	for ext in [save_ext, "png"]:
		var old_path = old_base + "." + ext
		var new_path = new_base + "." + ext
		if dir.file_exists(old_path):
			if dir.rename(old_path, new_path) != OK:
				push_error("Failed to move '%s' to '%s'!" % [old_path, new_path])
	
	refresh()

func _on_sort_by_selected(_index: int):
	refresh()
