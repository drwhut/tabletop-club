# open-tabletop
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows
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

class_name StackPieceInstance

var piece_entry: Dictionary = {}

# Set the piece to appear like it has been selected.
# selected: Should the piece appear selected?
func set_appear_selected(selected: bool) -> void:
	# NOTE: This should be nearly identical to Piece.set_appear_selected!
	var material = get_surface_material(0)
	if material is SpatialMaterial:
		material.emission = Piece.SELECTED_COLOUR
		material.emission_energy = Piece.SELECTED_ENERGY
		
		material.emission_enabled = selected
