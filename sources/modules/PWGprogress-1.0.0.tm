
# PWGprogress - a component of Password Gorilla
#
# ----------------------------------------------------------------------
#
# See the gorilla.tcl file for Password Gorilla copyright, authorship, and
# license information.
#
# This module authored by Richard Ellis <rellis@dp100.com>
# Copyright 2011 Richard Ellis
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, 51
# Franklin Street, Suite 500, Boston, MA 02110
#
# A copy of the GNU General Public License can be found in the file
# LICENSE.txt located in the same directory as gorilla.tcl.
# ----------------------------------------------------------------------

# this makes use of several 8.5 features, so make sure we are running at
# least 8.5
package require Tcl 8.5

package provide gorillaprogress 1.0.0

# 
# This module provides for a generic framework for feedback progress bars
# for Password Gorilla.  This encapsulates all the code related to handling
# the progress bars into one location, in a private namespace, and thereby
# simplifies the remainder of the Password Gorilla codebase.
#

namespace eval ::gorilla::progress {

	# stores the state of the progress subsystem
	variable state [ dict create ]

	# The dict "state" is a two level dict.  Toplevel key is the window
	# toplevel name.  Each toplevel key has one or more of:
	#   message    - the message to be displayed in the label widget
	#   active     - boolean indicating if this pbar is active
	#   lastupdate - integer milliseconds since last update of the value
	#   pbar       - window name for the progress bar itself

	# stores the current values of the various progress bars - this is
	# an array because tk/ttk widgets can not link to dict entries
	variable values

	namespace ensemble create

	namespace path { ::tcl::mathop ::tcl::mathfunc }

	namespace export init update finished newmessage

} ; # end namespace eval ::gorilla::progress

#
# ----------------------------------------------------------------------
#

proc ::gorilla::progress::init { args } {

	# Initializes the progress subsystem for use.  

	validate $args

	variable state
	variable values

	set tl [ winfo toplevel [ dict get $args -win ] ]

	if { [ dict exists $state $tl active ] } { return }

	dict set state $tl message [ set message [ dict get $args -message ] ]
	set values($tl) 0
	dict set state $tl active 1
	dict set state $tl lastupdate [ clock milliseconds ]
	dict set state $tl max [ expr { [ dict exists $args -max ] ? [ dict get $args -max ] : 100 } ]

	# build the progress bar
	# Note - use a tk frame because it allows control of the border
	dict set state $tl pbar [ set pbar [ frame $tl.pbar -borderwidth 1m -relief ridge ] ]
	set opts {-sticky news -padx {1m 1m}}
	grid [ ttk::label       $pbar.label -text [ format $message 0 ] ] {*}$opts -pady {1m 0}
	grid [ ttk::progressbar $pbar.bar -value 0 -maximum [ dict get $state $tl max ] ] {*}$opts -pady {0 1m}
	grid columnconfigure $pbar 0 -weight 1

	if { [ llength [ trace info variable [ namespace current ]::values($tl) ] ] == 0 } {
		trace add variable [ namespace current ]::values($tl) write [ namespace code [ list tracefired $tl ] ]
	}

	place $pbar -anchor center -relx 0.5 -rely 0.5 -width 3i 
	raise $pbar	

	::update idletasks

	return [ namespace current ]::values($tl)

	#ruff
	#
	# parameters 
	#
	#   -win window R Where the progress bar should appear - uses
	#                 toplevel window name as internal key.
	#
	#   -message string R The message string to display in the label
	#                     widget associated with the progress bar.
	#
	#   -max integer O Defines the range of the progress bar.  The value
	#                  should be integer multiplies of 100.
	#
	# The message entry must contain one, and only one, %d format
	# substitution marker.  This will be replaced by the percent
	# complete (scaled to the -max range) as given in calls to the
	# ::gorilla::progress::update subcommand.
	#
	# Note, init simply utilizes the passed message string unaltered,
	# msgcat translations are outside the scope of this module and are
	# expected to be handled by the code calling init, not by this
	# module.

} ; # end proc ::gorilla::progress::init

#
# ----------------------------------------------------------------------
#

proc ::gorilla::progress::validate { config } {

	# Validates the contents of the passed dictionary to make sure it
	# contains required elements, and that the elements make sense.

	# validate window option
	validate_window $config

	# validate message key
	validate_message $config

	# validate optional max
	validate_max $config

	return GORILLA_OK

} ; # end proc ::gorilla::progress::validate

#
# ----------------------------------------------------------------------
#

proc ::gorilla::progress::validate_window { config } {

	if { ! [ dict exists $config -win ] } {
		error "Required '-win' parameter missing."
	}

	if { ! [ winfo exists [ dict get $config -win ] ] } {
		error "Window '[ dict get $config -win ]' does not exist."
	}

} ; # end proc validate_window

#
# ----------------------------------------------------------------------
#

proc ::gorilla::progress::validate_message { config } {

	if { ! [ dict exists $config -message ] } {
		error "Required '-message' parameter missing."
	}

	if { -1 == [ set i [ string first "%d" [ dict get $config -message ] ] ] } {
		error "Message string does not contain a '%d' substitution."
	} elseif { -1 != [ string first "%d" [ dict get $config -message ] $i+1 ] } {
		error "Message string contains more than one '%d' substitution, only a single occurrence allowed."
	}

} ; # end proc ::gorilla::progress::validate_message

#
# ----------------------------------------------------------------------
#

proc ::gorilla::progress::validate_max { config } {

	if { [ dict exists $config -max ] } {
		if { ! [ string is integer -strict [ dict get $config -max ] ] } {
			error "Value for -max must be an integer."
		} elseif { ( [ dict get $config -max ] % 100 ) != 0 } {
			error "Value for -max must be an integer multiple of 100."
		} 
	}

} ; # end proc validate_variable

#
# ----------------------------------------------------------------------
#

proc ::gorilla::progress::active? { tl } {

	# tests for progress subsystem being in active state for toplevel
	# tl.  If not forces calling proc to unconditionally return.

	set tl [ winfo toplevel $tl ]

	variable state
	if { ! [ dict exists $state $tl active ] } {
		return -code return
	}

} ; # end proc ::gorilla::progress::active?

#
# ----------------------------------------------------------------------
#

proc ::gorilla::progress::tracefired { tl a b c } {
	# Handles variable trace callbacks by passing current value of
	# "value" variable to update proc
	variable state

	# limit update rate to once every 500ms
	if { [ - [ clock milliseconds ] [ dict get $state $tl lastupdate ] ] < 500 } {
		return
	}

	variable values
	set values($tl) [ max 0 [ min [ int $values($tl) ] [ dict get $state $tl max ] ] ]

	[ dict get $state $tl pbar ].label configure -text [ format [ dict get $state $tl message ] [ / [ * 100 $values($tl) ] [ dict get $state $tl max ] ] ]

	[ dict get $state $tl pbar ].bar configure -value $values($tl)

	dict set state $tl lastupdate [ clock milliseconds ]

	::update idletasks

} ; # end proc ::gorilla::progress::trace

#
# ----------------------------------------------------------------------
#

proc ::gorilla::progress::update-pbar { tl value } {

	# called to update the configured progress bar with a new value

	set tl [ winfo toplevel $tl ]

	active? $tl

	if { ! [ string is double -strict $value ] } {
		error "progress update called with non-numeric value '$value'"
	}

	variable values

	return GORILLA_OK

	#ruff
	#
	# tl    - the toplevel that this pbar is attached to
	#
	# value - the new value, can be integer or floating point, will be
	#         truncated to an integer and limited to the range 0 ... 
	#         100.

} ; # end proc ::gorilla::progress::update-pbar

#
# ----------------------------------------------------------------------
#

proc ::gorilla::progress::newmessage { tl text } {

	# Updates the internal message string and current widget text value
	# without modifying the widget name being utilized for feedback.

	validate_message [ list -message $text ]

	set tl [ winfo toplevel $tl ]

	variable state
	variable values
	dict set state $tl message $text

	set values($tl) $values($tl)

} ; # end proc ::gorilla::progress::newmessage

#
# ----------------------------------------------------------------------
#

proc ::gorilla::progress::finished { tl } {

	# Sets progress subsystem state to inactive, clears message text
	# from the configured widget, deletes variable trace.

	set tl [ winfo toplevel $tl ]

	active? $tl

	variable state
	destroy [ dict get $state $tl pbar ]
	dict unset state $tl 

	variable values
	unset values($tl)

	return GORILLA_OK

} ; # end proc ::gorilla::progress::finished
