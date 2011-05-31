#! /bin/sh
# the next line restarts using wish \
exec tclsh8.5 "$0" ${1+"$@"}

# help2po.tcl: Utility to create gettext catalogue message files
#
# location: <gorilla-path>/utilities
#
# patch viewhelp.tcl with msgcat::mc calls
#
# Usage: help2po locale ...
#
# The utility runs the gorilla::Help routine with a given language and
# adds the unknown messages to a .po file which can be edited and
# converted with msgfmt and mcset2mcmset.tcl
#
# FIXME: No error checking! No backup!

package require Tk
package require msgcat

namespace eval gorilla {}
namespace import msgcat::*

set output ""

# To create an empty help.pot we activate the following "mlocale" line
# with the language of the Adangme people in Ghana 
mclocale ada
# mclocale ?newLocale?

mcload [file join [file dirname [info script]] help2po]

# Some helper routines for the Gorilla viewhelp.tcl
# ----------------------------------------------------------------------

proc gorilla::TryResizeFromPreference { top } { return OK }

proc gorilla::CloseDialog { top } {
	if {[info exists ::gorilla::toplevel($top)]} {
		wm withdraw $top
	}
}

proc ::msgcat::mcunknown {locale src_string} {
	global output
	# redefine procedure to create .po entries
	set poStr "msgid \"[ string map [ list \\ \\\\ \" \\\" "\n" "\\n" ] $src_string	]\"\nmsgstr \"\"\n"

	if { $src_string ne "" } { puts $output $poStr }
	# puts $poStr
	return $src_string
}

# --------------------------- Main -------------------------------------

source ../sources/viewhelp.tcl

set output [open help.pot w]

::Help::ReadHelpFiles ../sources
::Help::Help
# ::Help::Help Overview

foreach title $::Help::state(allTOC) {
	::Help::Show $title
}

close $output

# exclude the duplicates
exec msguniq -o help.pot help.pot

exit

# ----------------------------- Comments -------------------------------

# How to filter two identical msgids with different translations in two
# message catalogues?
#
# msguniq will work just on one .po file
# try: msgcat -> 0 inputfile ...
#
# Note: default location for help .msg and .po files: /utilities/help

# Das Volk der Adangme zählt ca. 2.000 Angehörige
# locale ada
