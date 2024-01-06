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

class_name AssetEntrySingle
extends AssetEntry

## Contains metadata for a single asset.
##
## This class is here to store copyright information about a single asset.

## The author, or authors, of the asset.
export(String) var author := "" setget set_author

## The license the asset is distributed under.
export(String) var license := "" setget set_license

## The individuals who have modified the asset.
export(String) var modified_by := "" setget set_modified_by

## The URL from which to download the asset.
export(String) var url := "" setget set_url


func set_author(value: String) -> void:
	author = value.strip_edges()


func set_license(value: String) -> void:
	license = value.strip_edges()


func set_modified_by(value: String) -> void:
	modified_by = value.strip_edges()


func set_url(value: String) -> void:
	url = value.strip_edges()
