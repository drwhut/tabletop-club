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

class_name AssetEntry
extends ResourceWithErrors

## Base class for all of the entries in the AssetDB.
##
## Asset entries contain the metadata for custom assets that are imported by
## the game. Once an asset entry has been created, it can then be added to an
## [AssetPack], which itself can be added to the AssetDB.


## The string used to identify this entry among others of the same type within
## an asset pack.
export(String) var id := "_" setget set_id

## A custom description for the asset.
export(String, MULTILINE) var desc := ""

## The name of the [AssetPack] this entry belongs to, empty if the entry is not
## in a pack.
export(String) var pack := "TabletopClub" setget set_pack

## The type of the entry within the [AssetPack], empty if the entry is not in a
## pack.
export(String) var type := ""

## The display name of the asset. This can differ from [member id], for example
## if the name has been translated to another language. If set with an empty
## string, [member id] is returned instead.
var name := "" setget set_name, get_name

## A flag for whether the entry is temporary, for example, if it was provided
## by the host.
var temp := false


## Compare two entries using their ID, and return if the first comes before the
## second in a sorted list.
static func compare_entries(a: AssetEntry, b: AssetEntry) -> bool:
	return a.id < b.id


func get_name() -> String:
	return id if name.empty() else name


## Get the full AssetDB path for this entry, or return an empty string if it is
## not in an asset pack.
func get_path() -> String:
	if pack.empty() or type.empty():
		return ""
	
	return pack + "/" + type + "/" + id


func set_id(value: String) -> void:
	value = value.strip_edges().strip_escapes()
	
	if value.empty():
		push_error("ID is empty")
		return
	
	if not value.is_valid_filename():
		push_error("ID is invalid")
		return
	
	id = value


func set_name(value: String) -> void:
	value = value.strip_edges().strip_escapes()
	
	if not value.empty():
		if not value.is_valid_filename():
			push_error("Name is invalid")
			return
	
	name = value


func set_pack(value: String) -> void:
	if "/" in value:
		push_error("Pack name cannot contain '/' character")
		return
	
	pack = value
