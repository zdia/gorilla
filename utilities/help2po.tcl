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
# The new help.pot is saved in a temporary directory
#
# To create a new language po-help-file copy the file help.pot in the directory
# utilities/help2po to <your-locale>.po and edit it.
#
# Tested for PWGorilla version 1.5.3.6
#
# Author: Zbigniew Diaczyszyn
# https://github.com/zdia/gorilla

# FIXME: Add error checking!

package require Tk
package require msgcat

namespace eval gorilla {}
namespace import msgcat::*

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

# see if we are running from the utilities directory

if { ! [regexp /gorilla/utilities [pwd] ] } {
  puts "ERROR - this script must be run from the gorilla/utilities/ directory"
  puts "It is being run from [pwd] at present"
  puts "Unable to continue\n"
  exit
}

# viewhelp.tcl needs ::gorillaDir
set ::gorillaDir "[pwd]/../sources/"

source ../sources/viewhelp.tcl

set outdir [exec mktemp -d]
set outfile help.pot

set output [open $outdir/$outfile w]

# force mcunknown entries using the niche language ada
::Help::ReadHelpFiles ../sources ada
::Help::Help
# ::Help::Help Overview

foreach title $::Help::state(allTOC) {
	::Help::Show $title
}

close $output

# exclude the duplicates
exec msguniq -o $outdir/$outfile $outdir/$outfile

puts "\nNew help.pot file has been created in $outdir"

# update the old po-files with the new help.pot
set langlist [glob -d help2po *.po]
foreach file $langlist {
  puts "\nUpdating $file with latest help.pot created in $outdir:\n"
  exec -ignorestderr msgmerge --update $file --backup=simple $outdir/help.pot 
}

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
