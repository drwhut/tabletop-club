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

extends WindowDialog

onready var _page_list = $HBoxContainer/ScrollContainer/PageListContainer/PageList
onready var _text_edit = $HBoxContainer/PageContainer/TextEdit
onready var _title_edit = $HBoxContainer/PageContainer/TitleEdit

const TIME_UNTIL_SAVE: float = 3.0

var pages: Array = []

var _last_page_seen = -1
var _last_update = 0.0
var _updating = false

func display_page(index: int) -> void:
	if index >= 0 and index < pages.size():
		_title_edit.editable = true
		_text_edit.readonly = false
		
		_page_list.select(index)
		_title_edit.text = _page_list.get_item_text(index)
		_text_edit.text = pages[index]
		
		_last_page_seen = index
	else:
		push_error("Invalid page index to display (%d)!" % index)

func _process(delta: float):
	if _updating:
		_last_update += delta
		if _last_update > TIME_UNTIL_SAVE:
			_save_current_page()

func _load_pages_from_file() -> void:
	var file = File.new()
	if file.file_exists("user://notebook.cfg"):
		file = ConfigFile.new()
		var error = file.load("user://notebook.cfg")
		if error == OK:
			var contents = file.get_value("Notebook", "pages", [])
			
			if contents is Array:
				_page_list.clear()
				pages.clear()
				for page in contents:
					_page_list.add_item(page["title"])
					pages.append(page["text"])
				
				if pages.size() > 0:
					if _last_page_seen >= 0 and _last_page_seen < pages.size():
						display_page(_last_page_seen)
					else:
						display_page(0)
				else:
					_title_edit.text = ""
					_title_edit.editable = false
					
					_text_edit.text = ""
					_text_edit.readonly = true
			else:
				push_error("Notebook file format is invalid!")
		else:
			push_error("Error loading notebook contents (error: %d)!" % error)

func _save_current_page() -> void:
	if _page_list.get_item_count() != pages.size():
		push_error("Page list count (%d) does not match in-script list (%d)!" %
				[_page_list.get_item_count(), pages.size()])
	
	_updating = false
	pages[_last_page_seen] = _text_edit.text
	
	var file_content = []
	for index in range(pages.size()):
		file_content.append({
			"title": _page_list.get_item_text(index),
			"text": pages[index]
		})
	
	var file = ConfigFile.new()
	file.set_value("Notebook", "pages", file_content)
	var error = file.save("user://notebook.cfg")
	if error != OK:
		push_error("Error saving notebook contents (error: %d)!" % error)

func _on_NewPageButton_pressed():
	if not pages.empty():
		_save_current_page()
	
	_page_list.add_item(tr("New Page"))
	pages.append("")
	display_page(pages.size() - 1)

func _on_NotebookDialog_about_to_show():
	_load_pages_from_file()

func _on_NotebookDialog_popup_hide():
	_save_current_page()

func _on_NotebookDialog_tree_exiting():
	_save_current_page()

func _on_PageList_item_selected(index: int):
	_save_current_page()
	display_page(index)

func _on_TextEdit_text_changed():
	_last_update = 0.0
	_updating = true

func _on_TitleEdit_text_changed(new_text: String):
	var selected = _page_list.get_selected_items()
	if selected.size() == 1:
		_last_update = 0.0
		_updating = true
		
		var index = selected[0]
		_page_list.set_item_text(index, new_text)
	else:
		push_error("Invalid number of pages selected (%d)!" % selected.size())
