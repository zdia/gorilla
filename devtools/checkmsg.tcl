#
# checkmsg.tcl
#
# helper utility to pick all msgcat entries in the source file
# and to check if they are listed in the *.msg files
#
# Usage: tclsh checkmsg.tcl <sourcefile> <language>
# 
# e.g. 
# cd INSTALLPATH/devtools
# tclsh checkmsg.tcl ../sources/gorilla.tcl de
#
# for definition of <locale> see the Tcl manual for 'msgcat'
#
# *.msg are supposed to have the following content:
# mcmset de {
# "origin" "translation" \
# ...
# }
#
# Todo:
# intelligent handling of "about ..." and "about" -> source code changes!
#
# step 1: extract the mc messages in the source code
# step 2: load an eventually existing msg file and
# step 3: create a <locale>.msg.new file where untranslated entries
# are marked as undefined.
#
# Hint: 'locale -a' shows all available locale languages
#

proc initCheckMsg { file lang } {
	global msgcatDir
	#
	# does: loading package msgcat and reading the sourcefile content
	#
	package require msgcat
	namespace import msgcat::*
	
	# puts "Searching the msgcat files in '$msgcatDir'"

	if { $lang eq "" } {
		set lang [lindex [split [mclocale] _] 0]
	} 
	mclocale $lang
	# mcload "~/Projekte/gorilla/msgs"
	mcload $msgcatDir
	# mcload "/home/dia/Projekte/git/gorilla/sources/msgs"
	
	set localeMsg [file join $msgcatDir $lang.msg]
	
	if { [file exists $localeMsg] } {
		puts "Package msgcat loaded with resource file '$localeMsg'"
	} else {
		set fh [open $localeMsg w]
		puts $fh "mcmset $lang \{"
		puts $fh "\}"
		close $fh
		puts "Did not find '$localeMsg'. Created an empty resource file. Try checkmsg again."
		exit 1
	} ;# end if

	if {$file == ""} {
		puts stderr "need filename as argument"
	}
	if { ![file exists $file] } {
		puts "Could not find '$file'. Aborting."
		exit 1
	}
	set fsize [file size $file]
	set fh [open $file r]
	set content [ read $fh $fsize]
	close $fh
	return $content
} ;# end of proc initCheckMsg

proc getMsgEntriesFrom { source } {
	set msgs [list ]
	
		# explanation of the regexp:
		# begin with bracket and possible spaces non-greedy before mc
		# save all till the close bracket
		# subexpression is all between the brackets
		# if {($index > 2930) && ($index < 3000)} {puts "$index $line"}
		
	# +++ extract the [mc string] expressions +++
	foreach {fullmatch found} [regexp -inline -all -- {\[ *?mc (.*?)\]} $source ] {
		set found [string trim $found]
		set found [string trim $found \"]
		# puts "#$found#"
		
		# exclude variables
		if { ![regexp {^\$|^\"\$} $found] } {
			# puts $found
			lappend msgs $found
		# puts "=== $msgs"
		} ;# end if 
	}
	
	# +++ extract the menuitems in the ::gorilla::menu_desc string +++
	
	set desc [regexp -inline {set ::gorilla::menu_desc \{(.*)\} ;# end ::gorilla::menu_desc} $source ]
# puts "desc:\n$desc"
# puts [regexp -inline {set ::gorilla::menu_desc \{} $source ]
# puts [regexp -inline {\} ;# end ::gorilla::menu_desc} $source ]
	foreach {fullmatch item} [regexp -inline -all {\"(.*?)\"} [lindex $desc 1] ]	{
		if { $item != "" } {
			lappend msgs [ string trim $item ]
		}
	}
	
	return [lsort -unique $msgs]
} ;# end of proc getMsgEntriesFrom

proc createMsgFileFrom { entrylist lang} {
	# create new resource file
	# mark untranslated entries as "undefined"

	set newMsgEntries ""
	
	set fileHandler [open $lang.msg.new w]
		
	puts $fileHandler "mcmset $lang \{ \\"
	
	foreach item $entrylist {
	# puts ">>> ![join $item]! --- <<< ![mc [join $item]]!"
		
		if { [join $item] eq [mc [join $item]] } {
			puts "not found: $item"
			puts $fileHandler "\"$item\" \"undefined\" \\"
			# if there is no translation available:
			# puts $fileHandler "\"$item\" \"$item\" \\"
		} else {
			puts $fileHandler "\"$item\" \"[mc [join $item]]\" \\"
		}
	}
	puts $fileHandler "\}"
	
	close $fileHandler
	
	return 
}

proc checkMsg { source locale } {
	global msgcatDir
	
	set localeMsg [file join $msgcatDir $locale.msg]
	
	set sourceFile [ initCheckMsg $source $locale ]
	
	set allSourceEntries [getMsgEntriesFrom $sourceFile]
# puts "--- Rückgabe: $allSourceEntries"

	puts "Creating '$locale.msg.new' ..."
	createMsgFileFrom $allSourceEntries $locale
		
} ;# end of proc checkMsg

# ============== Main ===================

########## set the global individual filenames ##########################
set sourcefile [lindex $argv 0]	;# must be full pathname
set locale "[lindex $argv 1]"
set baseMsg en.msg
set msgcatDir [file join [file dirname [info script]] "../sources/msgs"]
##########################################################################

checkMsg $sourcefile $locale
