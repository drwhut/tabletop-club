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

## Used to access classes from the game's custom module.
##
## In order for the game to function properly, a custom module should be
## compiled with the engine binary that includes extra functionality like
## importing resources, as well as reporting errors and warnings.
## See: https://github.com/drwhut/tabletop_club_godot_module


## The [TabletopImporter] class, which is used to import resources at
## runtime, even in release builds.
var tabletop_importer: Reference = null setget _do_nothing

## The [ErrorReporter] class, which emits signals when an engine error or
## warning is thrown.
var error_reporter: Reference = null setget _do_nothing


func _ready():
	# We use ClassDB here just in case the custom module is not included,
	# so the game can at least keep running with limited functionality.
	if ClassDB.can_instance("TabletopImporter"):
		tabletop_importer = ClassDB.instance("TabletopImporter")
		print("Loaded: TabletopImporter")
	if ClassDB.can_instance("ErrorReporter"):
		error_reporter = ClassDB.instance("ErrorReporter")
		print("Loaded: ErrorReporter")


## Check if the custom module has loaded in correctly.
func is_loaded() -> bool:
	return (tabletop_importer != null) and (error_reporter != null)


# A dummy function that prevents outside code from removing the references.
func _do_nothing(_value) -> void:
	return
