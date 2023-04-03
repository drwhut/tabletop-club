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

extends GutTest

## Test scripts related to custom assets.


func test_asset_entries() -> void:
	var entry := AssetEntry.new()
	
	# id
	assert_eq(entry.id, "_")
	entry.id = "Test"
	assert_eq(entry.id, "Test")
	entry.id = "   Test   "
	assert_eq(entry.id, "Test")
	entry.id = "Test\n    "
	assert_eq(entry.id, "Test")
	entry.id = "" # Cannot be empty.
	assert_eq(entry.id, "Test")
	entry.id = "    \n\n  " # Cannot be empty.
	assert_eq(entry.id, "Test")
	entry.id = "Test/Subtest" # Must be a valid file name.
	assert_eq(entry.id, "Test")
	entry.id = "Test?" # Must be a valid file name.
	assert_eq(entry.id, "Test")
	entry.id = "Test*" # Must be a valid file name.
	assert_eq(entry.id, "Test")
	
	# name
	assert_eq(entry.name, "Test")
	entry.name = "Test2"
	assert_eq(entry.name, "Test2")
	entry.name = ""
	assert_eq(entry.name, "Test")
	entry.name = "    \n\t  "
	assert_eq(entry.name, "Test")
	entry.name = "/Test/" # Must be a valid file name.
	assert_eq(entry.name, "Test")
	
	# pack, type, get_path
	assert_eq(entry.pack, "")
	assert_eq(entry.type, "")
	assert_eq(entry.get_path(), "")
	
	entry.pack = "PackA"
	assert_eq(entry.pack, "PackA")
	entry.pack = "PackA/SubPack" # No '/' allowed in pack.
	assert_eq(entry.pack, "PackA")
	assert_eq(entry.get_path(), "")
	
	entry.type = "cards"
	assert_eq(entry.get_path(), "PackA/cards/Test")
	entry.type = "dice"
	assert_eq(entry.get_path(), "PackA/dice/Test")
	entry.pack = "PackB"
	assert_eq(entry.get_path(), "PackB/dice/Test")
