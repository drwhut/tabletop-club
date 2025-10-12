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

onready var _advanced_check_button = $VBox/AdvancedCheckButton
onready var _details_label = $VBox/DetailsLabel

var _text_advanced: String
var _text_basic: String

# Show the details dialog with information about the given pieces.
# piece_arr: An array of piece references.
func show_details(piece_arr: Array) -> void:
	_text_advanced = _generate_advanced_text(piece_arr)
	_text_basic = _generate_basic_text(piece_arr)
	
	if _advanced_check_button.pressed:
		_details_label.bbcode_text = _text_advanced
	else:
		_details_label.bbcode_text = _text_basic
	
	popup_centered()

# Generate a string of advanced text to display in the dialog.
# Returns: The BBCode text to display.
# piece_arr: An array of piece references that the text is based on.
func _generate_advanced_text(piece_arr: Array) -> String:
	var text = ""
	
	for piece in piece_arr:
		text += "[%s] %s\n" % [piece.name,
				JSON.print(piece.piece_entry, "\t", true)]
	
	return text

# Generate a string of basic text to display in the dialog.
# Returns: The BBCode text to display.
# piece_arr: An array of piece references that the text is based on.
func _generate_basic_text(piece_arr: Array) -> String:
	if piece_arr.empty():
		return tr("No objects have been selected.")
	
	var text = ""
	if piece_arr.size() == 1:
		var piece: Piece = piece_arr[0]
		var piece_entry = piece.piece_entry
		var secret = _is_piece_secret(piece)
		
		if piece is Stack:
			if secret:
				return "???"
			
			if piece.is_card_stack():
				return tr("A stack of %d cards.") % piece.get_piece_count()
			else:
				return tr("A stack of %d tokens.") % piece.get_piece_count()
		
		var piece_name = "???" if secret else _get_tr_property(piece_entry, "name")
		text += "[b][u]%s[/u][/b]\n" % piece_name
		
		var piece_desc = "???" if secret else _get_tr_property(piece_entry, "desc")
		if piece_desc.empty():
			piece_desc = tr("No description.")
		text += piece_desc + "\n\n"
		
		var author: String = "???" if secret else piece_entry["author"]
		if not author.empty():
			text += tr("Author: %s") % author + "\n"
		
		var license: String = "???" if secret else piece_entry["license"]
		if not license.empty():
			text += tr("License: %s") % license + "\n"
		
		var modified_by: String = "???" if secret else piece_entry["modified_by"]
		if not modified_by.empty():
			text += tr("Modified by: %s") % modified_by + "\n"
		
		var url: String = "???" if secret else piece_entry["url"]
		if not url.empty():
			text += tr("URL: %s") % url + "\n"
	else:
		text += tr("A total of %d objects were selected:") % piece_arr.size()
		text += "\n\n"
		
		for piece in piece_arr:
			text += "- "
			
			if _is_piece_secret(piece):
				text += "???"
			elif piece is Stack:
				if piece.is_card_stack():
					text += tr("Stack of %d cards") % piece.get_piece_count()
				else:
					text += tr("Stack of %d tokens") % piece.get_piece_count()
			else:
				text += _get_tr_property(piece.piece_entry, "name")
			
			text += "\n"
	
	return text

# Get the translated property of a piece entry, or just the regular property if
# a translated version does not exist.
# TODO: Since this is also done elsewhere in the UI, maybe it's worth putting
# this in the Piece class, or in a separate utility class?
# Returns: The translated property.
# piece_entry: The entry to get the property from.
# key: The key associated with the property.
func _get_tr_property(piece_entry: Dictionary, key: String) -> String:
	var locale = TranslationServer.get_locale()
	var key_locale = "%s_%s" % [key, locale]
	if piece_entry.has(key_locale):
		return piece_entry[key_locale]
	elif piece_entry.has(key):
		return piece_entry[key]
	else:
		push_error("Key '%s' does not exist in piece entry!" % key)
		return ""

# Check if the details of a given piece should be secret.
# Returns: If the piece should be kept secret.
# piece: The piece to check.
func _is_piece_secret(piece: Piece) -> bool:
	if piece is Card:
		var hand_id_arr = piece.over_hands
		if not hand_id_arr.empty():
			return not hand_id_arr.has(get_tree().get_network_unique_id())
	
	return false

func _on_AdvancedCheckButton_toggled(button_pressed: bool):
	if button_pressed:
		_details_label.bbcode_text = _text_advanced
	else:
		_details_label.bbcode_text = _text_basic
