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

extends AttentionPanel

## A panel showing credits for those that have helped make the game.


onready var _credits_label := $MarginContainer/CreditsLabel


func _ready():
	var credits_text = preload("res://CREDITS.txt").text
	
	credits_text = credits_text.replace("ALPHA TESTERS", tr("Alpha Testers"))
	credits_text = credits_text.replace("CONTRIBUTORS", tr("Contributors"))
	credits_text = credits_text.replace("CURSORS", tr("Cursors"))
	credits_text = credits_text.replace("DEVELOPERS", tr("Developers"))
	credits_text = credits_text.replace("FONTS", tr("Fonts"))
	credits_text = credits_text.replace("IMAGES", tr("Images"))
	credits_text = credits_text.replace("LOGO AND ICON", tr("Logo and Icon"))
	credits_text = credits_text.replace("SOUND EFFECTS", tr("Sound Effects"))
	credits_text = credits_text.replace("TOOL ICONS", tr("Tool Icons"))
	credits_text = credits_text.replace("TRANSLATORS", tr("Translators"))
	
	credits_text = credits_text.replace("DUTCH", tr("Dutch"))
	credits_text = credits_text.replace("ESPERANTO", tr("Esperanto"))
	credits_text = credits_text.replace("FRENCH", tr("French"))
	credits_text = credits_text.replace("GERMAN", tr("German"))
	credits_text = credits_text.replace("ITALIAN", tr("Italian"))
	credits_text = credits_text.replace("PORTUGUESE", tr("Portuguese"))
	credits_text = credits_text.replace("RUSSIAN", tr("Russian"))
	credits_text = credits_text.replace("SPANISH", tr("Spanish"))
	
	var credits_lines = credits_text.split("\n")
	
	for i in range(credits_lines.size() - 1, -1, -1):
		var line = credits_lines[i]
		if line.begins_with("-"):
			credits_lines[i - 1] = "[i]" + credits_lines[i - 1] + "[/i]"
			credits_lines.remove(i)
		elif line.begins_with("="):
			credits_lines[i - 1] = "[u]" + credits_lines[i - 1] + "[/u]"
			credits_lines.remove(i)
	
	_credits_label.bbcode_text = "[center]"
	for line in credits_lines:
		_credits_label.bbcode_text += line + "\n"
	_credits_label.bbcode_text += "[/center]"


func _on_BackButton_pressed():
	visible = false
