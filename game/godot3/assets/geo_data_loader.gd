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

class_name GeoDataLoader
extends ResourceFormatLoader

## Load [code].geo[/code] files as [GeoData].


func get_recognized_extensions() -> PoolStringArray:
	return PoolStringArray(["geo"])


func get_resource_type(path: String) -> String:
	return "Resource" if path.get_extension() == "geo" else ""


func handles_type(typename: String) -> bool:
	return typename == "Resource"


func load(path: String, _original_path: String, _no_subresource_cache: bool):
	var file := File.new()
	var err := file.open(path, File.READ)
	if err != OK:
		return err
	
	if file.get_len() != 40:
		return ERR_FILE_CORRUPT
	
	var geo_data := GeoData.new()
	geo_data.vertex_count = file.get_32()
	geo_data.vertex_sum.x = file.get_float()
	geo_data.vertex_sum.y = file.get_float()
	geo_data.vertex_sum.z = file.get_float()
	geo_data.bounding_box.position.x = file.get_float()
	geo_data.bounding_box.position.y = file.get_float()
	geo_data.bounding_box.position.z = file.get_float()
	geo_data.bounding_box.size.x = file.get_float()
	geo_data.bounding_box.size.y = file.get_float()
	geo_data.bounding_box.size.z = file.get_float()
	
	return geo_data
