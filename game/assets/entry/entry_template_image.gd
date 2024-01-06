# tabletop-club
# Copyright (c) 2020-2024 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2024 Tabletop Club contributors (see game/CREDITS.tres).
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

class_name AssetEntryTemplateImage
extends AssetEntryTemplate

## An asset entry for an image-based notebook template.
##
## Image-based templates are made up of an image in the background, with a list
## of textboxes in the foreground that the player can type into.


## A list of [TemplateTextbox] for the image template.
## TODO: Make typed in 4.x
export(Array, Resource) var textbox_list := []


## Load the [Texture] that [member template_path] points to. Returns
## [code]null[/code] if a texture does not exist at that path.
func load_image_template() -> Texture:
	if template_path.empty():
		return null
	
	return load(template_path) as Texture


func set_template_path(value: String) -> void:
	if not SanityCheck.is_valid_res_path(value,
			SanityCheck.VALID_EXTENSIONS_TEMPLATE_IMAGE):
		return
	
	template_path = value.simplify_path()
