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

extends WindowDialog

onready var _confirm_delete_dialog = $ConfirmDeleteDialog
onready var _delete_button = $HBoxContainer/PageContainer/ModifyContainer/DeleteButton
onready var _image_container = $HBoxContainer/PageContainer/ImageContainer
onready var _image_rect = $HBoxContainer/PageContainer/ImageContainer/ImageRect
onready var _modify_container = $HBoxContainer/PageContainer/ModifyContainer
onready var _move_down_button = $HBoxContainer/PageContainer/ModifyContainer/MoveDownButton
onready var _move_up_button = $HBoxContainer/PageContainer/ModifyContainer/MoveUpButton
onready var _new_page_button = $HBoxContainer/ScrollContainer/PageListContainer/NewPageButton
onready var _page_list = $HBoxContainer/ScrollContainer/PageListContainer/PageList
onready var _public_check_box = $HBoxContainer/PageContainer/TitleContainer/PublicCheckBox
onready var _template_dialog = $TemplateDialog
onready var _text_edit = $HBoxContainer/PageContainer/TextEdit
onready var _title_edit = $HBoxContainer/PageContainer/TitleContainer/TitleEdit
onready var _zoom_label = $HBoxContainer/PageContainer/ZoomContainer/ZoomLabel

const NOTEBOOK_FILE_PATH = "user://notebook.cfg"

const DEFAULT_FONT_SIZE = 16 # Text pages only.
const ZOOM_MAX = 5.0
const ZOOM_MIN = 0.1

const MAX_PAGE_ARRAY_NETWORK_SIZE = 50000 # 50 KB.
const REQUEST_PAGE_ARRAY_TIMEOUT_MS = 10000 # 10 seconds.
const UPDATE_TIME_UNTIL_SAVE_SEC = 3.0 # 3 seconds.

var current_page_array: Array = []

var _current_zoom: float = 1.0
var _base_image_scale: float = 1.0

var _has_entered_edit_mode: bool = false
var _page_on_display: int = -1
var _time_since_last_update: float = 0.0
var _updated_since_last_save: bool = false

var _client_page_array_expecting_from_server: Array = []
var _server_sending_arrays_to: Dictionary = {}

var _cache_array_for_server: Array = []
var _cache_array_is_invalid: bool = true

# Check whether the notebook is in edit mode or not.
# Returns: True if in edit mode, false if in view mode.
func is_in_edit_mode() -> bool:
	return _new_page_button.visible

# Popup the notebook window in edit mode.
func popup_edit_mode() -> void:
	var previous_page_on_display = _page_on_display
	if not _is_current_array_from_self():
		previous_page_on_display = 0
		current_page_array = _load_page_array_from_file()
	
	_set_window_title_with_name(get_tree().get_network_unique_id())
	_set_read_only(current_page_array.empty())
	_new_page_button.visible = true
	_modify_container.visible = true
	
	_display_page_list()
	if current_page_array.empty():
		_display_help_text()
		_page_on_display = -1
	else:
		_page_list.select(previous_page_on_display)
		_display_page_contents(previous_page_on_display)
		_set_modifier_buttons_enabled(previous_page_on_display)
	
	popup_centered()
	_has_entered_edit_mode = true

# Popup the notebook window in view mode.
# client_id: The ID of the client whose notebook to view.
func popup_view_mode(client_id: int) -> void:
	if client_id == get_tree().get_network_unique_id():
		push_warning("Cannot use notebook in view mode for self, ignoring.")
		return
	
	if not Lobby.player_exists(client_id):
		push_error("Player with ID %d does not exist in the lobby!" % client_id)
		return
	
	if _is_current_array_from_self():
		_attempt_save_page_array_to_file()
	
	# Hide the window until the details of the notebook have been received.
	visible = false
	
	if not _client_page_array_expecting_from_server.has(client_id):
		_client_page_array_expecting_from_server.append(client_id)
	rpc_id(1, "request_client_page_array", client_id)

# Called by the server when the client has sent their page array over.
# client_id: The ID of the client that the page array belongs to.
# client_page_array: The page array from the client we requested it from.
remotesync func receive_client_page_array(client_id: int, client_page_array: Array) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if not _client_page_array_expecting_from_server.has(client_id):
		push_warning("Unexpected page array of client %d from the server, ignoring." % client_id)
		return
	
	_client_page_array_expecting_from_server.erase(client_id)
	
	# Set the window to view mode.
	_set_window_title_with_name(client_id)
	_set_read_only(true)
	_new_page_button.visible = false
	_modify_container.visible = false
	
	_parse_page_array(client_page_array)
	current_page_array = client_page_array
	
	_display_page_list()
	if current_page_array.empty():
		_display_help_text()
		_page_on_display = -1
	else:
		_page_list.select(0)
		_display_page_contents(0)
	
	popup_centered()

# Request the server to retrieve another client's page array.
# client_id: The id of the client whose page array we want.
master func request_client_page_array(client_id: int) -> void:
	if not Lobby.player_exists(client_id):
		push_error("Cannot retrieve page array of player %d, player does not exist!" % client_id)
		return
	
	var send_id = get_tree().get_rpc_sender_id()
	if send_id == client_id:
		push_warning("Client attempting to retrieve their own page array, ignoring.")
		return
	
	if _server_sending_arrays_to.has(client_id):
		var sending_to: Dictionary = _server_sending_arrays_to[client_id]
		if sending_to.has(send_id):
			var last_request_time: int = sending_to[send_id]
			var time_since_last_request_ms = OS.get_ticks_msec() - last_request_time
			if time_since_last_request_ms > REQUEST_PAGE_ARRAY_TIMEOUT_MS:
				# Client did not respond in time, refresh the timer and try again.
				_server_sending_arrays_to[client_id][send_id] = OS.get_ticks_msec()
			else:
				# Client has yet to send us their page array, keep waiting.
				return
		else:
			# Keep track of when the request was made.
			_server_sending_arrays_to[client_id][send_id] = OS.get_ticks_msec()
	else:
		_server_sending_arrays_to[client_id] = { send_id: OS.get_ticks_msec() }
	
	rpc_id(client_id, "send_page_array_to_server")

# Called by the server when a client has requested our page array.
remotesync func send_page_array_to_server() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var page_array_to_use: Array = current_page_array
	if _is_current_array_from_self():
		_cache_array_for_server = []
		_cache_array_is_invalid = true
	else:
		if _cache_array_is_invalid:
			_cache_array_for_server = _load_page_array_from_file()
			_cache_array_is_invalid = false
		
		page_array_to_use = _cache_array_for_server
	
	# Only send public pages to the server.
	var size_of_data = 0
	var page_array_to_send: Array = []
	for page in page_array_to_use:
		if page["public"]:
			# There is a limit to how much data we can send over the network,
			# so if we are about to hit that limit, stop sending any more pages.
			var page_as_str = String(page)
			size_of_data += page_as_str.length()
			if size_of_data > MAX_PAGE_ARRAY_NETWORK_SIZE:
				break
			
			page_array_to_send.push_back(page)
	
	rpc_id(1, "send_response_to_requester", page_array_to_send)

# Send the client's page array to the server, who will then send it to whoever
# requested it.
# client_page_array: The client's page array.
master func send_response_to_requester(client_page_array: Array) -> void:
	var client_id = get_tree().get_rpc_sender_id()
	
	var expected_response = false
	if _server_sending_arrays_to.has(client_id):
		var potential_requesters: Dictionary = _server_sending_arrays_to[client_id]
		expected_response = not potential_requesters.empty()
		
		var send_to: int = -1
		for requester_id in potential_requesters.keys():
			var time_of_request: int = potential_requesters[requester_id]
			var time_since_request_ms = OS.get_ticks_msec() - time_of_request
			if time_since_request_ms <= REQUEST_PAGE_ARRAY_TIMEOUT_MS:
				send_to = requester_id
			else:
				_server_sending_arrays_to[client_id].erase(requester_id)
		
		if send_to > 0:
			if Lobby.player_exists(send_to):
				rpc_id(send_to, "receive_client_page_array", client_id,
						client_page_array)
			
			_server_sending_arrays_to[client_id].erase(send_to)
	
	if not expected_response:
		push_warning("Got page array response from client %d when not expecting one, ignoring." % client_id)
		return

func _process(delta: float):
	if _updated_since_last_save:
		_time_since_last_update += delta
		if _time_since_last_update > UPDATE_TIME_UNTIL_SAVE_SEC:
			_attempt_save_page_array_to_file()
			_time_since_last_update = 0.0

# A helper function for saving the contents of the page array if an update was
# detected.
func _attempt_save_page_array_to_file() -> void:
	if not _updated_since_last_save:
		return
	
	if _page_on_display >= 0:
		_save_text_to_current_array(_page_on_display)
	_save_page_array_to_file(current_page_array)

# Display help text to the UI for when there are no pages to display.
func _display_help_text() -> void:
	_title_edit.text = ""
	_public_check_box.set_pressed_no_signal(false)
	
	_text_edit.visible = true
	_image_container.visible = false
	if is_in_edit_mode():
		_text_edit.text = tr("You can use this notebook to write down information that will persist between sessions.")
	else:
		_text_edit.text = tr("This player does not have any public pages in their notebook.")
	
	_set_zoom(1.0)

# Display the given page contents on the UI.
# index: The index of the page in the current page array to display.
func _display_page_contents(index: int) -> void:
	if index < 0 or index >= current_page_array.size():
		push_error("Invalid page index %d!" % index)
		return
	
	var page: Dictionary = current_page_array[index]
	_title_edit.text = page["title"]
	_public_check_box.set_pressed_no_signal(page["public"])
	
	var image_path: String = ""
	var textbox_dict: Dictionary = {}
	var template_entry_path: String = page["template"]
	if not template_entry_path.empty():
		var template_entry = AssetDB.search_path(template_entry_path)
		if not template_entry.empty():
			var template_path: String = template_entry["template_path"]
			if template_path.get_extension() != "txt":
				image_path = template_path
				textbox_dict = template_entry["textboxes"]
	
	if image_path.empty():
		_text_edit.text = page["text"]
		
		_text_edit.visible = true
		_image_container.visible = false
	else:
		var texture: Texture = ResourceManager.load_res(image_path)
		_image_rect.texture = texture
		
		if texture.get_width() > 0:
			# By default, the full width of the image should be shown.
			_base_image_scale = _image_container.rect_size.x / texture.get_width()
		else:
			_base_image_scale = 1.0
		
		var textbox_id_arr = textbox_dict.keys()
		for index in range(textbox_dict.size()):
			var textbox_id: String = textbox_id_arr[index]
			var textbox_meta: Dictionary = textbox_dict[textbox_id]
			
			var num_lines: int = textbox_meta["lines"]
			var is_multiline: bool = (num_lines > 1)
			
			var need_new_node: bool = true
			if index < _image_rect.get_child_count():
				var node = _image_rect.get_child(index)
				
				if node is LineEdit and (not is_multiline):
					need_new_node = false
				elif node is TextEdit and is_multiline:
					need_new_node = false
			
			var textbox_edit: Control = null
			if need_new_node:
				if index < _image_rect.get_child_count():
					# There is a node here we need to... dispose of.
					var node: Node = _image_rect.get_child(index)
					if node is TextEdit:
						node.disconnect("text_changed", self, "_on_TextEdit_text_changed")
					elif node is LineEdit:
						node.disconnect("text_changed", self, "_on_LineEdit_text_changed")
					_image_rect.remove_child(node)
					node.queue_free()
				
				if is_multiline:
					textbox_edit = TextEdit.new()
					textbox_edit.wrap_enabled = true
					textbox_edit.connect("text_changed", self, "_on_TextEdit_text_changed")
				else:
					textbox_edit = LineEdit.new()
					textbox_edit.connect("text_changed", self, "_on_LineEdit_text_changed")
				
				var font: DynamicFont = preload("res://Fonts/Cabin/Cabin-Regular.tres")
				font = font.duplicate() # Allows for varying font sizes.
				textbox_edit.add_font_override("font", font)
				
				_image_rect.add_child(textbox_edit)
				_image_rect.move_child(textbox_edit, index)
			else:
				textbox_edit = _image_rect.get_child(index)
			
			textbox_edit.name = textbox_id
			textbox_edit.set_meta("textbox", textbox_meta)
			
			var text: String = page["text"][textbox_id]
			if textbox_edit is TextEdit:
				textbox_edit.text = text
				textbox_edit.readonly = _is_read_only()
			elif textbox_edit is LineEdit:
				textbox_edit.text = text
				textbox_edit.editable = not _is_read_only()
		
		for index in range(_image_rect.get_child_count()-1, textbox_dict.size()-1, -1):
			var to_remove: Node = _image_rect.get_child(index)
			if to_remove is TextEdit:
				to_remove.disconnect("text_changed", self, "_on_TextEdit_text_changed")
			elif to_remove is LineEdit:
				to_remove.disconnect("text_changed", self, "_on_LineEdit_text_changed")
			_image_rect.remove_child(to_remove)
			to_remove.queue_free()
		
		_text_edit.visible = false
		_image_container.visible = true
	
	_set_zoom(page["zoom"])
	_page_on_display = index

# Display the list of page names on the UI.
# NOTE: This function does not set one to be selected.
func _display_page_list() -> void:
	_page_list.clear()
	for page in current_page_array:
		_page_list.add_item(page["title"])

# Check if the current page array is of our own making.
# Returns: If the current array is our own.
func _is_current_array_from_self() -> bool:
	return _has_entered_edit_mode and is_in_edit_mode()

# Check if a page entry in a page array is valid.
# Returns: If the page entry is valid.
# page_entry: The entry to check. Note that it may be modified so it is valid.
func _is_page_entry_valid(page_entry: Dictionary) -> bool:
	if not page_entry.has("title"):
		push_error("Entry in page array has no title!")
		return false
	var page_title = page_entry["title"]
	if typeof(page_title) != TYPE_STRING:
		push_error("Page title in page array is not a string!")
		return false
	page_title = page_title.substr(0, _title_edit.max_length)
	
	if page_entry.has("public"):
		var page_public = page_entry["public"]
		if typeof(page_public) != TYPE_BOOL:
			push_error("Public field in page array is not a boolean!")
			return false
	else:
		page_entry["public"] = false
	
	if page_entry.has("template"):
		var page_template = page_entry["template"]
		if typeof(page_template) != TYPE_STRING:
			push_error("Page template in the page array is not a string!")
			return false
	else:
		page_entry["template"] = ""
	
	var page_template: String = page_entry["template"]
	var template_entry: Dictionary = {}
	var is_image_template: bool = false
	
	# Allow for blank page template entries for backwards-compatibility.
	if not page_template.empty():
		template_entry = AssetDB.search_path(page_template)
		if template_entry.empty():
			push_warning("Missing template '%s' for page '%s'." % [
					page_template, page_title])
		else:
			var template_path: String = template_entry["template_path"]
			is_image_template = (template_path.get_extension() != "txt")
	
	if not page_entry.has("text"):
		push_error("Entry in page array has no text!")
		return false
	var page_text = page_entry["text"]
	if typeof(page_text) == TYPE_STRING:
		if is_image_template:
			# We have a single string of text, but we need a dictionary of
			# strings - we can attempt to recover the full dictionary if the
			# string happens to be in JSON form, but otherwise we can dump all
			# of the text into the first textbox.
			var textbox_dict: Dictionary = template_entry["textboxes"]
			
			var new_text: Dictionary = {}
			for id in textbox_dict:
				var default_val: String = textbox_dict[id]["text"]
				new_text[id] = default_val
			
			var json: JSONParseResult = JSON.parse(page_text)
			if json.error == OK and json.result is Dictionary:
				for id in textbox_dict:
					if not json.result.has(id):
						continue
					
					var value = json.result[id]
					if not value is String:
						continue
					
					new_text[id] = value
			
			elif not textbox_dict.empty():
				var first_id: String = textbox_dict.keys()[0]
				new_text[first_id] = page_text
			
			page_entry["text"] = new_text
	elif typeof(page_text) == TYPE_DICTIONARY:
		for key in page_text:
			if not page_text[key] is String:
				push_error("Page text element '%s' is not a string!" % key)
				return false
		
		if is_image_template:
			var remaining_keys: Array = page_text.keys()
			
			var textbox_dict: Dictionary = template_entry["textboxes"]
			for textbox_id in textbox_dict:
				if remaining_keys.has(textbox_id):
					remaining_keys.erase(textbox_id)
				else:
					push_warning("Textbox '%s' is missing from page." % textbox_id)
					var default_val: String = textbox_dict[textbox_id]["text"]
					page_text[textbox_id] = default_val
			
			for key in remaining_keys:
				push_warning("Textbox '%s' is no longer used in page, removing." % key)
				page_text.erase(key)
		else:
			# The text we have is in a dictionary, but we need a single string.
			# For this, we can convert the dictionary into a JSON string, and
			# hope that in the future the template will be restored so the JSON
			# can be parsed back into a dictionary.
			page_entry["text"] = JSON.print(page_text)
	else:
		push_error("Page text in page array is neither a string or dictionary!")
		return false
	
	if page_entry.has("zoom"):
		var zoom = page_entry["zoom"]
		if typeof(zoom) != TYPE_REAL:
			push_error("Zoom in the page array is not a float!")
			return false
		
		zoom = min(max(ZOOM_MIN, zoom), ZOOM_MAX)
		zoom = round(10.0 * zoom) / 10.0
		page_entry["zoom"] = zoom
	else:
		page_entry["zoom"] = 1.0
	
	return true

# Check if the window is in read-only mode.
# Returns: If the window is in read-only mode.
func _is_read_only() -> bool:
	return _text_edit.readonly

# Load the contents of the notebook.cfg file into a page array.
# Returns: The page array from the file.
func _load_page_array_from_file() -> Array:
	var check_file = File.new()
	if not check_file.file_exists(NOTEBOOK_FILE_PATH):
		return []
	
	var notebook_file = ConfigFile.new()
	var err = notebook_file.load(NOTEBOOK_FILE_PATH)
	if err != OK:
		push_error("Failed to open '%s'! (error %d)" % [NOTEBOOK_FILE_PATH, err])
		return []
	
	var file_page_array = notebook_file.get_value("Notebook", "pages", [])
	if typeof(file_page_array) != TYPE_ARRAY:
		push_error("Data in notebook.cfg is not an array!")
		return []
	
	_parse_page_array(file_page_array)
	return file_page_array

# Parse a given page array to make sure all of the entries are valid.
# page_array: The page array to check. Note that the array may be modified.
func _parse_page_array(page_array: Array) -> void:
	for index in range(page_array.size() - 1, -1, -1):
		var page_data = page_array[index]
		
		var page_valid = false
		if page_data is Dictionary:
			if _is_page_entry_valid(page_data):
				page_valid = true
		
		if not page_valid:
			page_array.remove(index)

# Save the current page array to the notebook.cfg file.
# page_array: The page array to save to disk.
func _save_page_array_to_file(page_array: Array) -> void:
	var notebook_file = ConfigFile.new()
	notebook_file.set_value("Notebook", "pages", page_array)
	
	var err = notebook_file.save(NOTEBOOK_FILE_PATH)
	if err == OK:
		_updated_since_last_save = false
		
		_cache_array_for_server = []
		_cache_array_is_invalid = true
	else:
		push_error("Failed to save to '%s'! (error: %d)" % [NOTEBOOK_FILE_PATH, err])

# Save the current text to the corresponding entry in the page array.
# index: The index of the page to save the text to.
func _save_text_to_current_array(index: int) -> void:
	if index < 0 or index >= current_page_array.size():
		push_error("Invalid page index %d!" % index)
		return
	
	var is_image_page: bool = false
	var template_entry_path: String = current_page_array[index]["template"]
	if not template_entry_path.empty():
		var template_entry = AssetDB.search_path(template_entry_path)
		if not template_entry.empty():
			var template_path: String = template_entry["template_path"]
			is_image_page = (template_path.get_extension() != "txt")
	
	if is_image_page:
		var text_dict = {}
		for text_edit in _image_rect.get_children():
			if text_edit is LineEdit or text_edit is TextEdit:
				text_dict[text_edit.name] = text_edit.text
		current_page_array[index]["text"] = text_dict
	else:
		current_page_array[index]["text"] = _text_edit.text

# Set the scale of the image and it's children text nodes.
# scale: The new scale relative to the original scale.
func _set_image_scale(scale: float) -> void:
	var texture: Texture = _image_rect.texture
	var new_size: Vector2 = scale * texture.get_size()
	_image_rect.rect_min_size = new_size
	_image_rect.rect_size = new_size
	
	for index in range(_image_rect.get_child_count()):
		var textbox_edit: Control = _image_rect.get_child(index)
		
		if not textbox_edit.has_meta("textbox"):
			push_error("Textbox %s has no metadata assigned!" % textbox_edit.name)
			continue
		var textbox_meta: Dictionary = textbox_edit.get_meta("textbox")
		
		var font: DynamicFont = textbox_edit.get_font("font")
		var style: StyleBox = textbox_edit.get_stylebox("normal")
		var box_min_size: Vector2 = style.get_minimum_size()
		
		var rot_deg: float = textbox_meta["rot"]
		textbox_edit.rect_rotation = rot_deg
		
		# Vast majority of textboxes will not be rotated, so we can try to skip
		# some calculations.
		var rot_transform: Transform2D = Transform2D.IDENTITY
		if not is_zero_approx(rot_deg):
			rot_transform = Transform2D(deg2rad(rot_deg), Vector2.ZERO)
		
		var max_pos = new_size - box_min_size
		var x = max(0.0, min(scale * textbox_meta["x"], max_pos.x))
		var y = max(0.0, min(scale * textbox_meta["y"], max_pos.y))
		var pos = Vector2(x, y)
		
		var w = max(0.0, textbox_meta["w"])
		var h = max(0.0, textbox_meta["h"])
		var scaled_size = scale * Vector2(w, h)
		var to_opposite: Vector2 = scaled_size
		if not is_zero_approx(rot_deg):
			to_opposite = rot_transform.basis_xform(scaled_size)
		var opposite_pos = pos + to_opposite
		
		var will_correct_scale = false
		var new_to_opposite = to_opposite
		
		if opposite_pos.x < 0.0:
			new_to_opposite.x = -x
			will_correct_scale = true
		elif opposite_pos.x > new_size.x:
			new_to_opposite.x = new_size.x - x
			will_correct_scale = true
		
		if opposite_pos.y < 0.0:
			new_to_opposite.y = -y
			will_correct_scale = true
		elif opposite_pos.y > new_size.y:
			new_to_opposite.y = new_size.y - y
			will_correct_scale = true
		
		if will_correct_scale:
			if is_zero_approx(rot_deg):
				scaled_size = new_to_opposite
			else:
				scaled_size = rot_transform.basis_xform_inv(new_to_opposite)
		
		# Estimate how big the font can be before it starts expanding the
		# size of the textbox.
		var num_lines: int = textbox_meta["lines"]
		var font_height = float(scaled_size.y - box_min_size.y) / num_lines
		if textbox_edit is TextEdit:
			font_height -= textbox_edit.get_constant("line_spacing")
		font.size = int(max(1.0, ceil(0.65 * font_height)))
		
		textbox_edit.rect_position = pos
		textbox_edit.rect_size = scaled_size

# Set the modifier buttons to be enabled or not depending on the given index.
# index: The current page index. If negative, all buttons are disabled.
func _set_modifier_buttons_enabled(index: int) -> void:
	if index < 0:
		_move_up_button.disabled = true
		_move_down_button.disabled = true
		return
	
	_move_up_button.disabled = (index == 0)
	_move_down_button.disabled = (index >= current_page_array.size() - 1)

# Set the window to be in read-only mode or not.
# read_only: If the window should be in read-only mode.
func _set_read_only(read_only: bool) -> void:
	_title_edit.editable = not read_only
	_public_check_box.disabled = read_only
	_text_edit.readonly = read_only
	
	_move_up_button.disabled = read_only
	_move_down_button.disabled = read_only
	_delete_button.disabled = read_only
	
	for text_edit in _image_rect.get_children():
		if text_edit is LineEdit:
			text_edit.editable = not read_only
		elif text_edit is TextEdit:
			text_edit.readonly = read_only

# Set the window title based on the client's name.
# client_id: The ID of the client whose name will be in the title.
func _set_window_title_with_name(client_id: int) -> void:
	var client_name: String = tr("<Unknown>")
	if Lobby.player_exists(client_id):
		var player_meta: Dictionary = Lobby.get_player(client_id)
		
		# From Lobby.get_name_bb_code, but just for the name.
		client_name = player_meta["name"].strip_edges().strip_escapes()
		if client_name.empty():
			client_name = tr("<No Name>")
		elif Global.censoring_profanity:
			client_name = Global.censor_profanity(client_name)
	
	window_title = tr("%s's Notebook") % client_name

# Set the window's zoom scale.
# new_zoom: The new zoom scale, e.g. 1.0 is the default view.
func _set_zoom(new_zoom: float) -> void:
	_current_zoom = new_zoom
	_zoom_label.text = "%d%%" % int(round(100.0 * new_zoom))
	
	if _text_edit.visible:
		var font: DynamicFont = _text_edit.get_font("font")
		font.size = int(DEFAULT_FONT_SIZE * new_zoom)
		_text_edit.text = _text_edit.text # Force word wrap.
	else:
		_set_image_scale(_base_image_scale * new_zoom)

func _on_ConfirmDeleteDialog_confirmed():
	if _page_on_display < 0 or _page_on_display >= current_page_array.size():
		push_error("_page_on_display value (%d) is invalid!" % _page_on_display)
		return
	
	current_page_array.remove(_page_on_display)
	_page_list.remove_item(_page_on_display)
	
	var no_pages_left = current_page_array.empty()
	_set_read_only(no_pages_left)
	
	if no_pages_left:
		_display_help_text()
		_page_on_display = -1
	else:
		var new_index = max(0, _page_on_display - 1)
		_page_list.select(new_index)
		_display_page_contents(new_index)
		_set_modifier_buttons_enabled(new_index)
	
	_updated_since_last_save = true
	_time_since_last_update = 0.0

func _on_DeleteButton_pressed():
	if _page_on_display < 0 or _page_on_display >= current_page_array.size():
		push_error("_page_on_display value (%d) is invalid!" % _page_on_display)
		return
	
	var page_name: String = current_page_array[_page_on_display]["title"]
	var text = tr("Are you sure you want to delete the page '%s'?") % page_name
	_confirm_delete_dialog.dialog_text = text
	_confirm_delete_dialog.popup_centered()

func _on_ImageContainer_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		var ctrl = event.command if OS.get_name() == "OSX" else event.control
		if ctrl and event.pressed:
			# Make sure the scroll container does not scroll the contents if we
			# want to zoom in and out.
			_image_container.set_enable_v_scroll(false)
			
			if event.button_index == BUTTON_WHEEL_UP:
				_on_ZoomInButton_pressed()
			elif event.button_index == BUTTON_WHEEL_DOWN:
				_on_ZoomOutButton_pressed()
			
			_image_container.call_deferred("set_enable_v_scroll", true)

func _on_LineEdit_text_changed(_text: String):
	_updated_since_last_save = true
	_time_since_last_update = 0.0

func _on_MoveDownButton_pressed():
	_page_list.move_item(_page_on_display, _page_on_display + 1)
	
	var swap_page: Dictionary = current_page_array[_page_on_display]
	current_page_array[_page_on_display] = current_page_array[_page_on_display + 1]
	current_page_array[_page_on_display + 1] = swap_page
	
	_page_on_display += 1
	_set_modifier_buttons_enabled(_page_on_display)
	
	_updated_since_last_save = true
	_time_since_last_update = 0.0

func _on_MoveUpButton_pressed():
	_page_list.move_item(_page_on_display, _page_on_display - 1)
	
	var swap_page: Dictionary = current_page_array[_page_on_display]
	current_page_array[_page_on_display] = current_page_array[_page_on_display - 1]
	current_page_array[_page_on_display - 1] = swap_page
	
	_page_on_display -= 1
	_set_modifier_buttons_enabled(_page_on_display)
	
	_updated_since_last_save = true
	_time_since_last_update = 0.0

func _on_NewPageButton_pressed():
	_template_dialog.popup_centered()

func _on_NotebookDialog_popup_hide():
	if _is_current_array_from_self():
		_attempt_save_page_array_to_file()

func _on_NotebookDialog_tree_exiting():
	if _is_current_array_from_self():
		_attempt_save_page_array_to_file()

func _on_PageList_item_selected(index: int):
	if _is_current_array_from_self():
		_attempt_save_page_array_to_file()
	_display_page_contents(index)
	_set_modifier_buttons_enabled(index)

func _on_PublicCheckBox_toggled(button_pressed: bool):
	if _page_on_display < 0 or _page_on_display >= current_page_array.size():
		push_error("_page_on_display value (%d) is invalid!" % _page_on_display)
		return
	
	current_page_array[_page_on_display]["public"] = button_pressed
	
	_updated_since_last_save = true
	_time_since_last_update = 0.0

func _on_TemplateDialog_entry_requested(_pack: String, _type: String, entry: Dictionary):
	_template_dialog.visible = false
	
	# Save the text on the previous page.
	if not current_page_array.empty():
		_attempt_save_page_array_to_file()
	
	var template_entry_path: String = entry["entry_path"]
	var template_file_path: String  = entry["template_path"]
	
	var locale = TranslationServer.get_locale()
	var name_locale = "name_" + locale
	
	var template_name: String = entry["name"]
	if entry.has(name_locale):
		template_name = entry[name_locale]
	var page_title = tr("New %s") % template_name
	
	var page_entry: Dictionary = {
		"title": page_title,
		"public": false,
		"template": template_entry_path,
		"text": "",
		"zoom": 1.0
	}
	
	if template_file_path.get_extension() == "txt":
		var template_file = File.new()
		if template_file.file_exists(template_file_path):
			var err = template_file.open(template_file_path, File.READ)
			if err == OK:
				var default_text: String = template_file.get_as_text()
				template_file.close()
				
				# Check for invalid characters!
				for i in range(default_text.length() - 1, -1, -1):
					if default_text.ord_at(i) == 0:
						default_text.erase(i, 1)
				
				page_entry["text"] = default_text
			else:
				push_error("Failed to open '%s' (error: %d)" % [template_file_path, err])
		else:
			push_error("File '%s' does not exist!" % template_file_path)
	else:
		var default_dict: Dictionary = {}
		var textbox_dict: Dictionary = entry["textboxes"]
		
		for textbox_id in textbox_dict:
			var default_val: String = textbox_dict[textbox_id]["text"]
			default_dict[textbox_id] = default_val
		
		page_entry["text"] = default_dict
	
	current_page_array.push_back(page_entry)
	_page_list.add_item(page_title)
	
	_set_read_only(false)
	
	var new_index = current_page_array.size() - 1
	_page_list.select(new_index)
	_display_page_contents(new_index)
	_set_modifier_buttons_enabled(new_index)
	
	_updated_since_last_save = true
	_time_since_last_update = 0.0

func _on_TextEdit_text_changed():
	_updated_since_last_save = true
	_time_since_last_update = 0.0

func _on_TitleEdit_text_changed(new_text: String):
	if _page_on_display < 0 or _page_on_display >= current_page_array.size():
		push_error("_page_on_display value (%d) is invalid!" % _page_on_display)
		return
	
	current_page_array[_page_on_display]["title"] = new_text
	_page_list.set_item_text(_page_on_display, new_text)
	
	_updated_since_last_save = true
	_time_since_last_update = 0.0

func _on_ZoomInButton_pressed():
	var new_zoom = _current_zoom + 0.1
	new_zoom = min(round(10.0 * new_zoom) / 10.0, ZOOM_MAX)
	_set_zoom(new_zoom)
	
	# Need to check if the array is ours since we can also zoom in and out when
	# in view mode.
	if _page_on_display >= 0 and _is_current_array_from_self():
		current_page_array[_page_on_display]["zoom"] = new_zoom
		_updated_since_last_save = true
		_time_since_last_update = 0.0

func _on_ZoomOutButton_pressed():
	var new_zoom = _current_zoom - 0.1
	new_zoom = max(round(10.0 * new_zoom) / 10.0, ZOOM_MIN)
	_set_zoom(new_zoom)
	
	if _page_on_display >= 0 and _is_current_array_from_self():
		current_page_array[_page_on_display]["zoom"] = new_zoom
		_updated_since_last_save = true
		_time_since_last_update = 0.0
