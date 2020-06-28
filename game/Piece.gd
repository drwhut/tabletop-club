# OpenTabletop
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

extends RigidBody

class_name Piece

const LINEAR_FORCE_SCALAR  = 5.0
const ANGULAR_FORCE_SCALAR = 5.0

var hover_position = Vector3()

var _is_hovering = false

func start_hovering():
	_is_hovering = true
	custom_integrator = true

func stop_hovering():
	_is_hovering = false
	custom_integrator = false

func is_hovering():
	return _is_hovering

func _integrate_forces(state):
	if _is_hovering:
		# Force the piece to the given location.
		state.apply_central_impulse(LINEAR_FORCE_SCALAR * (hover_position - translation))
		# Stops linear harmonic motion.
		state.apply_central_impulse(-linear_velocity * mass)
		
		# TODO: Are the following cross products worth optimising?
		
		# Torque the piece to the upright position on two axes.
		state.add_torque(ANGULAR_FORCE_SCALAR * (Vector3.UP - transform.basis.y).cross(transform.basis.y))
		state.add_torque(ANGULAR_FORCE_SCALAR * (Vector3.FORWARD - transform.basis.z).cross(transform.basis.z))
		# Stops angular harmonic motion.
		state.add_torque(-angular_velocity)
