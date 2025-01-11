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

## A global script containing utility functions for [Shape]s.


## Create a new [Shape] by taking the existing [param shape] and scaling it with
## the given [param scale].
##
## If the scale is [code]Vector3.ONE[/code], then [param shape] is returned.
##
## [b]NOTE:[/b] This only works for certain types of shapes. If an unsupported
## shape is passed, then [code]null[/code] is returned.
## For example, [CylinderShape] cannot be used here, as it cannot be scaled by
## differing amounts in the X and Z axes.
func scale_shape(shape: Shape, scale: Vector3) -> Shape:
	if scale.is_equal_approx(Vector3.ONE):
		return shape
	
	if shape is ConvexPolygonShape:
		var new_points := PoolVector3Array()
		for point in shape.points:
			new_points.push_back(scale * point)
		
		var new_shape := ConvexPolygonShape.new()
		new_shape.points = new_points
		return new_shape
	
	elif shape is ConcavePolygonShape:
		var new_faces := PoolVector3Array()
		for point in shape.get_faces():
			new_faces.push_back(scale * point)
		
		var new_shape := ConcavePolygonShape.new()
		new_shape.set_faces(new_faces)
		return new_shape
	
	elif shape is BoxShape:
		var new_shape := BoxShape.new()
		new_shape.extents = scale * shape.extents
		return new_shape
	
	else:
		push_error("Cannot scale collision shape, unsupported type")
		return null


## Create a new [Shape] by taking the existing [param shape] and transforming
## it with a [param matrix].
##
## If the matrix is the identity matrix, then [param shape] is returned back.
##
## [b]NOTE:[/b] This only works for certain types of shapes. If an unsupported
## shape is passed, then [code]null[/code] is returned.
## For example, [BoxShape] cannot be used here, as rotations cannot be applied.
func transform_shape(shape: Shape, matrix: Basis) -> Shape:
	if matrix.is_equal_approx(Basis.IDENTITY):
		return shape
	
	if shape is ConvexPolygonShape:
		var new_points := PoolVector3Array()
		for point in shape.points:
			new_points.push_back(matrix * point)
		
		var new_shape := ConvexPolygonShape.new()
		new_shape.points = new_points
		return new_shape
	
	elif shape is ConcavePolygonShape:
		var new_faces := PoolVector3Array()
		for point in shape.get_faces():
			new_faces.push_back(matrix * point)
		
		var new_shape := ConcavePolygonShape.new()
		new_shape.set_faces(new_faces)
		return new_shape
	
	else:
		push_error("Cannot transform collision shape, unsupported type")
		return null
