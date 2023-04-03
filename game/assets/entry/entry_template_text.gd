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

class_name AssetEntryTemplateText
extends AssetEntryTemplate

## An asset entry for a text-based notebook template.
##
## A text-based template is essentially a text file that is copied to the page
## when it is loaded.


## Load the entire text file that [member template_path] points to. Returns an
## empty string if the text file could not be found, or if there was an error
## opening the file.
func load_text_template() -> String:
	if template_path.empty():
		return ""
	
	var template_file := File.new()
	var err := template_file.open(template_path, File.READ)
	if err != OK:
		push_error("Could not open '%s' (error %d)" % [template_path, err])
		return ""
	
	var contents := template_file.get_as_text()
	template_file.close()
	
	return contents


func set_template_path(value: String) -> void:
	if not SanityCheck.is_valid_res_path(value,
			SanityCheck.VALID_EXTENSIONS_TEMPLATE_TEXT):
		return
	
	template_path = value.simplify_path()
