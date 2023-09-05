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

tool
extends EditorImportPlugin

## A plugin for the editor to import text files as [EditorTextFile].


func get_importer_name() -> String:
	return "editor.text.file.plugin"


func get_visible_name() -> String:
	return "Editor Text File"


func get_recognized_extensions() -> Array:
	return ["txt"]


func get_save_extension() -> String:
	return "res"


func get_resource_type() -> String:
	return "Resource"


func get_preset_count() -> int:
	return 1


func get_preset_name(_preset: int) -> String:
	return "Default"


func get_import_options(_preset: int) -> Array:
	return []


func import(source_file: String, save_path: String, options: Dictionary,
		platform_variants: Array, gen_files: Array) -> int:
	
	var text_res := EditorTextFile.new()
	
	var file := File.new()
	var err := file.open(source_file, File.READ)
	if err != OK:
		push_error("Failed to open '%s' (error: %d)" % [source_file, err])
		return err
	
	text_res.text = file.get_as_text()
	file.close()
	
	var full_save_path := save_path + "." + get_save_extension()
	return ResourceSaver.save(full_save_path, text_res)
