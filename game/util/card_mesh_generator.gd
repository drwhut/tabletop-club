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


## The margin at the edges of the front face used for the sides of the mesh.
const UV_MARGIN := 0.01


## Create an [ArrayMesh] for cards with two surfaces: one for the front face,
## and one for the back face.
func create_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(0.5, 0.5, 0.5)) # +x+y+z
	st.add_uv(Vector2(0, 1))
	st.add_vertex(Vector3(-0.5, 0.5, 0.5)) # -x+y+z
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-0.5, 0.5, -0.5)) # -x+y-z
	
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-0.5, 0.5, -0.5)) # -x+y-z
	st.add_uv(Vector2(1, 0))
	st.add_vertex(Vector3(0.5, 0.5, -0.5)) # +x+y-z
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(0.5, 0.5, 0.5)) # +x+y+z
	
	st.add_uv(Vector2(0, 1-UV_MARGIN))
	st.add_vertex(Vector3(-0.5, 0.5, 0.5)) # -x+y+z
	st.add_uv(Vector2(1, 1-UV_MARGIN))
	st.add_vertex(Vector3(0.5, 0.5, 0.5)) # +x+y+z
	st.add_uv(Vector2(0, 1))
	st.add_vertex(Vector3(-0.5, -0.5, 0.5)) # -x-y+z
	
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(0.5, -0.5, 0.5)) # +x-y+z
	st.add_uv(Vector2(0, 1))
	st.add_vertex(Vector3(-0.5, -0.5, 0.5)) # -x-y+z
	st.add_uv(Vector2(1, 1-UV_MARGIN))
	st.add_vertex(Vector3(0.5, 0.5, 0.5)) # +x+y+z
	
	st.add_uv(Vector2(1, UV_MARGIN))
	st.add_vertex(Vector3(0.5, 0.5, -0.5)) # +x+y-z
	st.add_uv(Vector2(0, UV_MARGIN))
	st.add_vertex(Vector3(-0.5, 0.5, -0.5)) # -x+y-z
	st.add_uv(Vector2(1, 0))
	st.add_vertex(Vector3(0.5, -0.5, -0.5)) # +x-y-z
	
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-0.5, -0.5, -0.5)) # -x-y-z
	st.add_uv(Vector2(1, 0))
	st.add_vertex(Vector3(0.5, -0.5, -0.5)) # +x-y-z
	st.add_uv(Vector2(0, UV_MARGIN))
	st.add_vertex(Vector3(-0.5, 0.5, -0.5)) # -x+y-z
	
	st.add_uv(Vector2(UV_MARGIN, 0))
	st.add_vertex(Vector3(-0.5, 0.5, -0.5)) # -x+y-z
	st.add_uv(Vector2(UV_MARGIN, 1))
	st.add_vertex(Vector3(-0.5, 0.5, 0.5)) # -x+y+z
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-0.5, -0.5, -0.5)) # -x-y-z
	
	st.add_uv(Vector2(0, 1))
	st.add_vertex(Vector3(-0.5, -0.5, 0.5)) # -x-y+z
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-0.5, -0.5, -0.5)) # -x-y-z
	st.add_uv(Vector2(UV_MARGIN, 1))
	st.add_vertex(Vector3(-0.5, 0.5, 0.5)) # -x+y+z
	
	st.add_uv(Vector2(1-UV_MARGIN, 1))
	st.add_vertex(Vector3(0.5, 0.5, 0.5)) # +x+y+z
	st.add_uv(Vector2(1-UV_MARGIN, 0))
	st.add_vertex(Vector3(0.5, 0.5, -0.5)) # +x+y-z
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(0.5, -0.5, 0.5)) # +x-y+z
	
	st.add_uv(Vector2(1, 0))
	st.add_vertex(Vector3(0.5, -0.5, -0.5)) # +x-y-z
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(0.5, -0.5, 0.5)) # +x-y+z
	st.add_uv(Vector2(1-UV_MARGIN, 0))
	st.add_vertex(Vector3(0.5, 0.5, -0.5)) # +x+y-z
	
	st.generate_normals()
	var mesh := st.commit()
	
	# Create a second surface for the back face of the cards, since we want to
	# apply a separate texture for the back face.
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(-0.5, -0.5, 0.5)) # -x-y+z
	st.add_uv(Vector2(0, 1))
	st.add_vertex(Vector3(0.5, -0.5, 0.5)) # +x-y+z
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(0.5, -0.5, -0.5)) # +x-y-z
	
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(0.5, -0.5, -0.5)) # +x-y-z
	st.add_uv(Vector2(1, 0))
	st.add_vertex(Vector3(-0.5, -0.5, -0.5)) # -x-y-z
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(-0.5, -0.5, 0.5)) # -x-y+z
	
	st.generate_normals()
	mesh = st.commit(mesh)
	
	return mesh
