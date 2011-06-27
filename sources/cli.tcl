# cli.tcl
#
# Command-line module for Password Gorilla
#
# Usage: gorilla ?options|database?
#
# gorilla testdb.psafe3				-> opens an existing db (GUI mode)
# gorilla -cli|--comand-line	-> enters the parsing loop and waits for commands
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 675 Mass Ave, Cambridge, MA 02139, USA.

# A copy of the GNU GPL may be found in the LICENCE.txt file in the main
# gorilla/sources directory.
				
namespace eval ::cli {
	# FIXME: Option -h causes error "Tk not found"
	# Error can be fixed if argv is cleaned at the very beginning before
	# requirung package Tk.
	# set ::gorilla::argv $argv
	# set argv ""
	#

	array set Commands {
		open					cli::Open
		quit					cli::Quit
		list					cli::List
		edit					cli::Edit
		save					cli::Save
		find					::cli::Find
	}

	set FieldList [list uuid group title user notes password url \
		create-time last-pass-change last-access lifetime last-modified]
		
} ;# end eval cli

# --------------- list of commands -------------------------------------
# list field rn	-> list single record rn
# list field		-> lists all field records
# list 					-> all records with all fields
#
# edit field rn
# 
# add group|login
# merge

proc ::cli::Save { } {
	set nativeName [file nativename $::gorilla::fileName] 
	if { ! [ file writable $nativeName ]	} {
		return [list ERROR "$::gorilla::fileName is write-protected."]
	}
	
	set majorVersion 2
	
	if {[$::gorilla::db hasHeaderField 0]} {
		set version [$::gorilla::db getHeaderField 0]
		if {[lindex $version 0] == 3} {
			set majorVersion 3
		}
	}
	
	if { [catch {pwsafe::writeToFile $::gorilla::db $nativeName $majorVersion } oops] } {
		return [list ERROR "$oops"]
	}
	
	# backup?
	return [list OK "Saved database [ file tail $::gorilla::fileName ]"]
} ;# end of proc Save

proc ::cli::Edit { args } {
	# edit field rn

	if { ! [info exists ::gorilla::db] } {
		return [list ERROR "No database available. Please type: \"open <database>\"."]
	}
	# check options
	if { [llength $args] < 2 } {
		return [list ERROR "Argument missing. Should be \"Edit field rn\"."]
	 }
	set field [lindex $args 0]
	if { [lsearch $::cli::FieldList $field] < 0 } {
		return [list ERROR "Invalid field. Must be: $::cli::FieldList"]
	}
	set rn [lindex $args 1]
	if { [lsearch [$::gorilla::db getAllRecordNumbers] $rn] < 0} {
		return [list ERROR "Invalid record-number. Possible values: 1-[lindex [$::gorilla::db getAllRecordNumbers] end]"]
	}
	
	# edit string with line-at-a-time mode
	# c.f http://wiki.tcl.tk/16139: tcl-readline
	puts "Old string $field #$rn: [ ::gorilla::dbget $field $rn ]"
	puts -nonewline "New string $field #$rn: "
	flush stdout
	gets stdin newString
	gorilla::dbset $field $rn $newString
	set ::gorilla::dirty 1
	return [list OK "$field #$rn: [ ::gorilla::dbget $field $rn ]"]
} ;# end of proc ::cli::Edit

proc ::cli::usage {} {
	puts stdout "usage: [file tail $::argv0] \[Options\|<database>\]"
	puts stdout "\nOptions:"
	puts stdout "  --rc <name>\t\tUse <name> as configuration file (not the Registry)."
	# puts stdout "   --norc       Do not use a configuration file (or the Registry)."
	puts stdout "  --sourcedoc\t\tCreate source documentation with Ruff."
	puts stdout "  -t, --test\t\tOpen directly test database testdb.psafe3"
	puts stdout "  --tcltest\t\tRun all tcltest modules for Password Gorilla."
	puts stdout "  -cli, --command-line\tUse Password Gorilla in command-line mode."
	puts stdout "  --chkmsgcat\t\tRedefine msgcat::unknown for internal use."
	puts stdout "  --help\t\tShow this message."
	puts stdout "  <database>\t\tOpen <database> on startup."
}

proc ::cli::Norc {} {
	# This option is useful only for Windows users who want to use the registry
	set ::gorilla::preference(norc) 1
}

proc ::cli::Quit {} {
	if { $::gorilla::dirty } {
		puts -nonewline "Database has changed. Save it? ([mc yes]|[mc no]) :"
		flush stdout
		set choice [read stdin 1]
		if { $choice eq [string index [mc yes] 0] } {
			::cli::Save
			puts "Database saved"
		}
	}
	exit
} ;# end of proc ::cli::Quit

proc ::cli::Open { fileName } {
	# Note: for test purposes the filename is preset!
	set fileName [file join $::gorillaDir ../unit-tests testdb.psafe3]
	
	if { ![file exists $fileName] } {
		return [ list ERROR [mc "Could not find $file."] ]
		# mc ERROR-OpenError-nofile
	} ;# end if

	if {$::gorilla::dirty} {
		puts "should we save the db?"
	}

	set ::gorilla::collectedTicks [list [clock clicks]]
	gorilla::InitPRNG [join $::gorilla::collectedTicks -] ;# not a very good seed yet
	set newdb [pwsafe::createFromFile $fileName test ::gorilla::openPercent]
	# if newdb eq "" then return [list ERROR [mc "Could not open $filename"]]

	if {[info exists ::gorilla::db]} {
		itcl::delete object $::gorilla::db
	}
	
	set nativeName [file nativename $fileName]
	set ::gorilla::fileName $fileName
	set ::gorilla::db $newdb
	set ::gorilla::dirty 0
	
# puts "Debug fileName: $fileName newdb: $newdb"
	
	return [ list OK [mc "Ok. Actual database is %s." $fileName] ]
	# mc STATUS-Open-ok
} ;# end of proc ::cli::Open

proc ::cli::CheckRecordNr { rn } {
	# range
	if { $rn ni [$::gorilla::db getAllRecordNumbers] } {
		return [list ERROR  "Invalid record-number. Possible values: 1-[lindex [$::gorilla::db getAllRecordNumbers] end]"]
	}
	return [list OK $rn]
} ;# end of proc

proc ::cli::List { args } {
	# list field fieldname rn	-> list single record rn
	# list field fieldname		-> lists all records for fieldname
	# list 					-> all records with all fields (treeview?)
	# list rn	-> list single record
	# list group groupname -> all records in a group
	# list group -> all groupnames

	if { ! [info exists ::gorilla::db] } {
		return [list ERROR "No database available. Please type: \"open <database>\"."]
	} ;# end if

	# check list options

	if { $args eq "" } {
		return [list OK "all fields, all records"]
	} ;# end if
	
	if { [string is integer [lindex $args 0]] } {
		set result [ ::cli::CheckRecordNr [lindex $args 0] ]
		if { [lindex $result 0] eq "ERROR" } {
			return $result
		} else {
			set rn [lindex $result 1]
			return [list OK "list record $rn"] 
		}
	} ;# end if

	set option [lindex $args 0]

	# array set cli::OptionsExecute { field cli::OptionField }
	# eval cli::OptionsExecute($option) $args
	
	switch $option {
		field {
			set fieldname [lindex $args 1]
			if { $fieldname ne ""} {
				if { $fieldname ni $::cli::FieldList } {
					return [list ERROR "Invalid field. Must be: $::cli::FieldList"]
				}
				set rn [lindex $args 2]
				if { $rn ne ""} {
					set result [ ::cli::CheckRecordNr $rn ]
					if { [lindex $result 0] eq "ERROR" } {
						return $result
					}
					return [list OK "$fieldname #$rn: [ ::gorilla::dbget $fieldname $rn ]"]
				} else {
					puts "field fieldname"
				}
			} else {
				puts field
			}
		}
		group {
			puts group
			if { [lindex $args 1] ne ""} {
				puts "group groupname"
			} else {
				puts group
			}
		}
		default {
			return [list ERROR  "Invalid option. Must be: field, group"]
		}
	} ;# end switch
	
	return

		set allrecords ""
		foreach rn [$::gorilla::db getAllRecordNumbers] {
			append allrecords "[ ::gorilla::dbget $field $rn ] "
		}
		return [list OK $allrecords]
	
} ;# end of proc ::cli::List

proc ::cli::Find { args } {
	# find the passed text in the records
	# Usage: find ?-field? text
	# find ?-g group? ?-f field? text
	# find -l, --list	-> list the fields where text is found
	# find -h, --help (lists all options)
	# find -nc, --nocase
	# find -t, --title
	# returns all records and all fields in which the text was found
	# args - text to search
	#
	# make an AND search if multiple words?

	# database open?

	set text [lindex $args 0]
	set found [list ]
	set rn 0
	set totalRecords [llength [$::gorilla::db getAllRecordNumbers]]

	set field title
	puts stdout "searching in $field ..."
 	while { $rn < $totalRecords } {
		incr rn
		# set percent [expr {int(100.*$recordsSearched/$totalRecords)}]
		# set ::gorilla::status "Searching ... ${percent}%"
		# set cs $::gorilla::preference(caseSensitiveFind)
		if { [string match *$text* [::gorilla::dbget $field $rn] ] } {
			lappend found $field "#$rn"
		} ;# end if
		
	} ;# end while

	if { [llength $found] == 0 } {
		return [list ERROR  [mc "Did not find \"%s\"." $text]]
	}

	return [ list OK [mc "found \"%s\" in %s" $text $found] ]

} ;# end of proc find

proc ::cli::ParseCommand { line } {
	# check if the passed command is valid. Return the line without
	# command name
	#
	# line - The line entered by the user on the console
	#

	# get a proper list without unnecessary white spaces
	set line [ regexp -all -inline {\S+} $line ]
	set command [lindex $line 0]

	if { ! [info exists ::cli::Commands($command)] } {
		return [list ERROR "Unknown command: \"$command\". - Possible commands:\
			[join [array names ::cli::Commands] ", "]"] 
	}
	return [list OK "$::cli::Commands($command) [lrange $line 1 end]"]
}

proc ::cli::MainLoop { } {
	# enters the main loop for the command-line module
	#
	# TODO: make use of package vt100 for color, cursor placement ...
	# replace gets by a editable input routine like Tcl-Readline

	puts "Password Gorilla Command-Line Module ($::gorillaVersion)\nType \"quit\" to exit"
	
	gorilla::Init

	set line ""
	while 1 {
		puts -nonewline "> "
		flush stdout
		gets stdin line
		
		set line [ cli::ParseCommand $line ]
		if { [lindex $line 0] eq "ERROR" } {
			puts [lindex $line 1]
		} else {
			set answer [ eval [lindex $line 1] ]
			# [lindex $answer 0] contains OK, ERROR ... perhaps we will need it
			puts [lindex $answer 1]
		}
	} ;# end while
	
	return
}
