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

extends AttentionPanel

## A pop-up panel showing links to various websites related to Tabletop Club.


func _on_WebsiteButton_pressed():
	OS.shell_open("https://tabletopclub.net")


func _on_SourceCodeButton_pressed():
	OS.shell_open("https://github.com/drwhut/tabletop-club")


func _on_DocumentationButton_pressed():
	OS.shell_open("https://docs.tabletopclub.net")


func _on_FAQButton_pressed():
	OS.shell_open("https://docs.tabletopclub.net/en/stable/general/about.html#frequently-asked-questions")


func _on_NewsButton_pressed():
	OS.shell_open("https://tabletopclub.net/news")


func _on_CommunityButton_pressed():
	OS.shell_open("https://tabletopclub.net/community")


func _on_TranslationsButton_pressed():
	OS.shell_open("https://hosted.weblate.org/engage/tabletop-club/")


func _on_ReportIssueButton_pressed():
	OS.shell_open("https://github.com/drwhut/tabletop-club/issues")


func _on_ContributeButton_pressed():
	OS.shell_open("https://docs.tabletopclub.net/en/stable/general/contributing/ways_to_contribute.html")


func _on_BackButton_pressed():
	visible = false
