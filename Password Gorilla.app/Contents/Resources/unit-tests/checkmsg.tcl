#
# checkmsg.tcl
#
# helper utility to pick all msgcat entries in the source file
# and to check if they are listed in the *.msg files
#
# Usage: tclsh checkmsg.tcl <sourcefile> <language>
# e.g. tclsh checkmsg.tcl ../sources/gorilla.tcl de
#
# for definition of <locale> see the Tcl manual for 'msgcat'
#
# *.msg are supposed to have the following content:
# mcmset de {
# ...
# }
#
# Todo:
# intelligent handling of "about ..." and "about" -> source code changes!
# im Quellcode alle mc's ohne "" Klammer ergänzen
#
# step 1: extract the mc messages
# step 2: create a new ROOT.msg file as a base for the other languages
# step 3: diff existing *.msg files for completeness
# step 4: add the missing entries and save the incomplete entries in a *.diff file
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
puts "Searching the msgcat files in '$msgcatDir'"
	# mcload $msgcatDir
	# mcload "/home/dia/Projekte/git/gorilla/sources/msgs"

	if { $lang eq "" } {
		set lang [lindex [split [mclocale] _] 0]
	} 
	mclocale $lang
	mcload "~/Projekte/gorilla/msgs"
	set localeMsg [file join $msgcatDir $lang.msg]
	
	if { [file exists $localeMsg] } {
		puts "Package msgcat loaded with resource file '$localeMsg'"
	} else {
		set fh [open $localeMsg w]
		puts $fh "mcmset $lang \{\n"
		puts "\}\n"
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

proc getMsgentries { source } {
	set msgs [list ]
	
		# explanation of the regexp:
		# begin with bracket and possible spaces non-greedy before mc
		# save all till the close bracket
		# subexpression is all between the brackets
		
	# +++ extract the [mc string] expressions +++
	
	foreach {fullmatch found} [regexp -inline -all {\[ *?mc (.*?)\]} $source] {
		# puts "+++ found: !$found!"
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

	foreach {fullmatch item} [regexp -inline -all {\"(.*?)\"} [lindex $desc 1] ]	{
		if { $item != "" } {
			lappend msgs [ string trim $item ]
		}
	}

	set msgs [append msgs " File Edit Login Security Help Group: Title: Username: Password:"]
	return [lsort -unique $msgs]
} ;# end of proc getMsgentries

proc createBaseMsgFile { data } {
	global baseMsg msgcatDir
	
	set fh [open "$msgcatDir/$baseMsg" w]
	# set fh stdout
	puts $fh "mcmset de \{"
	foreach item $data {
			if { [regexp {^\"} $item] } {
				puts $fh "$item $item \\"
			} else {
				puts $fh "\"$item\" \"$item\" \\"
			}
	}
	puts $fh "\}"
	close $fh
	puts "Root resource file $baseMsg created."
	return ok
} ;# end of proc createBaseMsgFile

proc getMsgList { file } {
	set msgList ""
	set file [file join "[pwd]/msgs" $file]
	if { ![file exists $file] } {
		puts "Error in 'getMsgList': Could not find $file"
		exit 1
	} ;# end if
	
	set fh [open $file r]
	set base [read $fh]
	close $fh

	set base [split $base "\n"]
	set base [lreplace $base 0 0]		;# delete the first line and check de, ru ...
	
	# puts $baseS
	foreach line $base { 
		set item [regexp -inline {\"(.*?)\"} $line]
		if { $item != "" } {
			# puts "$line : [lindex $item 1]"
			lappend msgList [lindex $item 1]
		# puts [lindex $item 1] 
		} ;# end if $item empty
				
	}
	return $msgList
} ;# end of proc getMsgList

proc getMsgMissing { entrylist } {

	set notfound [list ]
# puts "entrylist \n$entrylist"
	
	foreach item $entrylist {
# puts ">>> $item\n<<< [mc $item]"
# puts [expr { $item eq [mc $item] } ]
# puts [expr { $item eq [mc [join $item]] } ]
# puts [expr { [join $item] eq [mc [join $item]] } ]
# exit
		# Conditions to define a notfound entry:
		# 1) normal mc for strings without special characters
		# 2) mc for strings with \"
		# 3) mc for strings with \n
		
		if {	[mc $item] eq $item && \
					$item eq [mc [join $item]] && \
					[join $item] eq [mc [join $item]] } {
			lappend notfound $item
		} else {
# puts [join $item]
# puts "[mc [join $item]]"
		}
	}
	return $notfound
}

proc appendMsgs { msgList file } {
	global msgcatDir
# puts "\n??? msgList $msgList"
puts $file
	set fh [open $file r+]
	set content ""
	set content [read $fh]
	# puts "=== original content of $file:\n$content==="
# puts [lindex $content 0]
	set missing ""
	foreach item $msgList {
		append missing "\n\"$item\" \"undefined\" \\"
	}
puts "\n============\nmissing entries:\n============\n$missing"
	regsub {\n\}(\n*)} $content $missing content
	append content "\n\}\n"
# puts "+++ new content:\n$content+++"
	seek $fh 0
	puts $fh $content
	close $fh
}

proc showMsgUndefined { entrylist file } {
	set undefined [list ]
# puts "entrylist \n$entrylist"
	
	foreach item $entrylist {
# puts ">>> $item\n<<< [mc $item]"
# puts [expr { $item eq "undefined" } ]
# puts [expr { [mc [join $item]] eq "undefined" } ]
		# puts "+++ [lsearch $trans $item]"
		
		# Conditions to define a undefined entry:
		# 1) normal mc for strings without special characters
		# 2) mc for strings with \"
		# 3) mc for strings with \n
		
		if {	[mc $item] eq "undefined" || \
					[mc [join $item]] eq "undefined" } {
# puts ">>> $item\n<<< [mc $item]"
			lappend undefined $item
		} 
	}
	return $undefined
} ;# end of proc showMsgUndefined

proc checkMsg { source locale } {
	global msgcatDir
	
	set localeMsg [file join $msgcatDir $locale.msg]
	set sourceFile [ initCheckMsg $source $locale ]
	set allSourceEntries [getMsgentries $sourceFile]
# puts "--- Rückgabe: $allSourceEntries"

	if { [createBaseMsgFile $allSourceEntries] != "ok" } {
		puts "Error: Couldn't create file $baseMsg"
		exit 1
	}
	
	puts "Checking '$locale.msg' for missing entries ..."
	
	set msgMissingList [ getMsgMissing $allSourceEntries ]
# puts "### missing entries:\n$msgMissingList"

	if { $msgMissingList == "" } {
		puts "No msgcat entries missing."
		puts "Checking 'localeMsg' for undefined entries ..."
		set result [showMsgUndefined $allSourceEntries $localeMsg]
		if { $result eq "" } {
			puts "All mgscat entries are translated."
		} else {
			puts "\nThe following entries are not defined:\n"
				foreach item $result {
					puts $item
				} ;# end foreach
		} ;# end if
	} else {
		appendMsgs $msgMissingList $localeMsg
		puts "The missing msgcat entries have been appended to the file '$localeMsg'."
		puts "\nPlease edit these entries which are marked in the resource file '$localeMsg' as <undefined>.\nThen try a new check."
	}
	
	# check if any entries in the locale msg file have been deleted in the source code
	
} ;# end of proc checkMsg

# ============== Main ===================

########## set the global individual filenamees ##########################
set sourcefile [lindex $argv 0]	;# must be full pathname
set locale "[lindex $argv 1]"
set baseMsg en.msg
set msgcatDir [file join [file dirname [info script]] "../sources/msgs"]
##########################################################################

checkMsg $sourcefile $locale
