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

class_name CardMeshGenerator
extends Reference

## A helper class for procedurally generating card meshes.
##
## Cards have special meshes that consists of two surfaces, one for the front
## face of the card, and one for the back, so that each surface can have a
## separate texture applied to it.
##
## As of v0.2.0, cards also have optional rounded corners, the sizes of which
## can be changed independently on each axis.
##
## TODO: Test this class fully once complete.


## A structure for internal use only.
class AuxiliaryData:
	extends Reference
	
	# Flags for various edge-cases depending on the properties we are given.
	var x_edge_exists: bool
	var z_edge_exists: bool
	var corners_exist: bool
	
	# The mesh origin is at (0, 0, 0), but the UV at the origin is (0.5, 0.5).
	var uv_corner_start: Vector2
	
	# The vertices of the -X-Z, -X+Z, +X-Z, and +X+Z corners, in that order.
	# For the +X+Z corner, the vertices are in clockwise order.
	var corner_verts: Array
	
	# The UVs for each of the vertices in corner_verts.
	var corner_uvs: Array
	
	func _init(extents: Vector3, corner_start: Vector2, corner_points: int):
		x_edge_exists = not is_zero_approx(corner_start.x)
		z_edge_exists = not is_zero_approx(corner_start.y)
		corners_exist = not (is_equal_approx(extents.x, corner_start.x) or \
				is_equal_approx(extents.z, corner_start.y))
		
		if corners_exist:
			var corner_ratio_x := corner_start.x / extents.x
			var corner_ratio_z := corner_start.y / extents.z
			uv_corner_start = 0.5 * Vector2(corner_ratio_x, corner_ratio_z)
		else:
			uv_corner_start = Vector2(0.5, 0.5)
		
		if not corners_exist:
			# Avoid divide-by-zero errors.
			corner_verts = []
			corner_uvs = []
			return
		
		# Figure out where the corner vertices should be relative to corner_start.
		var local_corner_verts := PoolVector2Array()
		var corner_size := Vector2(extents.x - corner_start.x,
				extents.z - corner_start.y)
		
		local_corner_verts.push_back(Vector2(corner_size.x, 0.0))
		
		for index in range(corner_points):
			var axis_fraction := float(index + 1) / (corner_points + 1)
			var vert := Vector2.ZERO
			
			# Iterate evenly over the shorter axis, so that we get more verticies
			# on the actual curved section of the corner.
			# NOTE: Based on the equation for an elipse.
			if corner_size.x < corner_size.y:
				axis_fraction = 1.0 - axis_fraction
				vert.x = axis_fraction * corner_size.x
				vert.y = sqrt(corner_size.x * corner_size.x - vert.x * vert.x)
				vert.y *= corner_size.y / corner_size.x
			else:
				vert.y = axis_fraction * corner_size.y
				vert.x = sqrt(corner_size.y * corner_size.y - vert.y * vert.y)
				vert.x *= corner_size.x / corner_size.y
			
			local_corner_verts.push_back(vert)
		
		local_corner_verts.push_back(Vector2(0.0, corner_size.y))
		
		var local_corner_uvs := PoolVector2Array()
		var uv_corner_size := Vector2(0.5, 0.5) - uv_corner_start
		var vert_to_uv := uv_corner_size / corner_size
		for vert in local_corner_verts:
			local_corner_uvs.push_back(vert_to_uv * vert)
		
		# Now that we have local vertex info for one corner, we can now figure
		# out the global vertex info for all four corners.
		for cx in [-1.0, 1.0]:
			for cy in [-1.0, 1.0]:
				var c := Vector2(cx, cy)
				
				var verts_for_corner := PoolVector2Array()
				for vert in local_corner_verts:
					verts_for_corner.push_back(c * (corner_start + vert))
				
				var uvs_for_corner := PoolVector2Array()
				for uv in local_corner_uvs:
					uvs_for_corner.push_back(Vector2(0.5, 0.5) + c * (
							uv_corner_start + uv))
				
				corner_verts.push_back(verts_for_corner)
				corner_uvs.push_back(uvs_for_corner)


## The matrix used to rotate vertices to make the back face.
const ROTATE_TO_BACK := Basis(
	Vector3(-1.0, 0.0,  0.0),
	Vector3(0.0,  -1.0, 0.0),
	Vector3(0.0,  0.0,  1.0)
)


## The extents to which the mesh is generated in each axis.
var extents := Vector3.ONE setget set_extents

## The extents to which the mesh's edge is straight, before the corner starts.
var corner_start := Vector2.ZERO setget set_corner_start

## The number of points to use in each corner.
var corner_points := 0 setget set_corner_points

## The size of the margin at the edge of the UV used for the sides of the mesh.
var uv_margin := 0.01 setget set_uv_margin


## Generate the card mesh as an [ArrayMesh] using the given properties.
func generate() -> ArrayMesh:
	var st := SurfaceTool.new()
	
	# Generate auxiliary data to pass to the private functions.
	var auxiliary_data := AuxiliaryData.new(extents, corner_start, corner_points)
	
	# SURFACE 0: FRONT FACE + SIDE MARGINS
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	_add_face(st, Basis.IDENTITY, auxiliary_data)
	_add_sides(st, auxiliary_data)
	
	st.generate_normals()
	var mesh := st.commit()
	
	# SURFACE 1: BACK FACE
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Same process at the front face, but rotated 180 degrees around z-axis.
	_add_face(st, ROTATE_TO_BACK, auxiliary_data)
	
	st.generate_normals()
	mesh = st.commit(mesh)
	
	return mesh


func set_extents(new_value: Vector3) -> void:
	new_value = new_value.abs()
	
	if (
		is_zero_approx(new_value.x) or
		is_zero_approx(new_value.y) or
		is_zero_approx(new_value.z)
	):
		push_error("Invalid extents for card mesh: %s" % str(new_value))
		return
	
	extents = new_value
	
	# corner_start might be too big now, adjust if needed.
	set_corner_start(corner_start)


func set_corner_start(new_value: Vector2) -> void:
	new_value = new_value.abs()
	new_value.x = min(new_value.x, extents.x)
	new_value.y = min(new_value.y, extents.z)
	corner_start = new_value


func set_corner_points(new_value: int) -> void:
	if new_value < 0:
		push_error("Invalid value '%d' for number of corner points" % new_value)
		return
	
	corner_points = new_value


func set_uv_margin(new_value: float) -> void:
	uv_margin = clamp(new_value, 0.0, 1.0)


func _add_face(st: SurfaceTool, m: Basis, a: AuxiliaryData) -> void:
	_add_face_rectangles(st, m, a)
	
	if not a.corners_exist:
		return
	
	for ci in range(4):
		_add_face_corner(st, m, ci, a)


func _add_face_rectangles(st: SurfaceTool, m: Basis, a: AuxiliaryData) -> void:
	if a.x_edge_exists:
		st.add_uv(Vector2(0.5 + a.uv_corner_start.x, 1.0))
		st.add_vertex(m * Vector3(corner_start.x, extents.y, extents.z))
		st.add_uv(Vector2(0.5 - a.uv_corner_start.x, 1.0))
		st.add_vertex(m * Vector3(-corner_start.x, extents.y, extents.z))
		st.add_uv(Vector2(0.5 - a.uv_corner_start.x, 0.0))
		st.add_vertex(m * Vector3(-corner_start.x, extents.y, -extents.z))
		
		st.add_uv(Vector2(0.5 + a.uv_corner_start.x, 1.0))
		st.add_vertex(m * Vector3(corner_start.x, extents.y, extents.z))
		st.add_uv(Vector2(0.5 - a.uv_corner_start.x, 0.0))
		st.add_vertex(m * Vector3(-corner_start.x, extents.y, -extents.z))
		st.add_uv(Vector2(0.5 + a.uv_corner_start.x, 0.0))
		st.add_vertex(m * Vector3(corner_start.x, extents.y, -extents.z))
		
		if a.z_edge_exists and a.corners_exist:
			st.add_uv(Vector2(1.0, 0.5 + a.uv_corner_start.y))
			st.add_vertex(m * Vector3(extents.x, extents.y, corner_start.y))
			st.add_uv(Vector2(0.5 + a.uv_corner_start.x, 0.5 + a.uv_corner_start.y))
			st.add_vertex(m * Vector3(corner_start.x, extents.y, corner_start.y))
			st.add_uv(Vector2(0.5 + a.uv_corner_start.x, 0.5 - a.uv_corner_start.y))
			st.add_vertex(m * Vector3(corner_start.x, extents.y, -corner_start.y))
			
			st.add_uv(Vector2(1.0, 0.5 + a.uv_corner_start.y))
			st.add_vertex(m * Vector3(extents.x, extents.y, corner_start.y))
			st.add_uv(Vector2(0.5 + a.uv_corner_start.x, 0.5 - a.uv_corner_start.y))
			st.add_vertex(m * Vector3(corner_start.x, extents.y, -corner_start.y))
			st.add_uv(Vector2(1.0, 0.5 - a.uv_corner_start.y))
			st.add_vertex(m * Vector3(extents.x, extents.y, -corner_start.y))
			
			st.add_uv(Vector2(0.5 - a.uv_corner_start.x, 0.5 + a.uv_corner_start.y))
			st.add_vertex(m * Vector3(-corner_start.x, extents.y, corner_start.y))
			st.add_uv(Vector2(0.0, 0.5 + a.uv_corner_start.y))
			st.add_vertex(m * Vector3(-extents.x, extents.y, corner_start.y))
			st.add_uv(Vector2(0.0, 0.5 - a.uv_corner_start.y))
			st.add_vertex(m * Vector3(-extents.x, extents.y, -corner_start.y))
			
			st.add_uv(Vector2(0.5 - a.uv_corner_start.x, 0.5 + a.uv_corner_start.y))
			st.add_vertex(m * Vector3(-corner_start.x, extents.y, corner_start.y))
			st.add_uv(Vector2(0.0, 0.5 - a.uv_corner_start.y))
			st.add_vertex(m * Vector3(-extents.x, extents.y, -corner_start.y))
			st.add_uv(Vector2(0.5 - a.uv_corner_start.x, 0.5 - a.uv_corner_start.y))
			st.add_vertex(m * Vector3(-corner_start.x, extents.y, -corner_start.y))
	
	elif a.z_edge_exists:
		st.add_uv(Vector2(1.0, 0.5 + a.uv_corner_start.y))
		st.add_vertex(m * Vector3(extents.x, extents.y, corner_start.y))
		st.add_uv(Vector2(0.0, 0.5 + a.uv_corner_start.y))
		st.add_vertex(m * Vector3(-extents.x, extents.y, corner_start.y))
		st.add_uv(Vector2(0.0, 0.5 - a.uv_corner_start.y))
		st.add_vertex(m * Vector3(-extents.x, extents.y, -corner_start.y))
		
		st.add_uv(Vector2(1.0, 0.5 + a.uv_corner_start.y))
		st.add_vertex(m * Vector3(extents.x, extents.y, corner_start.y))
		st.add_uv(Vector2(0.0, 0.5 - a.uv_corner_start.y))
		st.add_vertex(m * Vector3(-extents.x, extents.y, -corner_start.y))
		st.add_uv(Vector2(1.0, 0.5 - a.uv_corner_start.y))
		st.add_vertex(m * Vector3(extents.x, extents.y, -corner_start.y))


func _add_face_corner(st: SurfaceTool, m: Basis, ci: int, a: AuxiliaryData) -> void:
	var corner_vert := Vector2.ZERO
	var corner_uv := Vector2(0.5, 0.5)
	match ci:
		0:
			corner_vert = -corner_start
			corner_uv -= a.uv_corner_start
		1:
			corner_vert = Vector2(-corner_start.x, corner_start.y)
			corner_uv += Vector2(-a.uv_corner_start.x, a.uv_corner_start.y)
		2:
			corner_vert = Vector2(corner_start.x, -corner_start.y)
			corner_uv += Vector2(a.uv_corner_start.x, -a.uv_corner_start.y)
		3:
			corner_vert = corner_start
			corner_uv += a.uv_corner_start
	
	var verts_for_corner: PoolVector2Array = a.corner_verts[ci]
	var uvs_for_corner: PoolVector2Array = a.corner_uvs[ci]
	var swap_order := (ci == 1 or ci == 2)
	
	for index in range(verts_for_corner.size() - 1):
		var first_vert_index := (index + 1) if swap_order else index
		var second_vert_index := index if swap_order else (index + 1)
		
		var first_vert: Vector2 = verts_for_corner[first_vert_index]
		var first_uv: Vector2 = uvs_for_corner[first_vert_index]
		var second_vert: Vector2 = verts_for_corner[second_vert_index]
		var second_uv: Vector2 = uvs_for_corner[second_vert_index]
		
		st.add_uv(corner_uv)
		st.add_vertex(m * Vector3(corner_vert.x, extents.y, corner_vert.y))
		st.add_uv(first_uv)
		st.add_vertex(m * Vector3(first_vert.x, extents.y, first_vert.y))
		st.add_uv(second_uv)
		st.add_vertex(m * Vector3(second_vert.x, extents.y, second_vert.y))


func _add_sides(st: SurfaceTool, a: AuxiliaryData) -> void:
	_add_sides_at_edges(st, a)
	
	if not a.corners_exist:
		return
	
	for ci in range(4):
		_add_sides_at_corner(st, ci, a)


func _add_sides_at_edges(st: SurfaceTool, a: AuxiliaryData) -> void:
	if a.x_edge_exists:
		st.add_uv(Vector2(0.5 + a.uv_corner_start.x, 1.0))
		st.add_vertex(Vector3(corner_start.x, -extents.y, extents.z))
		st.add_uv(Vector2(0.5 - a.uv_corner_start.x, 1.0))
		st.add_vertex(Vector3(-corner_start.x, -extents.y, extents.z))
		st.add_uv(Vector2(0.5 - a.uv_corner_start.x, 1.0 - uv_margin))
		st.add_vertex(Vector3(-corner_start.x, extents.y, extents.z))
		
		st.add_uv(Vector2(0.5 + a.uv_corner_start.x, 1.0))
		st.add_vertex(Vector3(corner_start.x, -extents.y, extents.z))
		st.add_uv(Vector2(0.5 - a.uv_corner_start.x, 1.0 - uv_margin))
		st.add_vertex(Vector3(-corner_start.x, extents.y, extents.z))
		st.add_uv(Vector2(0.5 + a.uv_corner_start.x, 1.0 - uv_margin))
		st.add_vertex(Vector3(corner_start.x, extents.y, extents.z))
		
		st.add_uv(Vector2(0.5 - a.uv_corner_start.x, 0.0))
		st.add_vertex(Vector3(-corner_start.x, -extents.y, -extents.z))
		st.add_uv(Vector2(0.5 + a.uv_corner_start.x, 0.0))
		st.add_vertex(Vector3(corner_start.x, -extents.y, -extents.z))
		st.add_uv(Vector2(0.5 + a.uv_corner_start.x, uv_margin))
		st.add_vertex(Vector3(corner_start.x, extents.y, -extents.z))
		
		st.add_uv(Vector2(0.5 - a.uv_corner_start.x, 0.0))
		st.add_vertex(Vector3(-corner_start.x, -extents.y, -extents.z))
		st.add_uv(Vector2(0.5 + a.uv_corner_start.x, uv_margin))
		st.add_vertex(Vector3(corner_start.x, extents.y, -extents.z))
		st.add_uv(Vector2(0.5 - a.uv_corner_start.x, uv_margin))
		st.add_vertex(Vector3(-corner_start.x, extents.y, -extents.z))
	
	if a.z_edge_exists:
		st.add_uv(Vector2(1.0, 0.5 - a.uv_corner_start.y))
		st.add_vertex(Vector3(extents.x, -extents.y, -corner_start.y))
		st.add_uv(Vector2(1.0, 0.5 + a.uv_corner_start.y))
		st.add_vertex(Vector3(extents.x, -extents.y, corner_start.y))
		st.add_uv(Vector2(1.0 - uv_margin, 0.5 + a.uv_corner_start.y))
		st.add_vertex(Vector3(extents.x, extents.y, corner_start.y))
		
		st.add_uv(Vector2(1.0, 0.5 - a.uv_corner_start.y))
		st.add_vertex(Vector3(extents.x, -extents.y, -corner_start.y))
		st.add_uv(Vector2(1.0 - uv_margin, 0.5 + a.uv_corner_start.y))
		st.add_vertex(Vector3(extents.x, extents.y, corner_start.y))
		st.add_uv(Vector2(1.0 - uv_margin, 0.5 - a.uv_corner_start.y))
		st.add_vertex(Vector3(extents.x, extents.y, -corner_start.y))
		
		st.add_uv(Vector2(0.0, 0.5 + a.uv_corner_start.y))
		st.add_vertex(Vector3(-extents.x, -extents.y, corner_start.y))
		st.add_uv(Vector2(0.0, 0.5 - a.uv_corner_start.y))
		st.add_vertex(Vector3(-extents.x, -extents.y, -corner_start.y))
		st.add_uv(Vector2(uv_margin, 0.5 - a.uv_corner_start.y))
		st.add_vertex(Vector3(-extents.x, extents.y, -corner_start.y))
		
		st.add_uv(Vector2(0.0, 0.5 + a.uv_corner_start.y))
		st.add_vertex(Vector3(-extents.x, -extents.y, corner_start.y))
		st.add_uv(Vector2(uv_margin, 0.5 - a.uv_corner_start.y))
		st.add_vertex(Vector3(-extents.x, extents.y, -corner_start.y))
		st.add_uv(Vector2(uv_margin, 0.5 + a.uv_corner_start.y))
		st.add_vertex(Vector3(-extents.x, extents.y, corner_start.y))


func _add_sides_at_corner(st: SurfaceTool, ci: int, a: AuxiliaryData) -> void:
	# The UV co-ordinate to use for the bottom corners.
	# TODO: Come up with a better UV mapping for these side rectangles?
	var corner_uv := Vector2.ZERO
	match ci:
		0:
			corner_uv = Vector2(0.0, 0.0)
		1:
			corner_uv = Vector2(0.0, 1.0)
		2:
			corner_uv = Vector2(1.0, 0.0)
		3:
			corner_uv = Vector2(1.0, 1.0)
	
	# Same process as when adding the face corner.
	var verts_for_corner: PoolVector2Array = a.corner_verts[ci]
	var uvs_for_corner: PoolVector2Array = a.corner_uvs[ci]
	var swap_order := (ci == 1 or ci == 2)
	
	for index in range(verts_for_corner.size() - 1):
		var first_vert_index := (index + 1) if swap_order else index
		var second_vert_index := index if swap_order else (index + 1)
		
		var first_vert: Vector2 = verts_for_corner[first_vert_index]
		var first_uv: Vector2 = uvs_for_corner[first_vert_index]
		var second_vert: Vector2 = verts_for_corner[second_vert_index]
		var second_uv: Vector2 = uvs_for_corner[second_vert_index]
		
		st.add_uv(corner_uv)
		st.add_vertex(Vector3(first_vert.x, -extents.y, first_vert.y))
		st.add_uv(corner_uv)
		st.add_vertex(Vector3(second_vert.x, -extents.y, second_vert.y))
		st.add_uv(second_uv)
		st.add_vertex(Vector3(second_vert.x, extents.y, second_vert.y))
		
		st.add_uv(corner_uv)
		st.add_vertex(Vector3(first_vert.x, -extents.y, first_vert.y))
		st.add_uv(second_uv)
		st.add_vertex(Vector3(second_vert.x, extents.y, second_vert.y))
		st.add_uv(first_uv)
		st.add_vertex(Vector3(first_vert.x, extents.y, first_vert.y))
