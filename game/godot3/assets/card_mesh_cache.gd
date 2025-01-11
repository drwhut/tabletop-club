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

extends Node

## A cache for generated card meshes with various corner sizes.


var _mesh_cache := {}


## For the given card scale and corner size, get the corresponding [Mesh] using
## the [CardMeshGenerator].
##
## The resulting [Mesh] is cached, so that it is not re-generated when using the
## same parameters.
func get_mesh(card_scale: Vector2, corner_size: Vector2) -> Mesh:
	var key := [ card_scale, corner_size ]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	
	print("CardMeshCache: Generating mesh for scale = %s, corner_size = %s ..." %
			[str(card_scale), str(corner_size)])
	var generator := CardMeshGenerator.new()
	
	# Generate a mesh with a unit size, and let the ObjectBuilder scale it like
	# all other pieces afterwards.
	generator.extents = Vector3(0.5, 0.01, 0.5)
	
	if is_zero_approx(card_scale.x):
		push_error("X-scale of card cannot be 0")
		card_scale.x = 1.0
	
	if is_zero_approx(card_scale.y):
		push_error("Y-scale of card cannot be 0")
		card_scale.y = 1.0
	
	generator.corner_start = Vector2(0.5, 0.5) - (corner_size / card_scale)
	
	# Aim for roughly one vertex per in-game 0.25mm.
	var max_size := max(corner_size.x, corner_size.y)
	generator.corner_points = 4 * (1 + int(max_size))
	
	# Generate the mesh, and cache it.
	var mesh := generator.generate()
	_mesh_cache[key] = mesh
	return mesh
