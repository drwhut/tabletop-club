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

class_name ExternalDirectory
extends Reference

## Used to access the player's Documents folder.
##
## This folder is used as a convenient way for players to be able to add custom
## assets to the game, as well as to store save files and screenshots. If for
## whatever reason the folder cannot be accessed (e.g. due to insufficient
## permissions), then a fallback folder is used in the [code]user://[/code]
## directory.


## The path of the fallback directory.
const FALLBACK_DIR_PATH := "user://user"


## Open a sub-directory within the external directory. If it does not already
## exist, it is created.
static func open_sub_dir(sub_dir: String) -> Directory:
	var external_dir := get_external_dir()
	if not external_dir.dir_exists(sub_dir):
		var err := external_dir.make_dir(sub_dir)
		if err != OK:
			push_error("Failed to create directory at '%s' (error: %d)" % [
					external_dir.get_current_dir().plus_file(sub_dir), err])
	
	var err := external_dir.change_dir(sub_dir)
	if err != OK:
		push_error("Failed to change directory to '%s' (error: %d)" % [
				external_dir.get_current_dir().plus_file(sub_dir), err])
	
	return external_dir


## Get the external directory as a [Directory]. It is created if it does not
## already exist. If it cannot be opened, the fallback directory is returned
## instead.
static func get_external_dir() -> Directory:
	var external_dir := Directory.new()
	var documents_path := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var external_path := documents_path.plus_file("TabletopClub")
	
	if not external_dir.dir_exists(external_path):
		var err := external_dir.make_dir(external_path)
		if err != OK:
			push_warning("Failed to create external directory at '%s' (error: %d), using fallback directory instead" % [
					external_path, err])
			return get_fallback_dir()
	
	var err := external_dir.open(external_path)
	if err != OK:
		push_warning("Failed to open external directory at '%s' (error: %d), using fallback directory instead" % [
				external_path, err])
		return get_fallback_dir()
	
	return external_dir


## Get the fallback directory as a [Directory].
static func get_fallback_dir() -> Directory:
	var fallback_dir := Directory.new()
	if not fallback_dir.dir_exists(FALLBACK_DIR_PATH):
		var err := fallback_dir.make_dir(FALLBACK_DIR_PATH)
		if err != OK:
			push_error("Failed to create fallback directory at '%s' (error: %d)" % [
					FALLBACK_DIR_PATH, err])
	
	var err := fallback_dir.open(FALLBACK_DIR_PATH)
	if err != OK:
		push_error("Failed to open fallback directory at '%s' (error: %d)" % [
				FALLBACK_DIR_PATH, err])
	
	return fallback_dir
