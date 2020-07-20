# open-tabletop
# Copyright (c) 2020 drwhut
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

extends MeshInstance

func _init():
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	st.add_uv(Vector2(0.4, 1))
	st.add_vertex(Vector3(0.943, -0.333, 0)) # +x
	st.add_uv(Vector2(0, 1))
	st.add_vertex(Vector3(-0.471, -0.333, 0.816)) # +z
	st.add_uv(Vector2(0.2, 0))
	st.add_vertex(Vector3(0, 1, 0)) # +y
	
	st.add_uv(Vector2(0.2, 0))
	st.add_vertex(Vector3(-0.471, -0.333, 0.816)) # +z
	st.add_uv(Vector2(0.6, 0))
	st.add_vertex(Vector3(-0.471, -0.333, -0.816)) # -z
	st.add_uv(Vector2(0.4, 1))
	st.add_vertex(Vector3(0, 1, 0)) # +y
	
	st.add_uv(Vector2(0.8, 1))
	st.add_vertex(Vector3(-0.471, -0.333, -0.816)) # -z
	st.add_uv(Vector2(0.4, 1))
	st.add_vertex(Vector3(0.943, -0.333, 0)) # +x
	st.add_uv(Vector2(0.6, 0))
	st.add_vertex(Vector3(0, 1, 0)) # +y
	
	st.add_uv(Vector2(0.6, 0))
	st.add_vertex(Vector3(-0.471, -0.333, -0.816)) # -z
	st.add_uv(Vector2(1, 0))
	st.add_vertex(Vector3(-0.471, -0.333, 0.816)) # +z
	st.add_uv(Vector2(0.8, 1))
	st.add_vertex(Vector3(0.943, -0.333, 0)) # +x
	
	st.generate_normals()
	
	mesh = st.commit()
