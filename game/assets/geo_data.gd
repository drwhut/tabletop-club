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

class_name GeoData
extends Resource

## Store data about the geometry of a scene.
##
## This resource is used to scan custom scenes for useful geometry metadata,
## such as the average vertex or the overall bounding box across all meshes.
## This information can then be used in [AssetEntryScene].


## The total number of vertices in the scene.
export(int) var vertex_count := 0 setget set_vertex_count

## The sum total of all of the vertex positions in the scene.
export(Vector3) var vertex_sum := Vector3.ZERO

## The bounding box for the entire scene.
export(AABB) var bounding_box := AABB()


## Calculate the average vertex position for the entire scene.
func average_vertex() -> Vector3:
	if vertex_count == 0:
		return Vector3.ZERO
	
	return (1.0 / vertex_count) * vertex_sum


func set_vertex_count(count: int) -> void:
	if count < 0:
		push_error("Vertex count cannot be negative")
		return
	
	vertex_count = count
