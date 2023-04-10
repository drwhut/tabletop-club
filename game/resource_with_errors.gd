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

class_name ResourceWithErrors
extends Resource

## A resource with extra error metadata.
##
## This class can be used to store errors that occured during runtime, e.g.
## when importing assets.


class ErrorDetail:
	extends Reference
	
	## The function that produced the error.
	var function := ""
	
	## The file the error occured in.
	var file := ""
	
	## The line number the error occured at.
	var line := 0
	
	## A short description of the error.
	var error := ""
	
	## A longer description of the error.
	var error_exp := ""


## A list of runtime errors associated with this resource.
## TODO: Make array typed in 4.x
var runtime_errors: Array = []

## A list of runtime warnings associated with this resource.
## TODO: Make array typed in 4.x
var runtime_warnings: Array = []
