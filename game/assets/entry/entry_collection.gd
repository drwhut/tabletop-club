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

class_name AssetEntryCollection
extends AssetEntry

## An asset entry that references a list of other entries.
##
## This class is used to build objects that are made up of multiple objects,
## for example, [PieceStack].


## The list of entry references that make up this collection.
## TODO: export(Array, AssetEntrySingle), make typed array in 4.x
export(Array, Resource) var entry_list := []


## Get the list of asset types included within the collection.
## Note that in the majority of cases, a valid collection will only have one
## type of asset.
func get_included_types() -> Array:
	var types_found := []
	for entry in entry_list:
		if not types_found.has(entry.type):
			types_found.push_back(entry.type)
	return types_found


## If the collection is only made up of one type of entry, then return the type.
## Otherwise, return an empty string.
func get_single_type() -> String:
	var included_types := get_included_types()
	if included_types.size() == 1:
		return included_types[0]
	
	return ""


## Get the number of entries in the collection.
func get_size() -> int:
	return entry_list.size()


## Check if the collection is empty, as this is invalid.
func is_empty() -> bool:
	return entry_list.empty()
