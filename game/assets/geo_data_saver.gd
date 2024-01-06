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

class_name GeoDataSaver
extends ResourceFormatSaver

## Save [GeoData] in an optimised format.


func get_recognized_extensions(_resource: Resource) -> PoolStringArray:
	return PoolStringArray(["geo"])


func recognize(resource: Resource) -> bool:
	return resource is GeoData


func save(path: String, resource: Resource, _flags: int) -> int:
	if not resource is GeoData:
		return ERR_INVALID_PARAMETER
	
	var file := File.new()
	var err := file.open(path, File.WRITE)
	if err != OK:
		return err
	
	file.store_32(resource.vertex_count)
	file.store_float(resource.vertex_sum.x)
	file.store_float(resource.vertex_sum.y)
	file.store_float(resource.vertex_sum.z)
	file.store_float(resource.bounding_box.position.x)
	file.store_float(resource.bounding_box.position.y)
	file.store_float(resource.bounding_box.position.z)
	file.store_float(resource.bounding_box.size.x)
	file.store_float(resource.bounding_box.size.y)
	file.store_float(resource.bounding_box.size.z)
	
	file.close()
	return OK
