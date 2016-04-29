#! /bin/sh
# the next line restarts using wish \
exec tclsh "$0" ${1+"$@"}

#
# ----------------------------------------------------------------------
# Password Gorilla, a password database manager
# ----------------------------------------------------------------------
#
# Copyright (c) 2005-2009 Frank Pilhofer
# Copyright (c) 2010-2013 Richard Ellis and Zbigniew Diaczyszyn
#
# Version 1.5.3.7 tested with ActiveState's Tcl/Tk 8.5.13.0
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
# with this program; if not, write to the Free Software Foundation 51
# Franklin Street, Suite 500 Boston, MA 02110-1335
# ----------------------------------------------------------------------
#
# For further information and contact see https:/github.com/zdia/gorilla
#

package provide app-gorilla 1.0

namespace eval ::gorilla {
	variable Version {$Revision: 1.5.3.7 $}

	# find the location of the install directory even when "executing" a symlink
	# pointing to the gorilla.tcl file
	if { [ file type [ info script ] ] eq "link" } {
		variable Dir [ file normalize [ file dirname [ file join [ file dirname [ info script ] ] [ file readlink [ info script ] ] ] ] ]
	} else {
		variable Dir [ file normalize [ file dirname [ info script ] ] ]
	}

	variable PicsDir [ file join $::gorilla::Dir pics ]
}

# ----------------------------------------------------------------------
# Make sure that our prerequisite packages are available. Don't want
# that to fail with a cryptic error message.
# ----------------------------------------------------------------------
#

if {[catch {package require Tk 8.5} oops]} {
	#
	# Because of using Themed Widgets we need Tk 8.5
	#

	puts "Password Gorilla has been unable to load Tk 8.5, which is required."
	puts "Reason: '$oops'"
	exit 1
}

# Fix the issue of TTk widgets having different default background colors
# from Tk widgets (esp.  toplevel widgets) by automatically placing a TTk
# frame in each toplevel when the toplevel is created - this way when
# widgets are positioned in the toplevel, what should show through behind
# them is the ::ttk::frame background color, not the ::tk::toplevel
# background color.

rename toplevel _toplevel
proc toplevel {path args} {
	_toplevel $path {*}$args
	::ttk::frame $path.ttkbkg
	place $path.ttkbkg -in $path -anchor nw -x 0 -y 0 -bordermode outside \
	                   -relheight 1.0 -relwidth 1.0
	# this lower should be redundant, but do it just to be sure
	lower $path.ttkbkg
	return $path
}

option add *Dialog.msg.wrapLength 6i

if {[catch {package require Tcl 8.5}]} {
	wm withdraw .
	tk_messageBox -type ok -icon error -default ok \
		-title "Need more recent Tcl/Tk" \
		-message "The Password Gorilla requires at least Tcl/Tk 8.5\
		to run. This smells like Tcl/Tk [info patchlevel].\
		Please upgrade."
	exit 1
}

# ----------------------------------------------------------------------

proc ::gorilla::if-platform? { test body } {

	if { $::tcl_platform(platform) eq $test } {
	  uplevel 1 $body
	}

	#ruff
	# Tests the tcl_platform(platform) global against passed parameter
	# test, and executes body if the test is true.
	#
	# test - value to compare against tcl_platform(platform) contents
	# body - script to execute when the test passes

} ; # end proc if-platform?

# ----------------------------------------------------------------------
# Note - the load-package proc is defined in the global namespace because it
#        is called from outside the gorilla namespace in order to load
#        packages

proc load-package { args } {
	# A helper proc to load packages.  This collects the details of "catching"
	# and reporting errors upon package loading into one single proc.
	#
	# args - package(s) to load

	foreach package $args {

		if { [ catch "package require $package" catchResult catchOptions ] } {

			# a package load error occurred - create log file and report to user

			set statusinfo [ subst {
-begin------------------------------------------------------------------
Statusinfo created [ clock format [ clock seconds ] -format "%b %d %Y %H:%M:%S" ]
Password Gorilla version: $::gorilla::Version
Failure to load package: $package
catch result: $catchResult
catch options: $catchOptions
auto_path: $::auto_path
modules path: [ ::tcl::tm::path list ]
tcl_platform: [ array get ::tcl_platform ]
info library: [ info library ]
gorilla::Dir: $::gorilla::Dir
gorilla::Dir contents:
	[ join [ glob -directory $::gorilla::Dir -nocomplain * ] "\n\t" ]
auto_path dir contents:
[ set result ""
  foreach dir $::auto_path {
    append result "$dir\n"
    append result "\t[ join [ glob -directory $dir -nocomplain -- * ] "\n\t" ]\n"
  } 
  return $result ]
modules dir contents:
[ set result ""
  foreach dir [ ::tcl::tm::path list ] {
    append result "$dir\n"
    append result "\t[ join [ glob -directory $dir -nocomplain -- * ] "\n\t" ]\n"
  }
  return $result ]
-end--------------------------------------------------------------------
} ] ; # end of subst

			# for Linux, put failure status log in users home dir - for anything
			# else, use "Desktop"
			
			if { $::tcl_platform(os) eq "Linux" } {
				set logfile [ file join ~ gorilla-debug-log ]
			} else {
				set logfile [ file join ~ Desktop gorilla-debug-log.txt ]
			}

			set logfile [ file normalize $logfile ]
						
			if { [ catch { set logfd [ open $logfile {WRONLY CREAT APPEND} ] } ] } {
				# could not create log file - limp along as best we can
				text .error
				pack .error
				.error insert end "\nPassword Gorilla was unable to create a debug log file.\n"
				.error insert end "Please copy and paste the contents of this window into am email to\nPWGorilla@t-online.de\n"
				.error insert end "Use Control+c to copy\n\n$statusinfo\n"
				.error tag add sel 0.0 end
				vwait forever
			} else {
				puts $logfd $statusinfo
				close $logfd
			} 
			
			# also output to the terminal as well
			puts $statusinfo

			set message "Couldn't find the package $package.\n$package is required for Password Gorilla\nThe file $logfile was created for debugging purposes.\nPlease mail this file to 'PWGorilla@t-online.de'.\nPassword Gorilla will now terminate."

			tk_messageBox -type ok -icon error -message $message
		
			exit

		} ; # end if catch package require

	} ; # end foreach package in args

} ; # end proc gorilla::load-package

load-package msgcat

namespace import msgcat::*

mcload [file join $::gorilla::Dir msgs]
# The message files will be loaded according to the system's actual
# language. During initialization of Gorilla's preferences the command
# 'mclocale' will set the language accoring to Gorilla's resource file.
# 
# Look out! If you use a file ROOT.msg in the msgs folder it will be used 
# without regard to the Unix LOCALE configuration

#
# The isaac and viewhelp packages should be in the current directory
#

foreach file {isaac.tcl viewhelp.tcl} {
	if {[catch {source [file join $::gorilla::Dir $file]} oops]} {
		wm withdraw .
		tk_messageBox -type ok -icon error -default ok \
			-title [ mc "Need %s" $file ] \
			-message [ mc "The Password Gorilla requires the \"%s\"\
			package. This seems to be an installation problem, as\
			this file ought to be part of the Password Gorilla\
			distribution.\n\nError message: %s" $file $oops ]
		exit 1
	}
} ; unset file

#
# Itcl 3.4 is in an subdirectory available to auto_path
# The environment variable ::env(ITCL_LIBRARY) is set 
# to the subdirectory Itcl3.4 in the pkgindex.tcl
# This is necessary for the embedded standalone version in MacOSX
#

if {[tk windowingsystem] == "aqua"}	{
	# set auto_path /Library/Tcl/teapot/package/macosx-universal/lib/Itcl3.4
	set auto_path ""
}

foreach testitdir [glob -nocomplain [file join $::gorilla::Dir itcl*]] {
	if {[file isdirectory $testitdir]} {
		lappend auto_path $testitdir
	}
} ; unset -nocomplain testitdir

#
# Check the subdirectories for needed packages
#

# Set our own install directory and our local tcllib directory as first
# elements in auto_path, so that local items will be found before system
# installed items
set auto_path [ list $::gorilla::Dir [ file join $::gorilla::Dir tcllib ] {*}$auto_path ]

# Initialize the Tcl modules system to look into modules/ directory
::tcl::tm::add [ file join $::gorilla::Dir modules ]

foreach package {Itcl pwsafe tooltip PWGprogress} {
	load-package $package
} ; unset package

#
# If installed, we can use the uuid package (part of Tcllib) to generate
# UUIDs for new logins, but we don't depend on it.
#

catch {package require uuid}

# Detect whether or not the file containing download sites exists
set ::gorilla::hasDownloadsFile [ file exists [ file join $::gorilla::Dir downloads.txt ] ]

#
# ----------------------------------------------------------------------
# Prepare and hide main window
# ----------------------------------------------------------------------
#

namespace eval gorilla {}

if {![info exists ::gorilla::init]} {
	wm withdraw .
	set ::gorilla::init 0
}

# ----------------------------------------------------------------------
# GUI and other Initialization
# ----------------------------------------------------------------------

proc gorilla::Init {} {
	set ::gorilla::status ""
	set ::gorilla::uniquenodeindex 0
	set ::gorilla::dirty 0
	set ::gorilla::overridePasswordPolicy 0
	set ::gorilla::isPRNGInitialized 0
	set ::gorilla::activeSelection 0
	catch {unset ::gorilla::dirName}
	catch {unset ::gorilla::fileName}
	catch {unset ::gorilla::db}
	catch {unset ::gorilla::statusClearId}
	catch {unset ::gorilla::clipboardClearId}
	catch {unset ::gorilla::idleTimeoutTimerId}

	if {[llength [trace info variable ::gorilla::status]] == 0} {
		trace add variable ::gorilla::status write ::gorilla::StatusModified
	}

	# New preferences system by Richard Ellis
	# 
	# This dict defines all the preference variables, their defaults, and
	# an anonymous validation proc for use in loading stored preferences
	# from disk.  The format is name of pref as key, each value being a
	# two element list.  Each two element list is preference default and
	# anonymous validation proc in that order.  The validation proc
	# returns true for valid, false for invalid.

	set ::gorilla::preference(all-preferences) {

		autoclearMultiplier    { 1       { {value} { expr { ( [ string is integer $value ] ) && ( $value >= 0 ) } } }         }
		autocopyUserid         { 0       { {value} { string is boolean $value } }                                             }
		backupPath             { {}      { {value} { file exists $value } }                                                   }
		browser-exe            { {}      { {value} { return true } }                                                          }
		browser-param          { {}      { {value} { return true } }                                                          }
		caseSensitiveFind      { 0       { {value} { string is boolean $value } }                                             }
		clearClipboardAfter    { 0       { {value} { expr { ( [ string is integer $value ] ) && ( $value >= 0 ) } } }         }
		defaultVersion         { 3       { {value} { expr { ( [ string is integer $value ] ) && ( $value >= 0 ) } } }         }
		doubleClickAction      { nothing { {value} { return true } }                                                          }
		exportAsUnicode        { 0       { {value} { string is boolean $value } }                                             }
		exportFieldSeparator   { ,       { {value} { expr { ( [ string length $value ] == 1 ) && ( $value in [list , \; :] ) } } } }
		exportIncludeNotes     { 1       { {value} { string is boolean $value } }                                             }
		exportIncludePassword  { 1       { {value} { string is boolean $value } }                                             }
		exportShowWarning      { 1       { {value} { string is boolean $value } }                                             }
		findInAny              { 0       { {value} { string is boolean $value } }                                             }
		findInNotes            { 1       { {value} { string is boolean $value } }                                             }
		findInPassword         { 1       { {value} { string is boolean $value } }                                             }
		findInTitle            { 1       { {value} { string is boolean $value } }                                             }
		findInURL              { 1       { {value} { string is boolean $value } }                                             }
		findInUsername         { 1       { {value} { string is boolean $value } }                                             }
		findThisText           { {}      { {value} { return true } }                                                          }
		fontsize               { 10      { {value} { string is integer $value } }                                             }
		gorillaAutocopy        { 0       { {value} { string is boolean $value } }                                             }
		gorillaIcon            { 0       { {value} { string is boolean $value } }                                             }
		hideLogins             { 0       { {value} { string is boolean $value } }                                             }
		iconifyOnAutolock      { 0       { {value} { string is boolean $value } }                                             }
		idleTimeoutDefault     { 5       { {value} { expr { ( [ string is integer $value ] ) && ( $value >= 0 ) } } }         }
		keepBackupFile         { 0       { {value} { string is boolean $value } }                                             }
		lang                   { en      { {value} { return true } }                                                          }
		lockDatabaseAfter      { 0       { {value} { expr { ( [ string is integer $value ] ) && ( $value >= 0 ) } } }         }
		lruSize                { 10      { {value} { expr { ( [ string is integer $value ] ) && ( $value >= 0 ) } } }         }
		lru                    { {}      { {value} { file exists $value } }                                                   }
		rememberGeometries     { 1       { {value} { string is boolean $value } }                                             }
		saveImmediatelyDefault { 0       { {value} { string is boolean $value } }                                             }
		timeStampBackup        { 0       { {value} { string is boolean $value } }                                             }
		unicodeSupport         { 1       { {value} { expr { ( [ string is integer $value ] ) && ( $value >= 0 ) } } }         }

	} ; # end set ::gorilla::preferences(all-preferences)

	# initialize all the default preference settings now
	dict for {pref value} $::gorilla::preference(all-preferences) {
		set ::gorilla::preference($pref) [ lindex $value 0 ] 
	}
		
	# make the ::tcl::mathop operators and functions visible
	namespace path {::tcl::mathop ::tcl::mathfunc}
		
} ; # end proc gorilla::Init

# This callback traces writes to the ::gorilla::status variable, which
# is shown in the UI's status line. We arrange for the variable to be
# cleared after some time, so that potentially sensible information
# like "password copied to clipboard" does not show forever.
#

proc gorilla::StatusModified {name1 name2 op} {
	if {![string equal $::gorilla::status ""] && \
		![string equal $::gorilla::status "Ready."] && \
		![string equal $::gorilla::status [mc "Welcome to the Password Gorilla."]]} {
		if {[info exists ::gorilla::statusClearId]} {
			after cancel $::gorilla::statusClearId
		}
		set ::gorilla::statusClearId [after 5000 ::gorilla::ClearStatus]
	} else {
		if {[info exists ::gorilla::statusClearId]} {
			after cancel $::gorilla::statusClearId
		}
	}	
	.status configure -text $::gorilla::status
}

proc gorilla::Feedback { message } {

	# A proc to place a message string into the Gorilla status line.  This
	# encapuslates the "set" to a global var plus the update idletasks for
	# the status line into a single proc, making the code elsewhere slightly
	# cleaner.
	#
	# message - the message string to be placed in the status line.
	#
	# returns GORILLA_OK as it should always perform its task
	
	set ::gorilla::status $message
	update idletasks
	
	return GORILLA_OK

} ; # end proc gorilla::Feedback

proc gorilla::ClearStatus {} {
	catch {unset ::gorilla::statusClearId}
	set ::gorilla::status ""
}

proc gorilla::InitGui {} {
	# themed widgets do'nt know a resource database
	# option add *Button.font {Helvetica 10 bold}
	# option add *title.font {Helvetica 16 bold}
	option add *Menu.tearOff 0
	
	menu .mbar

	# Struktur im menu_desc(ription):
	# label	widgetname {item tag command shortcut}

	# the "tag" value is used to group menu entries for parallel
	# enablement/disablement via the setmenustate proc

	set meta Control
	set menu_meta Ctrl
		
	if {[tk windowingsystem] == "aqua"}	{
		set meta Command
		set menu_meta Cmd
		# mac is showing the Apple key icon but app is hanging if a procedure
		# is calling a vwait loop. So we just show the letter. Both meta keys
		# are working later on (Tk 8.5.8)
		# set menu_meta ""
	}

	# Note - the string below, because it is passed through subst, needs
	# to be formatted as a proper string representation of a list.  That
	# is why all of the [mc] calls are surrounded by quotes.  This
	# assures that the result of the [mc] call (unless the result
	# contains a ") will be a proper single element of the string rep.
	# of a list.
	
	set ::gorilla::menu_desc [ subst {
		"[ mc File ]" file {"[ mc New ] ..."         {}   gorilla::New         ""
		                    "[ mc Open ] ..."        {}   gorilla::Open        $menu_meta+O
		                    "[ mc Merge ] ..."       open gorilla::Merge       ""
		                    "[ mc Save ]"            save gorilla::Save        $menu_meta+S
		                    "[ mc "Save As" ] ..."   open gorilla::SaveAs      ""
		                    separator                ""   ""                   ""
		                    "[ mc Export ] ..."      open gorilla::Export      ""
		                    "[ mc Import ] ..."      open gorilla::Import      ""
		                    separator                mac  ""                   ""
		                    "[ mc Preferences ] ..." mac  gorilla::Preferences ""
		                    separator                mac  ""                   ""
		                    "[ mc Exit ]"            mac  gorilla::Exit        $menu_meta+X
		                   }

		"[ mc Edit ]" edit {"[ mc "Copy Username" ]"   login  {gorilla::CopyToClipboard Username} $menu_meta+U
		                    "[ mc "Copy Password" ]"   login  {gorilla::CopyToClipboard Password} $menu_meta+P
		                    "[ mc "Copy URL" ]"        login  {gorilla::CopyToClipboard URL}      $menu_meta+W
		                    separator                  ""     ""                                  ""
		                    "[ mc "Clear Clipboard" ]" ""     gorilla::ClearClipboard             $menu_meta+C
		                    separator                  ""     ""                                  ""
		                    "[ mc Find ] ..."          open   gorilla::Find                       $menu_meta+F
		                    "[ mc "Find next" ]"       open   gorilla::FindNext                   $menu_meta+G
		                   }
		                
		"[ mc Login ]" login {"[ mc "Add Login" ]"        open  gorilla::AddLogin    $menu_meta+A
				      "[ mc "Edit Login" ]"       open  gorilla::EditLogin   $menu_meta+E
				      "[ mc "View Login" ]"       open  gorilla::ViewLogin   $menu_meta+V
				      "[ mc "Delete Login" ]"     login gorilla::DeleteLogin ""
				      "[ mc "Move Login" ] ..."   login gorilla::MoveLogin   ""
				      separator                   ""    ""                   ""
				      "[ mc "Add Group" ] ..."    open  gorilla::AddGroup    ""
				      "[ mc "Add Subgroup" ] ..." group gorilla::AddSubgroup ""
				      "[ mc "Rename Group" ] ..." group gorilla::RenameGroup ""
				      "[ mc "Move Group" ] ..."   group gorilla::MoveGroup   ""
				      "[ mc "Delete Group" ]"     group gorilla::DeleteGroup ""
				     }
				
		"[ mc Security ]" security {"[ mc "Password Policy" ] ..."        open gorilla::PasswordPolicy            ""
				            "[ mc Customize ] ..."                open gorilla::DatabasePreferencesDialog ""
				            separator                             ""   ""                                 ""
				            "[ mc "Change Master Password" ] ..." open gorilla::ChangePassword            ""
				            separator                             ""   ""                                 ""
				            "[ mc "Lock now" ]"                   open gorilla::LockDatabase              $menu_meta+L
				           }

		"[ mc Help ]" help {"[ mc Help ] ..." mac  gorilla::Help    ""
				    "[ mc License ] ..."          ""   gorilla::License ""
				    "[ mc "Look for Update"]"     dld  gorilla::versionLookup ""
				    separator                     mac  ""  ""
				    "[ mc About ] ..."            mac tkAboutDialog ""
				   }

	} ] ;# end ::gorilla::menu_desc

	foreach {menu_name menu_widget menu_itemlist} $::gorilla::menu_desc {
		
		.mbar add cascade -label $menu_name -menu .mbar.$menu_widget
	
		menu .mbar.$menu_widget
		
		set taglist ""
		
		foreach {menu_item menu_tag menu_command shortcut} $menu_itemlist {
	
			# erstelle für jedes widget eine Tag-Liste
			lappend taglist $menu_tag
			if {$menu_tag eq "mac" && [tk windowingsystem] == "aqua"} {
				continue
			}
			if {$menu_item eq "separator"} {
				.mbar.$menu_widget add separator
			} else {
				.mbar.$menu_widget add command -label $menu_item \
					-command $menu_command -accelerator $shortcut
			} 	
		}
		set ::gorilla::tag_list($menu_widget) $taglist
	}
	
	# modify the "About" menuitem in the Apple application menu
	
	if {[tk windowingsystem] == "aqua"} {
		menu .mbar.apple
		.mbar add cascade -menu .mbar.apple
		.mbar.apple add command -label "[mc "About"] Password Gorilla" -command gorilla::About
		# .mbar.apple add separator
	}

	# This command must be last menu oriented command due to TkCocoa for MacOSX
	. configure -menu .mbar

	# note - if the help menu widget name changes, this will need to be updated	
  # To generate documentation use command line: gorilla --sourcedoc
	# ::gorilla::addRufftoHelp .mbar.help

	# menueintrag deaktivieren mit dem tag "login
	# suche in menu_tag(widget) in den Listen dort nach dem Tag "open" mit lsearch -all
	# etwa in $menu_tag(file) = {"" login}, ergibt index=2
	# Zuständige Prozedur: setmenustate .mbar login disabled/normal
	# Index des Menueintrags finden:

	# suche alle Einträge mit dem Tag tag und finde den Index
	# .mbar.file entryconfigure 2 -state disabled
 
	wm title . "Password Gorilla"
	wm iconname . "Gorilla"
	wm iconphoto . $::gorilla::images(application) 
	
	if {[info exists ::gorilla::preference(geometry,.)]} {
		TryResizeFromPreference .
	} else {
		wm geometry . 640x480
	}

	#---------------------------------------------------------------------
	# Arbeitsfläche bereitstellen unter Verwendung von ttk::treeview
	# Code aus ActiveTcl demo/tree.tcl
	#---------------------------------------------------------------------
	
	set tree [ttk::treeview .tree \
		-yscroll [ list .vsb set ] -xscroll [ list .hsb set ] -show tree \
		-style gorilla.Treeview]
	.tree tag configure red -foreground red
	.tree tag configure black -foreground black

	if {[tk windowingsystem] ne "aqua"} {
		set sbtype ttk::scrollbar
	} else {
		set sbtype scrollbar
	}
	$sbtype .vsb -orient vertical   -command [ list .tree yview ]
	$sbtype .hsb -orient horizontal -command [ list .tree xview ]

	ttk::label .status -relief sunken -padding [list 5 2]

	## Arrange the tree, its scrollbars, and the status line in the toplevel
	grid .tree   .vsb -sticky nsew
	# .hsb does not do anything at the moment - therefore do not display it
	#grid .hsb    x    -sticky news
	grid .status -    -sticky news
	grid columnconfigure . 0 -weight 1
	grid rowconfigure    . 0 -weight 1
	
	bind .tree <Double-Button-1> {gorilla::TreeNodeDouble [.tree focus]}
	bind .tree <Button-3> { gorilla::TreeNodePopup [ gorilla::GetSelectedNode %x %y ] }
	bind .tree <<TreeviewSelect>> gorilla::TreeNodeSelectionChanged
	
	# On the Macintosh, make the context menu also pop up on
	# Control-Left Mousebutton and button 2 <right-click>
	
	catch {
		if {[tk windowingsystem] == "aqua"} {
			bind .tree <$meta-Button-1> { gorilla::TreeNodePopup [ gorilla::GetSelectedNode %x %y ] }
			bind .tree <Button-2> { gorilla::TreeNodePopup [ gorilla::GetSelectedNode %x %y ] }
		}
	}
	
	#
	# remember widgets
	#

	set ::gorilla::toplevel(.) "."
	set ::gorilla::widgets(main) ".mbar"
	set ::gorilla::widgets(tree) ".tree"
	
	#
	# Initialize menu state
	#

	UpdateMenu
	# setmenustate .mbar group disabled
	# setmenustate .mbar login disabled
	
	#
	# bindings
	#

	catch {bind . <MouseWheel> "$tree yview scroll \[expr {-%D/120}\] units"}

	bind . <$meta-o> {.mbar.file invoke 1}
	bind . <$meta-s> {.mbar.file invoke 3}
	bind . <$meta-x> {.mbar.file invoke 11}
	
	bind . <$meta-u> {.mbar.edit invoke 0}
	bind . <$meta-p> {.mbar.edit invoke 1}
	bind . <$meta-w> {.mbar.edit invoke 2}
	bind . <$meta-c> {.mbar.edit invoke 4}
	bind . <$meta-f> {.mbar.edit invoke 6}
	bind . <$meta-g> {.mbar.edit invoke 7}

	bind . <$meta-a> {.mbar.login invoke 0}
	bind . <$meta-e> {.mbar.login invoke 1}
	bind . <$meta-v> {.mbar.login invoke 2}

	bind . <$meta-l> {.mbar.security invoke 5}

	# bind . <$meta-L> "gorilla::Reload"
	# bind . <$meta-R> "gorilla::Refresh"
	# bind . <$meta-C> "gorilla::ToggleConsole"
	# bind . <$meta-q> "gorilla::Exit"
	# bind . <$meta-q> "gorilla::msg"
	# ctrl-x ist auch exit, ctrl-q reicht

	if {[tk windowingsystem] == "aqua"}	{
		# for some reason, on MacOS, PWGorilla will "freeze" if the Cmd+o key is
		# used to access the "File->Open" function.  The "freeze" happens once
		# PGWorilla enters the vwait loop within the OpenDatabase proc.  For
		# some reason the event loop stops processing user input from that point
		# forward.  However, inserting a short amount of delay before invoking
		# the open dialog prevents the "freeze" from happening.  Note, this is a
		# workaround.  A true fix will involve rewriting the open dialog to
		# remove the internal vwait event loop.
		bind . <$meta-o> "after 150 [ bind . <$meta-o> ]"
	}


	#
	# Handler for the X Selection
	#

	selection handle -selection PRIMARY   . gorilla::XSelectionHandler
	selection handle -selection CLIPBOARD . gorilla::XSelectionHandler

	#
	# Handler for the WM_DELETE_WINDOW event, which is sent when the
	# user asks the window manager to destroy the application
	#

	wm protocol . WM_DELETE_WINDOW gorilla::Exit

	# attach drag and drop functionality to the tree
	::gorilla::dnd init $::gorilla::widgets(tree)

}

#
# Initialize the Pseudo Random Number Generator
#

proc gorilla::InitPRNG {{seed ""}} {

	# Initialize the ISAAC PRNG seed.  Takes one parameter.

	#
	# Try to compose a not very predictable seed
	#

	append seed "20041201"
	append seed [ clock seconds ] [ clock clicks ] [ pid ]
	append seed [ winfo id . ] [ winfo geometry . ] [ winfo pointerxy . ]
	set hashseed [ ::sha2::sha256 -bin $seed ]

	# Determine if a /dev/urandom device exists, if so attempt to obtain 992
	# bytes more random data to produce an even better seed.  Wrap everything
	# in a catch so that if something goes wrong, PWGorilla will continue on
	# as if nothing had happened - lack of a better seed value is not a reason
	# to abort.  This will also cover instances where [file] thinks urandom
	# exists and is readable, but open throws an error for some reason.
	
	if { [ file exists /dev/urandom ] && [ file readable /dev/urandom ] } {
		catch {
			set rfd [ open /dev/urandom {RDONLY BINARY} ]
			append hashseed [ read $rfd 992 ]
			close $rfd
		}
	}
	
	# Help the randomness for our friends on Windows or anywhere else that
	# /dev/urandom does not exist or is unreadable - this recommendation comes
	# from the IASSC webpage (http://burtleburtle.net/bob/rand/isaacafa.html)
	# where it states:
	#
	#   As ISAAC is intended to be a secure cipher, if you want to reseed it,
	#   one way is to use some other cipher to seed some initial version of
	#   ISAAC, then use ISAAC's output as a seed for other instances of ISAAC
	#   whenever they need to be reseeded.
	#
	# As it happens, PWGorilla calls this seed function twice.  Once when
	# first starting, then a second time after entry of the unlock password. 
	# The second call includes some additional entropy derived from timing the
	# time between keystrokes during password entry.  Leverage that second
	# call to add ISAAC feedback entropy when /dev/urandom has not been
	# available to pad out to 1024 bytes of seed material.
	
	if {    $::gorilla::isPRNGInitialized 
	     && ( [ string length $hashseed ] < 1024 ) } {
		while { [ string length $hashseed ] < 1024 } {
		  append hashseed [ binary format i [ ::isaac::int32 ] ]
		}
	}

	#
	# Init PRNG
	#
	#puts "seeding with [ string length $hashseed ] bytes" ; # debugging
	isaac::srand $hashseed
	set ::gorilla::isPRNGInitialized 1
	
	# The original version of this proc utilized the pwsafe v2 modified sha1
	# hash to scramble the incoming seed value.  In the time since PWGorilla
	# was first written, there have been some cryptanalysis results that have
	# weakened the sha1 hash function.  So this seems like a good time to move
	# up to a better hash.  In this case sha256.
	
	#ruff
	# seed - a value to use as the seed for the PRNG.  The input value will
	# have some more tidbits of system details appended to hopefully increase
	# the possible entropy and will then be hashed by sha256 to obtain 32
	# bytes of binary seed data.
	#
	# If /dev/urandom is available, it will be used to obtain 992 more bytes
	# of higher quality random data to fill out the full 256 by 32bit seed
	# size of the ISAAC PRNG.  If /dev/urandom is not available, ISAAC itself
	# will be used to pad out 992 additional bytes of seed data during a
	# second call to this proc by the password unlock code.
	#
	# Note as well that the choice of /dev/urandom for additional PRNG seed
	# randomness is purposeful.  The /dev/random device is defined as blocking
	# if there is insufficient entropy in the kernel random pool to generate
	# random output data.  Blocking on /dev/random will make all of PWGorilla
	# appear to hang, potentially for a quite lengthy and completely
	# indeterminate amount of time given that 992 bytes of data are being
	# read.
	#
	# 992 bytes of very good quality random data from /dev/urandom is an order
	# of magnitude or more (likely much more) better random seed source than
	# what PWGorilla was historically utilizing (16 bytes of modified sha1
	# output).  As such the fact that /dev/urandom is not defined as
	# cryptographic quality is mitigated somewhat by obtaining such a large
	# amount of data, of a much higher quality than previously, that the net
	# effect is that PWGorilla's random number generation has increased in
	# quality significantly on any system having a working /dev/urandom
	# device.  All without appearing to hang for a lengthy period of time.

} ; # end proc gorilla::InitPRNG

proc setmenustate {widget tag_pattern state} {
	if {$tag_pattern eq "all"} {
		foreach {menu_name menu_widget menu_itemlist} $::gorilla::menu_desc {
			set index 0
			foreach {title a b c } $menu_itemlist {
				if { $title ne "separator" } {
					$widget.$menu_widget entryconfigure $index -state $state
				}
				incr index
			}
		}
		if { [tk windowingsystem] eq "aqua" } {
			# appmenu's About
			.mbar.apple entryconfigure 0 -state $state
		}
		return
	}
	foreach {menu_name menu_widget menu_itemlist} $::gorilla::menu_desc {
		set result [lsearch -all $::gorilla::tag_list($menu_widget) $tag_pattern]
		foreach index $result {
			$widget.$menu_widget entryconfigure $index -state $state
		}	
	}
}

proc gorilla::getMenuState { menu } {

  # Walk a Tk "menu" hierarchy, building a script that captures the current
  # state (normal/disabled) of each item in the menu heirarchy.
  #
  # menu - The menu widget at which to start traversing the hierarchy.
  #
  # Returns a script which can be "eval'ed" to return the menu hierarchy to
  # the state it was in when this command was called.

  set result ""

  for {set idx 0} {$idx <= [ $menu index end ]} {incr idx} {
    if { [ catch {$menu entrycget $idx -menu } submenu ] } {
      if { ! [ catch {$menu entrycget $idx -state} state ] } {
        append result "$menu entryconfigure $idx -state $state" \n
      }
    } else {
      append result [ getMenuState $submenu ]
    }
  }

  return $result
} ; # end proc gorilla::getMenuState

proc gorilla::EvalIfStateNormal {menuentry index} {
	if {[$menuentry entrycget $index -state] == "normal"} {
		eval [$menuentry entrycget 0 -command]
	}
}

# ----------------------------------------------------------------------
# Tree Management: Select a node
# ----------------------------------------------------------------------
#

proc gorilla::GetSelectedNode { x y } {
	# returns node at mouse position
	return [ .tree identify row $x $y ]
}

proc gorilla::TreeNodeSelect {node} {
	ArrangeIdleTimeout
	set selection [$::gorilla::widgets(tree) selection]

	if {[llength $selection] > 0} {
		set currentselnode [lindex $selection 0]

		if {$node == $currentselnode} {
			return
		}
	}

	focus $::gorilla::widgets(tree)
	$::gorilla::widgets(tree) selection set $node
	$::gorilla::widgets(tree) see $node
	set ::gorilla::activeSelection 0
}

# proc gorilla::TreeNodeSelectionChanged {widget nodes} {
proc gorilla::TreeNodeSelectionChanged {} {
		UpdateMenu
		ArrangeIdleTimeout
}

#
# ----------------------------------------------------------------------
# Tree Management: Double click
# ----------------------------------------------------------------------
#
# Double click on a group toggles its openness
#; already implemented in ttk::treeview
# Double click on a login copies the password to the clipboard; implemented
#

proc gorilla::TreeNodeDouble {node} {
	ArrangeIdleTimeout
	focus $::gorilla::widgets(tree)
	$::gorilla::widgets(tree) see $node

	set data [$::gorilla::widgets(tree) item $node -values]
	set type [lindex $data 0]

	if {$type == "Group" || $type == "Root"} {
		# set open [$::gorilla::widgets(tree) itemcget $node -open]
		# if {$open} {
			# $::gorilla::widgets(tree) itemconfigure $node -open 0
		# } else {
			# $::gorilla::widgets(tree) itemconfigure $node -open 1
		# }
		return
	} else {
		switch -- $::gorilla::preference(doubleClickAction) {
			copyPassword {
				gorilla::CopyToClipboard Password
			}
			editLogin {
				gorilla::EditLogin
			}
			launchBrowser {
				::gorilla::LaunchBrowser [ ::gorilla::GetSelectedRecord ] 
			}
			default {
				# do nothing
			}
		}
	}
}

#
# ----------------------------------------------------------------------
# Tree Management: Popup
# ----------------------------------------------------------------------
#

proc gorilla::TreeNodePopup {node} {
	ArrangeIdleTimeout
	TreeNodeSelect $node

	set xpos [expr [winfo pointerx .] + 5]
	set ypos [expr [winfo pointery .] + 5]

	set data [$::gorilla::widgets(tree) item $node -values]
	set type [lindex $data 0]

	switch -- $type {
		Root -
		Group {
			GroupPopup $node $xpos $ypos
		}
		Login {
			LoginPopup $node $xpos $ypos
		}
	}
}

# ----------------------------------------------------------------------
# Tree Management: Popup for a Group
# ----------------------------------------------------------------------
#

proc gorilla::GroupPopup {node xpos ypos} {
	if {![info exists ::gorilla::widgets(popup,Group)]} {
		set ::gorilla::widgets(popup,Group) [menu .popupForGroup]
		$::gorilla::widgets(popup,Group) add command \
			-label [mc "Add Login"] \
			-command "::gorilla::LoginDialog::AddLogin"
		$::gorilla::widgets(popup,Group) add command \
			-label [mc "Add Subgroup"] \
			-command "gorilla::PopupAddSubgroup"
		$::gorilla::widgets(popup,Group) add command \
			-label [mc "Rename Group"] \
			-command "gorilla::PopupRenameGroup"
		$::gorilla::widgets(popup,Group) add separator
		$::gorilla::widgets(popup,Group) add command \
			-label [mc "Delete Group"] \
			-command "gorilla::PopupDeleteGroup"
	}

	set data [$::gorilla::widgets(tree) item $node -values]
	set type [lindex $data 0]

	if {$type == "Root"} {
		$::gorilla::widgets(popup,Group) entryconfigure 2 -state disabled
		$::gorilla::widgets(popup,Group) entryconfigure 4 -state disabled
	} else {
		$::gorilla::widgets(popup,Group) entryconfigure 2 -state normal
		$::gorilla::widgets(popup,Group) entryconfigure 4 -state normal
	}

	# this catch is necessary to prevent a "grab failed" error
	# when opening a menu while another app is holding the
	# "grab"
	catch { tk_popup $::gorilla::widgets(popup,Group) $xpos $ypos }
}

proc gorilla::LookupNodeData { node } {

	# Takes a treeview node ID value and returns the node values and the
	# node type value as a list.
	#
	# node - a treeview node identifier

	set data [ $::gorilla::widgets(tree) item $node -values ]
	set type [ lindex $data 0 ]

	return [ list $data $type ]

} ; # end proc gorilla::LookupNodeData

proc gorilla::PopupAddSubgroup {} {
	gorilla::AddSubgroup
}

proc gorilla::PopupDeleteGroup {} {
	gorilla::DeleteGroup
}

proc gorilla::PopupRenameGroup {} {
	gorilla::RenameGroup
}


# ----------------------------------------------------------------------
# Tree Management: Popup for a Login
# ----------------------------------------------------------------------
#

proc gorilla::LoginPopup {node xpos ypos} {
	# Creates the popup menu widget for the right clicks on a tree item
	# node - node index for right-clicked tree item
	# xpos, ypos - root coordinates for the popup menu
	if {![info exists ::gorilla::widgets(popup,Login)]} {
		set ::gorilla::widgets(popup,Login) [menu .popupForLogin]
		$::gorilla::widgets(popup,Login) add command \
			-label [mc "Open URL"] \
			-command { ::gorilla::LaunchBrowser [ ::gorilla::GetSelectedRecord ] }
		$::gorilla::widgets(popup,Login) add command \
			-label [mc "Copy Username to Clipboard"] \
			-command "gorilla::PopupCopyUsername"
		$::gorilla::widgets(popup,Login) add command \
			-label [mc "Copy Password to Clipboard"] \
			-command "gorilla::PopupCopyPassword"
		$::gorilla::widgets(popup,Login) add command \
			-label [mc "Copy URL to Clipboard"] \
			-command "gorilla::PopupCopyURL"
		$::gorilla::widgets(popup,Login) add separator
		$::gorilla::widgets(popup,Login) add command \
			-label [mc "Add Login"] \
			-command "::gorilla::LoginDialog::AddLogin"
		$::gorilla::widgets(popup,Login) add command \
			-label [mc "Edit Login"] \
			-command "gorilla::PopupEditLogin"
		$::gorilla::widgets(popup,Login) add command \
			-label [mc "View Login"] \
			-command "gorilla::PopupViewLogin"
		$::gorilla::widgets(popup,Login) add separator
		$::gorilla::widgets(popup,Login) add cascade \
			-label [ mc "Move Login to:" ] \
			-menu [ set submenu $::gorilla::widgets(popup,Login).movesub ]
		$::gorilla::widgets(popup,Login) add separator 
		$::gorilla::widgets(popup,Login) add command \
			-label [mc "Delete Login"] \
			-command "gorilla::PopupDeleteLogin"
			
		# now setup the cascade menu
		menu $submenu -postcommand [ list ::gorilla::populateLoginPopup $submenu ]
	}

	# this catch is necessary to prevent a "grab failed" error
	# when opening a menu while another app is holding the
	# "grab"
	catch { tk_popup $::gorilla::widgets(popup,Login) $xpos $ypos }
}

proc gorilla::populateLoginPopup { win } {

	# builds the dynamic menu of group names for the right click move-to
	# function

	$win delete 0 end
	lassign [ ::gorilla::get-selected-tree-data ] node type rn 
	
	# count is used to "split" the menu into elements of 20 units each
	set count -1
	foreach group [ lsort [ array names ::gorilla::groupNodes ] ] {
		incr count
		set grouplist [ split $group "." ]
		set grouplen [ llength $grouplist ]
		if { $grouplen <= 1 } { 
		  set leader ""
		} else {
		  set leader "[ string repeat "   " [ expr { $grouplen - 2 } ] ] \u2022 "
		}
		$win add command -label "$leader[ lindex $grouplist end ]" -command [ list ::gorilla::MoveTreeNode $node $::gorilla::groupNodes($group) ] \
		                 -columnbreak [ expr { ( $count % 20 ) == 0 } ]
	}

} ; # end proc gorilla::populateLoginPopup

proc gorilla::PopupEditLogin {} {
	::gorilla::EditLogin
}

proc gorilla::PopupViewLogin {} {
	::gorilla::ViewLogin
}

proc gorilla::PopupCopyUsername {} {
	gorilla::CopyToClipboard Username
}

proc gorilla::PopupCopyPassword {} {
	gorilla::CopyToClipboard Password
}

proc gorilla::PopupCopyURL {} {
	gorilla::CopyToClipboard URL
}

proc gorilla::PopupDeleteLogin {} {
	::gorilla::DeleteLogin
}


# ----------------------------------------------------------------------
# New
# ----------------------------------------------------------------------
#

#
# Attempt to resize a toplevel window based on our preference
#

proc gorilla::TryResizeFromPreference {top} {
	if {!$::gorilla::preference(rememberGeometries)} {
		return
	}
	if {![info exists ::gorilla::preference(geometry,$top)]} {
		return
	}
	if {[scan $::gorilla::preference(geometry,$top) "%dx%d" width height] != 2} {
		unset ::gorilla::preference(geometry,$top)
		return
	}
	if {$width < 10 || $width > [winfo screenwidth .] || \
		$height < 10 || $height > [winfo screenheight .]} {
		unset ::gorilla::preference(geometry,$top)
		return
	}
	wm geometry $top ${width}x${height}
}

proc gorilla::CollectTicks {} {
	lappend ::gorilla::collectedTicks [clock clicks]
}

proc gorilla::New {} {
	ArrangeIdleTimeout

	#
	# If the current database was modified, give user a chance to think
	#

	if {$::gorilla::dirty} {
		set answer [tk_messageBox -parent . \
		-type yesnocancel -icon warning -default yes \
		-title [ mc "Save changes?" ] \
		-message [ mc "The current password database is modified. Do you want to save the current database before creating the new database?"]]

		# switch $answer {}
		# yes {}
		# no {aktuelle Datenbank schließen, Variable neu initialisieren}
		# default {return}
		
		if {$answer == "yes"} {
			if {[info exists ::gorilla::fileName]} {
				if { [::gorilla::Save] ne "GORILLA_OK" } {
					return
				}
			} else {
				if { [::gorilla::SaveAs] ne "GORILLA_OK" } {
					return
				}
			}
		} elseif {$answer != "no"} {
			return
		}
	}

	#
	# Timing between clicks is used for our initial random seed
	#

	set ::gorilla::collectedTicks [list [clock clicks]]
	gorilla::InitPRNG [join $::gorilla::collectedTicks -] ;# not a very good seed yet

	if { [catch {set password [GetPassword 1 [mc "New Database: Choose Master Password"]]} \
		error] } {
		# canceled
		return
	}

	lappend ::gorilla::collectedTicks [clock clicks]
	gorilla::InitPRNG [join $::gorilla::collectedTicks -] ;# much better seed now

	set myOldCursor [. cget -cursor]
	. configure -cursor watch
	update idletasks

	wm title . [mc "Password Gorilla - <New Database>"]

	# Aufräumarbeiten
	if {[info exists ::gorilla::db]} {
		itcl::delete object $::gorilla::db
	}
	set ::gorilla::dirty 0

	# create an pwsafe object ::gorilla::db 
	# with accessible by methods like: GetPreference <name>
	set ::gorilla::db [namespace current]::[pwsafe::db \#auto $password]
	pwsafe::int::randomizeVar password
	catch {unset ::gorilla::fileName}

	#
	# Apply defaults: auto-save, idle timeout, version, Unicode support
	#

	$::gorilla::db setPreference SaveImmediately \
	$::gorilla::preference(saveImmediatelyDefault)

	if {$::gorilla::preference(idleTimeoutDefault) > 0} {
		$::gorilla::db setPreference LockOnIdleTimeout 1
		$::gorilla::db setPreference IdleTimeout \
		$::gorilla::preference(idleTimeoutDefault)
	} else {
		$::gorilla::db setPreference LockOnIdleTimeout 0
	}

	if {$::gorilla::preference(defaultVersion) == 3} {
		$::gorilla::db setHeaderField 0 [list 3 0]
	}

	$::gorilla::db setPreference IsUTF8 \
	$::gorilla::preference(unicodeSupport)

	$::gorilla::widgets(tree) selection set {}		
	# pathname delete itemList ;# Baum löschen
	catch {	$::gorilla::widgets(tree) delete [$::gorilla::widgets(tree) children {}] }
	# catch {	$::gorilla::widgets(tree) delete [$::gorilla::widgets(tree) nodes root] }
	
# ttk:treeview: pathname insert 	parent index ?-id id? options... 
# BWidget: pathName insert				index	parent	node	?option value...? 

	$::gorilla::widgets(tree) insert {} end -id "RootNode" \
			-open true \
			-text [mc "<New Database>"]\
			-values [list Root] \
			-image $::gorilla::images(group) 
	set ::gorilla::status [mc "Add logins using <Add Login> in the <Login> menu."]
	. configure -cursor $myOldCursor

	# Must also unset the cache of group names to ttk::treeview node identifiers
	unset -nocomplain ::gorilla::groupNodes

	if {[$::gorilla::db getPreference "SaveImmediately"]} {
		gorilla::SaveAs
	}
	UpdateMenu
}

# ----------------------------------------------------------------------
# Open a database file; used by "Open" and "Merge"
# ----------------------------------------------------------------------
#

proc gorilla::DestroyOpenDatabaseDialog {} {
	set ::gorilla::guimutex 2
}

;# proc gorilla::OpenDatabase {title defaultFile} {}
	
# proc gorilla::OpenDatabase {title {defaultFile ""}} {
proc gorilla::OpenDatabase {title {defaultFile ""} {allowNew 0}} {

	ArrangeIdleTimeout
	set top .openDialog

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top -class "Gorilla"
		
		# TryResizeFromPreference $top

		set aframe [ttk::frame $top.right -padding [list 10 5]]
		
		if {$::gorilla::preference(gorillaIcon)} {
			# label $top.splash -bg "#ffffff" -image $::gorilla::images(splash)
			ttk::label $top.splash -image $::gorilla::images(splash)
			pack $top.splash -side left -fill both -padx 10 -pady 10
		}
		
		ttk::label $aframe.info -anchor w -width 80 -relief sunken \
			 -padding [list 5 5 5 5]
		# -background #F6F69E ;# helles Gelb

		ttk::labelframe $aframe.file -text [mc "Database:"] -width 70

		ttk::combobox $aframe.file.cb -width 40
		ttk::button $aframe.file.sel -image $::gorilla::images(browse) \
			-command "set ::gorilla::guimutex 3"

		pack $aframe.file.cb -side left -padx 10 -pady 10 -fill x -expand yes
		pack $aframe.file.sel -side right -padx 10 

		ttk::labelframe $aframe.pw -text [mc "Password:"] -width 40
		ttk::entry $aframe.pw.pw -width 40 -show "*"
		bind $aframe.pw.pw <KeyPress> "+::gorilla::CollectTicks"
		bind $aframe.pw.pw <KeyRelease> "+::gorilla::CollectTicks"
		
		pack $aframe.pw.pw -side left -padx 10 -pady 10 -fill x -expand yes

		ttk::frame $aframe.buts
		set but1 [ttk::button $aframe.buts.b1 -width 9 -text [ mc "OK" ]\
			-command "set ::gorilla::guimutex 1"]
		set but2 [ttk::button $aframe.buts.b2 -width 9 -text [mc "Exit"] \
			-command "set ::gorilla::guimutex 2"]
		set but3 [ttk::button $aframe.buts.b3 -width 9 -text [mc "New"] \
			-command "set ::gorilla::guimutex 4"]
		pack $but1 $but2 $but3 -side left -pady 10 -padx 5 -expand 1
	
		set sep [ttk::separator $aframe.sep -orient horizontal]
		
		grid $aframe.file -row 0 -column 0 -columnspan 2 -sticky we
		grid $aframe.pw $aframe.buts -pady 10
		grid $sep -sticky we -columnspan 2 -pady 5
		grid $aframe.info -row 3 -column 0 -columnspan 2 -pady 5 -sticky we 
		grid configure $aframe.pw  -sticky w
		grid configure $aframe.buts  -sticky nse
		
		bind $aframe.file.cb <Return> "set ::gorilla::guimutex 1"
		bind $aframe.pw.pw <Return> "set ::gorilla::guimutex 1"
		bind $aframe.buts.b1 <Return> "set ::gorilla::guimutex 1"
		bind $aframe.buts.b2 <Return> "set ::gorilla::guimutex 2"
		bind $aframe.buts.b3 <Return> "set ::gorilla::guimutex 4"
		pack $aframe -side right -fill both -expand yes

		pack $aframe -expand 1
		
		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW gorilla::DestroyOpenDatabaseDialog

	} else {
		set aframe $top.right
		wm deiconify $top
	}

	wm title $top $title
	wm iconphoto $top $::gorilla::images(application)

	$aframe.pw.pw delete 0 end

	if { [llength $::gorilla::preference(lru)] } {
		$aframe.file.cb configure -values $::gorilla::preference(lru)
		$aframe.file.cb current 0
	}

	if {$allowNew} {
		set info [mc "Select a database, and enter its password. Click \"New\" to create a new database."]
		$aframe.buts.b3 configure -state normal
	} else {
		set info [mc "Select a database, and enter its password."]
		$aframe.buts.b3 configure -state disabled
	}

	$aframe.info configure -text $info

	if {$defaultFile != ""} {
		catch {set ::gorilla::dirName [file dirname $defaultFile]}

		set values [$aframe.file.cb get]
		set found [lsearch -exact $values $defaultFile]

		if {$found != -1} {
			$aframe.file.cb current $found
		} else {
			set values [linsert $values 0 $defaultFile]
			$aframe.file.cb configure -values $values
			$aframe.file.cb current 0
		}
	}


	#
	# Disable the main menu, so that it is not accessible, even on the Mac.
	#
    
	setmenustate $::gorilla::widgets(main) all disabled

	#
	# Run dialog
	#

	set oldGrab [grab current .]

	update idletasks
	raise $top
	focus $aframe.pw.pw
	if {[tk windowingsystem] != "aqua"} {
		catch {grab $top}
	}

	#
	# Timing between clicks is used for our initial random seed
	#

	set ::gorilla::collectedTicks [list [clock clicks]]
	gorilla::InitPRNG [join $::gorilla::collectedTicks -] ;# not a very good seed yet

	while {42} {
		ArrangeIdleTimeout
		set ::gorilla::guimutex 0
		vwait ::gorilla::guimutex

		lappend myClicks [clock clicks]

		if {$::gorilla::guimutex == 2} {
			# Cancel
			break
		} elseif {$::gorilla::guimutex == 4} {
			# New
			break
		} elseif {$::gorilla::guimutex == 1} {
			set fileName [$aframe.file.cb get]
			set nativeName [file nativename $fileName]

			if {$fileName == ""} {
				tk_messageBox -parent $top -type ok -icon error -default ok \
					-title [mc "No File"] \
					-message [mc "Please select a password database."]
				continue
			}

			# work around an issue with "file readable" and Windows samba mounts
			# by simply attempting to open the PWFile in read only mode.  If the
			# open succeeds then we have read access.  If it fails, we don't have
			# access of some form.
			
			# If the open succeeds, immediately close the file because the open is
			# just a test for access.
			
			if { [ catch { close [ open $fileName RDONLY ] } ] } {
				# also generate a more meaningful error message
				if { [ file exists $fileName ] } {
				  set error_message [ mc "The password database %s can not be read." $nativeName ]
				} else {
				  set error_message [ mc "The password database %s does not exist." $nativeName ]
				}
				tk_messageBox -parent $top -type ok -icon error -default ok \
					-title [ mc "Error Accessing File" ] \
					-message $error_message
				continue
			}

			$aframe.info configure -text [mc "Please be patient. Verifying password ..."]

			set myOldCursor [$top cget -cursor]
			set dotOldCursor [. cget -cursor]
			$top configure -cursor watch
			. configure -cursor watch
			update idletasks

			lappend ::gorilla::collectedTicks [clock clicks]
			gorilla::InitPRNG [join $::gorilla::collectedTicks -] ;# much better seed now

			set password [$aframe.pw.pw get]
			set pvar [ ::gorilla::progress init -win $aframe.info -message [ mc "Opening ... %d %%" ] -max 200 ]
			

#set a [ clock milliseconds ]
			if { [ catch { set newdb [ pwsafe::createFromFile $fileName $password \
						 $pvar ] } oops ] } {
				pwsafe::int::randomizeVar password
				::gorilla::progress finished $aframe.info
				. configure -cursor $dotOldCursor
				$top configure -cursor $myOldCursor

				tk_messageBox -parent $top -type ok -icon error -default ok \
					-title [mc "Error Opening Database"] \
					-message [mc "Can not open password database \"%s\": %s" $nativeName $oops]
				$aframe.info configure -text $info
				$aframe.pw.pw delete 0 end
				focus $aframe.pw.pw
				continue
			}
#set b [ clock milliseconds ]
#puts stderr "elapsed open time: [ expr { $b - $a } ]ms"
		# all seems well

			::gorilla::progress finished $aframe.info
			. configure -cursor $dotOldCursor
			$top configure -cursor $myOldCursor
			pwsafe::int::randomizeVar password
			break
		} elseif {$::gorilla::guimutex == 3} {

			set fileName [ filename_query Open -parent $top \
					-title [ mc "Browse for a password database ..." ] ]

			if {$fileName == ""} {
				continue
			}

			set nativeName [file nativename $fileName]
			catch {
				set ::gorilla::dirName [file dirname $fileName]
			}

			set values [$aframe.file.cb cget -values]
			set found [lsearch -exact $values $nativeName]

			if {$found != -1} {
				$aframe.file.cb current $found
			} else {
				set values [linsert $values 0 $nativeName]
				$aframe.file.cb configure -values $values
				$aframe.file.cb current 0
				# $aframe.file.cb setvalue @0
			}

			focus $aframe.pw.pw
		}
	} ;# end while

	set fileName [$aframe.file.cb get]
	set nativeName [file nativename $fileName]
	pwsafe::int::randomizeVar ::gorilla::collectedTicks

	# make sure collectedTicks is a proper list again after
	# having been randomized above - this avoids an error
	# message from the lappend in gorilla::CollectTicks when
	# attempting to lappend after randomizing the variable
	set ::gorilla::collectedTicks [ list [ clock clicks ] ] 

	$aframe.pw.pw configure -text ""

	if {$oldGrab != ""} {
		catch {grab $oldGrab}
	} else {
		catch {grab release $top}
	}

	wm withdraw $top
	update

	#
	# Re-enable the main menu.  The UpdateMenu call is needed to adjust the
	# individual menu entries based upon gorilla internal status.  Otherwise
	# every menu entry becomes enabled, even if it does not make sense for
	# that entry to be enabled at this time.
	#

	setmenustate $::gorilla::widgets(main) all normal
	UpdateMenu

	if {$::gorilla::guimutex == 2} {
		# Cancel
		return "Cancel"
	} elseif {$::gorilla::guimutex == 4} {
		# New
		return "New"
	}

	#
	# Add file to LRU preference
	#

	set found [lsearch -exact $::gorilla::preference(lru) $nativeName]
	if {$found == -1} {
		# not found
		set ::gorilla::preference(lru) [linsert $::gorilla::preference(lru) 0 $nativeName]
	} elseif {$found != 0} {
		set tmp [lreplace $::gorilla::preference(lru) $found $found]
		set ::gorilla::preference(lru) [linsert $tmp 0 $nativeName]
	}

	#
	# Show any warnings?
	#

	set dbWarnings [$newdb cget -warningsDuringOpen]

	if {[llength $dbWarnings] > 0} {
		set message $fileName
		append message ": " [join $dbWarnings "\n"]
		tk_messageBox -parent . \
			-type ok -icon warning -title "File Warning" \
			-message $message
	}

	#
	# All seems well
	#

	ArrangeIdleTimeout
	return [list "Open" $fileName $newdb]
}

#
# ----------------------------------------------------------------------
# Open a file
# ----------------------------------------------------------------------
#

# Open erhält eine Liste, die kann auch leer sein...

proc gorilla::Open {{defaultFile ""}} {

	#
	# If the current database was modified, give user a chance to think
	#

	if {$::gorilla::dirty} {
		set answer [tk_messageBox -parent . \
			-type yesnocancel -icon warning -default yes \
			-title [mc "Save changes?"] \
			-message [mc "The current password database is modified.\
			Do you want to save the database?\n\
			\"Yes\" saves the database, and continues to the \"Open File\" dialog.\n\
			\"No\" discards all changes, and continues to the \"Open File\" dialog.\n\
			\"Cancel\" returns to the main menu."] ]
		if {$answer == "yes"} {
			if {[info exists ::gorilla::fileName]} {
				if { [::gorilla::Save] ne "GORILLA_OK" } {
					return
				}
			} else {
				if { [::gorilla::SaveAs] ne "GORILLA_OK" } {
					return
				}
			}
		} elseif {$answer != "no"} {
			return
		}
	}

	if { $::gorilla::DEBUG(TEST) } {
		# Skip OpenDialog
		set ::gorilla::collectedTicks [list [clock clicks]]
		gorilla::InitPRNG [join $::gorilla::collectedTicks -] ;# not a very good seed yet
		set fileName [file join $::gorilla::Dir ../unit-tests testdb.psafe3]
		set newdb [pwsafe::createFromFile $fileName test ::gorilla::openPercent]
		set openInfo [list "Open" $fileName $newdb ]
	} else {
		set openInfo [OpenDatabase [mc "Open Password Database"] $defaultFile 1]
	}
	
	set action [lindex $openInfo 0]

	if {$action == "Cancel"} {
		return "Cancel"
	} elseif {$action == "New"} {
		gorilla::New
		return "New"
	}

	set fileName [lindex $openInfo 1]
	set newdb [lindex $openInfo 2]
	set nativeName [file nativename $fileName]

	wm title . "Password Gorilla - $nativeName"

	if {[info exists ::gorilla::db]} {
		itcl::delete object $::gorilla::db
	}

	set ::gorilla::status [mc "Password database %s loaded." $nativeName ]
	set ::gorilla::fileName $fileName
	set ::gorilla::db $newdb
	set ::gorilla::dirty 0

	$::gorilla::widgets(tree) selection set ""
	# delete all the tree
	# $::gorilla::widgets(tree) delete [$::gorilla::widgets(tree) nodes root]
	$::gorilla::widgets(tree) delete [$::gorilla::widgets(tree) children {}]
	
	
	catch {array unset ::gorilla::groupNodes}

	$::gorilla::widgets(tree) insert {} end -id "RootNode" \
		-open 1 \
		-image $::gorilla::images(group) \
		-text $nativeName \
		-values [list Root]

	FocusRootNode
	AddAllRecordsToTree
	UpdateMenu
	return "Open"
}

#
# ----------------------------------------------------------------------
# Non-modal password add/edit dialog boxes
# ----------------------------------------------------------------------
#

#
# Put everything into a namespace so that there is no interference with the
# rest of PWGorilla
#
# The code will be ready for refactoring in regard to OO facilities in Tcl/Tk 8.6
#

namespace eval ::gorilla::LoginDialog { 

	namespace path ::gorilla

	variable seq 0
	
	# The idle-windows list and the push/pop procs are used to impliment
	# window reuse like in the rest of PWGorilla.  However the normal
	# PWGorilla method of window reuse does not work when there are
	# multiple windows to be remembered.  Idle-windows is a stack of
	# toplevel names that are not in use and push/pop manipulate that
	# stack in the obvious manner
	 
	variable idle-windows [ list ]

	namespace import ::tcl::mathop::+ ::tcl::mathop::* ::tcl::mathop::/ 

	# arbiter is a dict used to prevent more than one open edit dialog for an
	# individual db record number

	variable arbiter [ dict create ]
  
# -----------------------------------------------------------------------------

	proc push { win } {

		# add an window name to the end of the namespace variable idle-windows
		# win - the window name to "push" onto the idle-windows stack variable
		# Side-effect: Modifes namespace variable idle-windows.
		#
		# This is used to maintain a list of "inactive" withdrawn dialogs for
		# reuse in future edit requests.  Such avoids having to rebuild both the
		# dialog as well as the dialog state space and GUI handling procs.

		variable idle-windows
		lappend idle-windows $win
	} ; # end proc push

# -----------------------------------------------------------------------------

	# see http://wiki.tcl.tk/1923
	proc K { x y } { set x }

# -----------------------------------------------------------------------------

	proc pop { } {

		# Remove a window name from the stack in the idle-windows namespace variable.
		# Side-effect: Modifes namespace variable idle-windows.
		#
		# This is used to maintain a list of "inactive" withdrawn dialogs for
		# reuse in future edit requests.  Such avoids having to rebuild both the
		# dialog as well as the dialog state space and GUI handling procs.

		variable idle-windows
		return [ K [ lindex ${idle-windows} end ] [ set idle-windows [ lrange ${idle-windows} 0 end-1 ] ] ]
		# returns the name of the window that was popped from the stack.
	}

# -----------------------------------------------------------------------------

	proc info { } {
		# A testing proc for debugging purposes
		variable idle-windows
		return "idle-windows -> '${idle-windows}'"
		# returns the contents of the idle-windows namespace variable stack
	}

# -----------------------------------------------------------------------------

	# parameters ================================================================
	# -rn       - record number to edit, default of -999 means create new record
	# -group    - initial group name to use for creation of a new record
	# -treenode - the ttk::treeview node ID for editing an existing record
	#           + This is simply passed through to the final Ok proc for use
	#           + in updating an existing record in the treeview.
	# ===========================================================================

	proc LoginDialog { args } {

		# Open a dialog to edit/create an entry in the login DB.
		#
		# -rn - Record number from Itcl login DB to edit.  Magic record number
		#  -999 is defined to mean edit a new (blank) record.  Defaults to -999
		#  if not provided.
		#
		# -group - Set initial "group" name to apply to a new record.  This
		#  initializes the "group" field of the edit dialog.
		#
		# -treenode - The ttk::treeview node ID of an existing record when a
		#  user requests editing of an existing record.  This is used to update
		#  the tree display when a user clicks "Ok" to their changes.
		#
		# Requirements: If -rn is not -999 then the record number must exist in
		# the Itcl DB when called.  In addition, to edit an existing record, the
		# -treenode value must also be passed in.
		#
		# Additionally, a simple check is made such that there is a one to one
		# mapping of existing record numbers to open edit dialogs.  It is
		# disallowed to edit the exact same record in two independent dialogs
		# simultaneously.

		variable arbiter

		if { 0 != [ expr { [ llength $args ] % 2 } ] } {
			error "[ namespace current ]::LoginDialog: Must have an even number of arguments."
		}

		ArrangeIdleTimeout

		# very simple command line handling, first set default values, then
		# overwrite those valies with args (if any)

		array set {} [ list -rn -999 -group "" -treenode "" ]
		array set {} $args

		# a bit of sanity checking of the inputs
		if { $(-rn) != -999 } {
			# != -999 means an attempt to edit an existing record
			if { $(-treenode) eq "" } {
				error "[ namespace current ]::LoginDialog: Editing an existing record requires that -treenode option be non-null."
			}
			if { ! [ $::gorilla::db existsRecord $(-rn) ] } {
				error "[ namespace current ]::LoginDialog: Can not edit a record number ('$(-rn)') which does not exist in the database."
			}

			# should only have one dialog open per unique record entry in the db

			if { [ dict exists $arbiter $(-rn) ] } {
				wm deiconify [ dict get $arbiter $(-rn) ]
				raise [ dict get $arbiter $(-rn) ]
				return
			}

		} ; # end if -rn != -999


		set top [ pop ] 
		if { $top ne "" } {

			set pvns [ get-pvns-from-toplevel $top ]

			wm deiconify $top

		} else {

			variable seq
			set top [ toplevel .nmLoginDialog$seq ]
			set pvns [ namespace eval [ namespace current ]::$seq { namespace current } ] ; # pvns -> private variable name space
			incr seq

			wm title $top [ mc "Add/Edit/View Login" ]
			wm protocol $top WM_DELETE_WINDOW [ namespace code [ list DestroyLoginDialog $top ] ]

			# add a binding to clean out the namespace if the window is ever explicity destroyed

# fixme - the catch is here for testing, should not be needed for production
			bind $top <Destroy> [ list catch "namespace delete $pvns" ]

			BuildLoginDialog $top $pvns
			
		} ; # end if top ne ""

		# store away -treenode value in the pvns for use later during processing
		# by the ${pvns}::Ok proc
		set ${pvns}::treenode $(-treenode)

		if { $(-rn) != -999 } {
			# remember that we are editing this -rn in this $top window
			dict set arbiter $(-rn) $top
		}

		set ::gorilla::toplevel($top) $top
		TryResizeFromPreference $top
		
		${pvns}::PopulateLoginDialog $(-rn) $(-group)

	} ; # end proc LoginDialog
	
# -----------------------------------------------------------------------------

	proc DestroyLoginDialog { win } {
	
		# Used to withdraw, reset, and store for later an edit dialog from the
		# screen.
		#
		# win - the toplevel name of the edit dialog to withdraw, reset, and
		#  store.
	
		variable arbiter
		unset -nocomplain ::gorilla::toplevel($win)
		push $win

		# unmap the ppf pane, if it is mapped - otherwise the width added by the
		# ppf pane will end up getting added as a base minwidth value - i.e.,
		# the window will be permanently wider than it should be.
		set [ get-pvns-from-toplevel $win ]::overridePasswordPolicy 0
		
		wm withdraw $win

		# remove the entry for this window from the arbiter dict
		dict unset arbiter [ set [ get-pvns-from-toplevel $win ]::rn ]

	} ; # end proc DestroyLoginDialog

# -----------------------------------------------------------------------------

	# the name of the private variable namespace is the numeric suffix of
	# the toplevel name, so extract the numeric suffix from the toplevel
	# name

	proc get-pvns-from-toplevel { top } {

		# Extracts the private namespace name for an edit dialog
		#
		# top - the toplevel name of an edit dialog from which to extract the
		#  private variable namespace
	  
		return [ namespace current ]::[ lindex [ regexp -inline {([0-9]+)$} $top ] 1 ] 
		
		# returns The name of the private variable namespace associated with the
		# passed toplevel name.
		
	} ; # end proc get-pvns-from-toplevel

# -----------------------------------------------------------------------------

	proc make-label { top text } {
	
		# A helper proc to generate a ttk::label element for the Edit Login
		# Dialog.  Collapses all of the details of label creation into one
		# place.  Also autogenerates a unique label name.
		#
		# top - the parent window of the new label window.
		#
		# text - the textual value to place in the label.  Will have a colon
		# appended and the result will then be passed through mc for
		# translation purposes (i.e., the colon becomes part of the "mc"
		# string for translation).
		#
		# Returns the generated label name.
	
		variable seq
		return [ ttk::label $top.l-[ incr seq ] -text [ wrap-measure "${text}:" ] -style Wrapping.TLabel ]
	} ; # end 

# -----------------------------------------------------------------------------

	proc BuildLoginDialog { top pvns } {

		# Builds out the widgets to create a single instance of an edit login
		# dialog window.
		#
		# top - the parent window for all of the component widgets.
		#
		# pvns - the private variable namespace which has been assigned to
		# this login dialog window to hold -textvariables and GUI event
		# callback procedures specific to this particular edit login window.
		#
		# Does not return any useful value to the caller.

		set widget(top) $top

		ttk::style configure Wrapping.TLabel -wraplength {} -anchor e -justify right -padding {10 0 5 0} 

		foreach {child label w} [ list group    [ mc Group    ] combobox \
		                               title    [ mc Title    ] entry    \
		                               url      [ mc URL      ] entry    \
		                               user     [ mc Username ] entry    \
		                               password [ mc Password ] entry  ] {
			grid [ make-label $top $label ] \
			     [ set widget($child) [ ttk::$w $top.e-$child -width 40 -textvariable ${pvns}::$child ] ] \
					-sticky news -pady 5
		} ; # end foreach {child label}

		# password should show "*" by default
		$widget(password) configure -show "*"
		
		# group combox box needs to receive its values list of group names
		$widget(group) configure -postcommand [ fill-combobox-with-grouplist $widget(group) ] 

		# The notes text widget - with scrollbar - in an embedded frame
		# because the text widget plus scrollbar needs to fit into the single
		# column holding all the other ttk::entries in the outer grid
		
		set textframe [ ttk::frame $top.e-notes-f ]
		set widget(notes) [ set ${pvns}::notes [ text $textframe.e-notes -width 40 -height 5 -wrap word -yscrollcommand [ list $textframe.vsb set ] ] ]
		grid $widget(notes) [ scrollbar $textframe.vsb -command [ list $widget(notes) yview ] ] -sticky news
		grid rowconfigure $textframe $widget(notes) -weight 1
		grid columnconfigure $textframe $widget(notes) -weight 1

		grid [ make-label $top [mc Notes] ] \
		     $textframe \
		     -sticky news -pady 5

		grid rowconfigure    $top $textframe -weight 1
		grid columnconfigure $top $textframe -weight 1

		set lastChangeList [list last-pass-change [mc "Last Password Change"] last-modified [mc "Last Modified"] ]
		
		foreach {child label} $lastChangeList {
			grid [ make-label $top $label ] \
			     [ ttk::label $top.e-$child -textvariable ${pvns}::$child -width 40 -anchor w ] \
			     -sticky news -pady 5
		}

		# bias the lengths of the labels to a slightly larger size than the average
		ttk::style configure Wrapping.TLabel -wraplength [ + 40 [ wrap-measure ] ]

		set bf  [ ttk::frame $top.bf  ]	; # button frame
		set frt [ ttk::frame $bf.top ]	; # frame right - top

		ttk::button $frt.ok -width 16 -text [ mc "OK" ] -command [ list namespace inscope $pvns Ok ]
		ttk::button $frt.c -width 16 -text [ mc "Cancel" ] -command [ namespace code [ list DestroyLoginDialog $top ] ]

		pack $frt.ok $frt.c -side top -padx 10 -pady 5
		pack $frt -side top -pady 20

		set frb [ ttk::frame $bf.pws ] ; # frame right - bottom
		set widget(showhide) [ ttk::button $frb.show -width 16 -text [ mc "Show Password" ] -command [ list namespace inscope $pvns ShowPassword ] ]

		ttk::button $frb.gen -width 16 -text [ mc "Generate Password" ] -command [ list namespace inscope $pvns MakeNewPassword ]
		ttk::checkbutton $frb.override -text [ mc "Override Password Policy" ] -variable ${pvns}::overridePasswordPolicy 
			# -justify left

		set ${pvns}::overridePasswordPolicy 0

		pack $frb.show $frb.gen $frb.override -side top -padx 10 -pady 5

		pack $frb -side top -pady 20

		grid $bf -row 0 -column 2 -rowspan 8 -sticky news

		# this adds a feedback line along the bottom edge of the window
		grid [ set widget(feedback) [ ttk::label $top.feedback -borderwidth 3 ] ] -columnspan 3 -sticky news

		set ${pvns}::feedbacktimer -1	; # to keep track of "after" id value
		

		# create, but do not make visible yet, a pane for overriding password
		# policy settings

		set ppf [ set widget(ppf) [ ttk::frame $top.ppf -borderwidth 2 -relief solid ] ] ; # ppf -> Pass Policy Frame
		
		set plf [ ttk::frame $ppf.plen -padding [ list 0 10 0 0 ] ] ; # ppf -> Pass Length Frame
		ttk::label $plf.l -text [ mc "Password Length" ]
		spinbox $plf.s -from 1 -to 999 -increment 1 \
			-width 4 -justify right \
			-textvariable ${pvns}::PassPolicy(length)
		pack $plf.l -side left
		pack $plf.s -side left -padx 10

		pack $plf -side top -anchor w -padx 10 -pady 3

		foreach {item label} [ list                                            \
			uselowercase {Use lowercase letters}                                 \
			useuppercase {Use UPPERCASE letters}                                 \
			usedigits    {Use digits}                                            \
			usehexdigits {Use hexadecimal digits}                                \
			usesymbols   {Use symbols (%, $, @, #, etc.)}                        \
			easytoread   {Use easy to read characters only (e.g. no "0" or "O")} ] {

			ttk::checkbutton $ppf.$item -text [ wrap-measure [ mc $label ] ] \
			        -variable ${pvns}::PassPolicy($item) \
				-style Wrapping.TCheckbutton

			pack $ppf.$item -anchor w -side top -padx 10 -pady 3

		} ; # end foreach item,label 

		ttk::style configure Wrapping.TCheckbutton -wraplength [ wrap-measure ]


		# force geometry calculations to happen - the ppf frame map/unmap code
		# depends on this having been run now

		update idletasks
		
		# do not allow resize smaller than the native requested size of the
		# internal widgets

		wm minsize $top [ winfo reqwidth $top ] [ winfo reqheight $top ]

		# Now build the callback procs that will handle this window's gui
		# interactions with the user

		build-gui-callbacks $pvns [ array get widget ]

	} ; # end proc buildLoginDialog
	
# -----------------------------------------------------------------------------

	# a proc to make computing the average pixel width of a set of lines of
	# text easier
	# if called with a parameter, adds the length of that parameter to an internal list
	# if called without a parameter, returns the average accumulated length and resets itself to empty

	proc wrap-measure { {text ""} } {
		variable ___accumulated_lengths___
		if { ( $text eq "" ) && ( [ llength $___accumulated_lengths___ ] > 0 ) } {
			return [ K [ calculateWraplength $___accumulated_lengths___ ] [ set ___accumulated_lengths___ [ list ] ] ]
		} else {
			lappend ___accumulated_lengths___ [ font measure [ ttk::style configure . -font ] $text ]
			return $text
		}
	} ; # end proc wraplength

# -----------------------------------------------------------------------------

	# calculates a "wraplength" value from the list of integer lengths passed
	# to the proc.  The resulting length will be an integer representing the
	# mean of the passed in list, rounded up to the next even unit of 10.
  
	proc calculateWraplength { lengths } {
		return [ * [ / [ + [ / [ + {*}$lengths ] [ llength $lengths ] ] 9 ] 10 ] 10 ]
	} ; # end proc computeWraplength 

# -----------------------------------------------------------------------------

	# smacro -> simple macro processor.  The idea is inspired by Lisp macros,
	# but this simple implimentation has more in common with cpp style macros,
	# in that it is a simple string substiution.

	proc smacro { map body } {
		return [ string map [ convert_map $map ] $body ]
	} ; # end proc smacro

# -----------------------------------------------------------------------------

	# preprocess the macro substitution map.  Each key in the map is prefixed
	# by m: and then the result is surrounded by hyphens, i.e. "-m:key-". 
	# This format was chosen because this is highly unlikely to be utilized as
	# valid Tcl code otherwise.

	proc convert_map { map } {

		foreach {key value} $map {
			lappend result "-m:$key-" $value
		} ; # end foreach key,value in map

		return $result

	} ; # end proc smacro_map

# -----------------------------------------------------------------------------

	proc build-gui-callbacks { pvns widgets } {

		# This builds the callback procs that will handle this dialogs
		# interaction with the user - generation of these procs borrows a bit of
		# ideas from Lisp macros to avoid having to pass a bunch of constants
		# around in proc parameters (i.e., the pvns name or the widget path/proc
		# names) or having the procs reference a bunch of quasi-global variables
		#
		# pvns - the name of the private variable namespace for the dialog.  The
		#  GUI interaction procs will be built within this namespace.
		#
		# widgets - A key/value list (i.e. a dict or a list from array get) of
		#  descriptive widget names and the actual widget window pathname to
		#  apply as the "macro" transformations for each proc built.  Each key
		#  will be substituted for the value of that key in the body of each
		#  proc, with the result being that the resulting procs are "customized"
		#  at build time to know which GUI widgets to access for performing
		#  their relevant functions.

		namespace eval $pvns [ smacro $widgets {
		
		  namespace import ::tcl::mathop::+ ::tcl::mathop::-
		
			namespace path ::gorilla

			# since TogglePassPolicyFrame is a trace callback, it will need "args"
			# to accept the extra args that trace adds - the args are ignored

			proc TogglePassPolicyFrame { args } {

				variable overridePasswordPolicy

				# The resize code below increases (or decreases) the width and
				# minwidth of the toplevel window by the width of the ppf pane.
				
				# This resizing code turned out to be necessary because when gorilla
				# withdrew and then deiconified edit windows upon a lock/unlock
				# event, it also set an explicit geometry.  By setting a geometry
				# the window would no longer auto-resize when the ppf pane was
				# mapped/unmapped.
				
				# The extra 10 in the increment/decrement calculations is because of
				# the -padx 5 given to grid.  Five pixels per side of padding is 10
				# extra pixels above the width of the ppf frame itself.

				# Note - this code also depends upon the BuildDialog proc having run
				# "update idletasks" to assure that the initial window geometry
				# calculations have all occurred.

				# 2011-03-18 - Finally deduced how to expand/shrink the width of the
				# parent window while otherwise maintaining its exact position on
				# screen.  The winfo rootx|rooty command is the magic.
				
				if { $overridePasswordPolicy } {
					# true - map the ppf frame
				  
					if { ! [ winfo ismapped -m:ppf- ] } {
						# only expand window size if the ppf is not currently mapped

						set parent [ winfo parent -m:ppf- ]
						set inc [ + 10 [ winfo reqwidth -m:ppf- ] ]

						wm geometry $parent "=[ + $inc [ winfo width $parent ] ]x[ winfo height $parent ]+[ winfo rootx $parent ]+[ winfo rooty $parent ]"

						lassign [ wm minsize $parent ] minw minh
						wm minsize $parent [ + $inc $minw ] $minh
					}

					grid -m:ppf- -row 0 -column 3 -sticky news -rowspan 9 -padx 5 -pady 5

				} else {

					if { [ winfo ismapped -m:ppf- ] } {
						# only shrink window size if the ppf was mapped to start with

						set parent [ winfo parent -m:ppf- ]
						set dec [ + 10 [ winfo reqwidth -m:ppf- ] ]

						wm geometry $parent "=[ - [ winfo width $parent ] $dec ]x[ winfo height $parent ]+[ winfo rootx $parent ]+[ winfo rooty $parent ]"

						lassign [ wm minsize $parent ] minw minh
						wm minsize $parent [ - $minw $dec ] $minh 
					}

					grid forget -m:ppf- 

				} ; # end if overridePasswordPolicy

			} ; # end proc TogglePassPolicyFrame

			# install a variable trace on the password policy checkbutton variable
			# to trigger opening/closing of the adjust pass policy pane.

			trace add variable overridePasswordPolicy write [ namespace code TogglePassPolicyFrame ]

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc ShowPassword { } {
				-m:password- configure -show {}
				-m:showhide- configure -command [ namespace code HidePassword ] -text [ mc "Hide Password" ]
			} ; # end proc ShowPassword

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -
		
			proc HidePassword { } {
				-m:password- configure -show "*"
				-m:showhide- configure -command [ namespace code ShowPassword ] -text [ mc "Show Password" ]
			} ; # end proc HidePassword

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc MakeNewPassword { } {

				variable overridePasswordPolicy
				variable PassPolicy
				variable password
				
				if { $overridePasswordPolicy } {
					set policy [ array get PassPolicy ] 
				} else {
					set policy [ GetDefaultPasswordPolicy ] 
				} ; # end if override

				if { [ catch { set newPassword [ GeneratePassword $policy ] } oops ] } {
					feedback [ mc "Password policy settings invalid." ]
				} else {
					set password $newPassword
					::pwsafe::int::randomizeVar newPassword
				} ; # end if catch

			} ; # end proc MakeNewPassword

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc feedback { text } {
				-m:feedback- configure -relief sunken -text $text -background yellow
				set-feedback-timer 300 clearHighlight
			} ; # end proc feedback

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc clearHighlight { } {
				-m:feedback- configure -background {}
				set-feedback-timer 9700 clearFeedback
			} ; # end proc clearHighlight

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc clearFeedback { } {
				variable feedbacktimer
				-m:feedback- configure -relief flat -text "" -background {}
				set feedbacktimer -1
			} ; # end proc clearFeedback

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc set-feedback-timer { length next } {
				variable feedbacktimer
				if { $feedbacktimer != -1 } {
					after cancel $feedbacktimer
				}
				set feedbacktimer [ after $length [ namespace code $next ] ]
			} ; # end proc set-feedback-timer

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			# extracts fields from the gorilla db record and inserts them into the
			# proper linked variables or widgets in the dialog

			proc PopulateLoginDialog { in_rn in_group } {

				variable rn
				variable overridePasswordPolicy 0
				variable PassPolicy 
				array set PassPolicy [ GetDefaultPasswordPolicy ]

				foreach item { group title url user password } {
					variable $item
					set $item [ dbget $item $in_rn ]
				}

				if { $in_group ne "" } {
					set group $in_group
				}

				-m:notes- delete 0.0 end
				-m:notes- insert end [ dbget notes $in_rn ]
				
				foreach item { last-pass-change last-modified } {
					variable $item
					set $item [ dbget $item $in_rn [ mc "<unknown>" ] ]
				}

				clearFeedback

				set rn $in_rn
				
				HidePassword

			} ; # end proc PopulateLoginDialog

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc PopulateRecord { rn } {
			
				# Insert the state data from the linked
				# login window into a db record
				#
				# rn - the db record number into which to
				#      insert the state data

				set varlist { group title user password url }
				
				foreach var $varlist {
					variable $var
				}

				set modified 0
				set now [clock seconds]

				if { [ dbget uuid $rn ] eq "" } {
					if { ! [ catch { package present uuid } ] } {
						dbset uuid $rn [uuid::uuid generate]
					}                              
				}

				foreach element [ list {*}$varlist notes ] {

					if { $element ne "notes" } {
						set new_value [ set $element ]
					} else {
						set new_value [ string trimright [ -m:notes- get 0.0 end ] ]
					}

					set old_value [ dbget $element $rn ]
					
					if { $new_value ne $old_value } {
						set modified 1
						if { $new_value eq "" } {
							dbunset $element $rn
						} else {

							dbset $element $rn $new_value

							if { $element eq "password" } {
								dbset last-pass-change $rn $now
							} ; # end if element eq password

						} ; # end if new_value eq ""

					} ; # end if new_value ne old_value

					# note - "$element" is correct below.  For all but "notes", the
					# element variable contains a variable name, it is that inner
					# variable name that should be cleansed
					if { $element ne "notes" } {
						::pwsafe::int::randomizeVar $element new_value old_value
					}

				} ; # end foreach element
				
				if { $modified } {
					dbset last-modified $rn $now
				}

				return $modified

			} ; # end proc PopulateRecord

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc Ok { } {

				variable title
				variable group
				variable rn
				variable treenode
				variable url
				variable user
        
				if { 0 == [ string length [ string trim $title ] ] } {
					# use url, if none use username
					if { 0 < [ string length [ string trim $url ] ] } {
						set title $url
					} else {
						if { 0 == [ string length [ string trim $user ] ] } {
							feedback [ mc "This login must have a title, url or username." ]
							return
						} else {
							set title $user
						}
					}
				}

				if { [ catch { ::pwsafe::db::splitGroup $group } ] } {
					feedback [ mc "This login's group name is not valid." ] $pvns
					return
				}

				if { $rn == -999 } {
					set modified [ PopulateRecord [ set newrn [ $::gorilla::db createRecord ] ] ]
				} else {
					set modified [ PopulateRecord $rn ]
				}

				# Once the database has been updated, the
				# dialog window is no longer necessary. 
				# Withdrawing it now prevents a flash of
				# random data in the entries if a user has
				# "auto-save-on-change" turned on.
				
				[ namespace parent ]::DestroyLoginDialog -m:top-

				if { $modified } {

					if { $rn == -999 } {
						set ::gorilla::status [ mc "New login added." ]
						AddRecordToTree $newrn
					} else {
						# this takes a shortcut, for an existing record, simply delete from
						# tree then reinsert into tree
						$::gorilla::widgets(tree) delete $treenode
						AddRecordToTree $rn                   
						set ::gorilla::status [ mc "Login modified." ]
					}

					MarkDatabaseAsDirty

				} ; # end if modified

			} ; # end proc Ok
			
		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

		} ] ; # end smacro namespace eval

	} ; # end proc build-gui-callbacks

# -----------------------------------------------------------------------------

	proc EditLogin {} {
		ArrangeIdleTimeout

		lassign [ ::gorilla::get-selected-tree-data "Please select a login entry first." ] node type rn 

		if {$type == "Group" || $type == "Root"} {
			set ::gorilla::status [ mc "Group entries may be renamed, not edited." ]
			return
		}

		LoginDialog -rn $rn -treenode $node

	} ; # end proc EditLogin

# -----------------------------------------------------------------------------

	proc AddLogin {} {

		set tree $::gorilla::widgets(tree)

		set node [ lindex [ $tree selection ] 0 ]

		lassign [ ::gorilla::LookupNodeData $node ] data type
		
		# if "type" is Login, repeat the data lookup, but for the parent of the
		# node, to result in an "add to group" action occurring instead.

		if { $type eq "Login" } {
			lassign [ gorilla::LookupNodeData [ $tree parent $node ] ] data type
		}

		# if no entry in tree is selected, then "type" will be {},
		# so in that case perform the same action as an add to root
		
		switch -exact -- $type {
			Group	{ LoginDialog -group [ lindex $data 1 ] }
			Root	{ LoginDialog -group "" }
			Login	{ LoginDialog -group [ lindex [ $tree item [ $tree parent $node ] -values ] 1 ] }
			{}	{ LoginDialog -group "" }
		} 

	} ; # end proc AddLogin

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------

#	#
#	# Set up bindings
#	#
#
#	bind $top.l.group2 <Shift-Tab> "after 0 \"focus $top.r.top.ok\""
#	bind $top.l.title2 <Shift-Tab> "after 0 \"focus $top.l.group2\""
#	bind $top.l.user2 <Shift-Tab> "after 0 \"focus $top.l.title2\""
#	bind $top.l.pass2 <Shift-Tab> "after 0 \"focus $top.l.user2\""
#	bind $top.l.notes <Tab> "after 0 \"focus $top.r.top.ok\""
#	bind $top.l.notes <Shift-Tab> "after 0 \"focus $top.l.pass2\""
#
#	bind $top.l.group2 <Return> "set ::gorilla::guimutex 1"
#	bind $top.l.title2 <Return> "set ::gorilla::guimutex 1"
#	bind $top.l.user2 <Return> "set ::gorilla::guimutex 1"
#	bind $top.l.pass2 <Return> "set ::gorilla::guimutex 1"
#	bind $top.r.top.ok <Return> "set ::gorilla::guimutex 1"
#	bind $top.r.top.c <Return> "set ::gorilla::guimutex 2"
#

} ; # end namespace eval ::gorilla::LoginDialog


# ----------------------------------------------------------------------
# Add a Login
# ----------------------------------------------------------------------

proc gorilla::AddLogin {} {
	# since version 1.5.3.4 only the non-modal version is used
	::gorilla::LoginDialog::AddLogin
}

# ----------------------------------------------------------------------
# Edit a Login
# ----------------------------------------------------------------------

proc gorilla::EditLogin {} {
	# modal version is deprecated, renamed to gorilla::EditLoginModal
	# since version 1.5.3.4 only the non-modal version is used
	
	::gorilla::LoginDialog::EditLogin
}

# ----------------------------------------------------------------------
# Move a Login
# ----------------------------------------------------------------------
#

proc gorilla::MoveLogin {} {
	gorilla::MoveDialog [mc Login]
}

proc gorilla::MoveGroup {} {
	gorilla::MoveDialog [mc Group]
}

proc gorilla::MoveDialog {type} {
	ArrangeIdleTimeout

	lassign [ ::gorilla::get-selected-tree-data "Please select an entry in the tree to move." ] node nodetype rn
	
	set top .moveDialog
	
	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top -class "Gorilla"
		TryResizeFromPreference $top
		wm title $top [mc "Move %s" "$type"]

		ttk::labelframe $top.source -text $type -padding [list 10 10]
		ttk::entry $top.source.e -width 40 -textvariable ::gorilla::MoveDialogSource
		ttk::labelframe $top.dest \
		-text [mc "Destination Group with format <Group.Subgroup> :"] \
		-padding [list 10 10]
		ttk::combobox $top.dest.e -width 40 -textvariable ::gorilla::MoveDialogDest \
		              -postcommand [ list ::gorilla::fill-combobox-with-grouplist $top.dest.e ] 

		# Format: group.subgroup
		pack $top.source.e -side left -expand yes -fill x
		pack $top.source -side top -expand yes -fill x -pady 10 -padx 10
		pack $top.dest.e -side left -expand yes -fill x
		pack $top.dest -side top -expand yes -fill x -fill y -pady 10 -padx 10

		ttk::frame $top.buts
		set but1 [ttk::button $top.buts.b1 -width 10 -text "OK" \
			-command "set ::gorilla::guimutex 1"]
		set but2 [ttk::button $top.buts.b2 -width 10 -text [mc "Cancel"] \
			-command "set ::gorilla::guimutex 2"]
		pack $but1 $but2 -side left -pady 10 -padx 20
		pack $top.buts -side bottom -pady 10 -fill y -expand yes
	
		bind $top.source.e <Shift-Tab> "after 0 \"focus $top.buts.b1\""
		bind $top.dest.e <Shift-Tab> "after 0 \"focus $top.source.e\""
		
		bind $top.source.e <Return> "set ::gorilla::guimutex 1"
		bind $top.dest.e <Return> "set ::gorilla::guimutex 1"
		bind $top.buts.b1 <Return> "set ::gorilla::guimutex 1"
		bind $top.buts.b2 <Return> "set ::gorilla::guimutex 2"

		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW gorilla::DestroyAddSubgroupDialog
	} else {
		wm deiconify $top
	}
	
	# Configure Dialog

	if {$nodetype == "Group"} {
		# for group entries the "rn" field contains the group name
		set ::gorilla::MoveDialogSource $rn 
	} elseif {$nodetype == "Login"} {
		if {[$::gorilla::db existsField $rn 3]} {
			set ::gorilla::MoveDialogSource [ ::gorilla::dbget title $rn ]
		}
	} else {
		return
	}
	set ::gorilla::MoveDialogDest ""

	# Run Dialog

	set oldGrab [grab current .]

	update idletasks
	raise $top
	focus $top.dest.e
	catch {grab $top}
	
	while {42} {
		ArrangeIdleTimeout
		set ::gorilla::guimutex 0
		vwait ::gorilla::guimutex

		set sourceNode [$top.source.e get]
		set destGroup [$top.dest.e get]

		if {$::gorilla::guimutex != 1} {
			break
		}
		#
		# The group name must not be empty
		# 
		
		if {$destGroup == ""} {
			tk_messageBox -parent $top \
				-type ok -icon error -default ok \
				-title [ mc "Invalid Group Name" ] \
				-message [ mc "The group name can not be empty." ]
			continue
		}

		#
		# See if the destination's group name can be parsed
		#

		if {[catch {
			set destNode $::gorilla::groupNodes($destGroup)
		}]} {
			tk_messageBox -parent $top \
				-type ok -icon error -default ok \
				-title [ mc "Invalid Group Name" ] \
				-message [ mc "The name of the parent group is invalid." ]
			continue
		}
		# all seems well
		break
	}

	if {$oldGrab != ""} {
		catch {grab $oldGrab}
	} else {
		catch {grab release $top}
	}

	wm withdraw $top

	if {$::gorilla::guimutex != 1} {
		set ::gorilla::status [mc "Moving of %s canceled." $type]
		return
	}

	gorilla::MoveTreeNode $node $destNode
	
	$::gorilla::widgets(tree) item $destNode -open 1
	$::gorilla::widgets(tree) item "RootNode" -open 1
	set ::gorilla::status [mc "%s moved." $type]
	MarkDatabaseAsDirty
}


# ----------------------------------------------------------------------
# Delete a Login
# ----------------------------------------------------------------------
#

proc gorilla::DeleteLogin {} {
	ArrangeIdleTimeout

	lassign [ ::gorilla::get-selected-tree-data RETURN ] node type rn 

	if {$type != "Login"} {
		error "oops"
	}
	
	# It is good if there is necessarily a question, no if-question necessary
	if {0} {
		set answer [tk_messageBox -parent . \
			-type yesno -icon question -default no \
			-title [mc "Delete Login"] \
			-message [mc "Are you sure that you want to delete this login?"]]

		if {$answer != "yes"} {
			return
		}
	}

	$::gorilla::db deleteRecord $rn
	$::gorilla::widgets(tree) delete $node
	set ::gorilla::status [mc "Login deleted."]
	MarkDatabaseAsDirty
}

# ----------------------------------------------------------------------
# Add a new group
# ----------------------------------------------------------------------
#

proc gorilla::AddGroup {} {
	gorilla::AddSubgroup
	# gorilla::AddSubgroupToGroup ""
}

#
# ----------------------------------------------------------------------
# Add a new subgroup (to the selected group)
# ----------------------------------------------------------------------
#

proc gorilla::AddSubgroup {} {

	lassign [ ::gorilla::get-selected-tree-data ] node type rn

	if { ( $node eq "" ) && ( $type eq "" ) } {
		
		# No selection. Add to toplevel
		#
		gorilla::AddSubgroupToGroup ""
		
	} else {

		if {$type == "Group"} {
			# for group entries, rn field contains group name
			gorilla::AddSubgroupToGroup $rn 
		} elseif {$type == "Root"} {
			gorilla::AddSubgroupToGroup ""
		} else {
			
			# A login is selected. Add to its parent group.
			#
			set parent [$::gorilla::widgets(tree) parent $node]
			if {[string equal $parent "RootNode"]} {
				gorilla::AddSubgroupToGroup ""
			} else {
				set pdata [ $::gorilla::widgets(tree) item $parent -values ]
				gorilla::AddSubgroupToGroup [lindex $pdata 1]
			}
		}
	}
} ; # end proc gorilla::AddSubgroup

#
# ----------------------------------------------------------------------
# Add a new subgroup
# ----------------------------------------------------------------------
#

proc gorilla::DestroyAddSubgroupDialog {} {
	set ::gorilla::guimutex 2
}

proc gorilla::AddSubgroupToGroup {parentName} {
	ArrangeIdleTimeout

	if {![info exists ::gorilla::db]} {
		tk_messageBox -parent . \
			-type ok -icon error -default ok \
			-title [mc "No Database"] \
			-message [mc "Please create a new database, or open an existing\
			database first."]
		return
	}

	set top .subgroupDialog

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top -class "Gorilla"
		TryResizeFromPreference $top
		wm title $top [mc "Add a new Group"]

		ttk::labelframe $top.parent -text [mc "Parent:"] \
		 -padding [list 10 10]
		ttk::entry $top.parent.e -width 40 -textvariable ::gorilla::subgroup.parent
		pack $top.parent.e -side left -expand yes -fill x
		pack $top.parent -side top -expand yes -fill x -pady 10 -padx 10

		ttk::labelframe $top.group -text [mc "New Group Name:"] -padding [list 10 10]
		ttk::entry $top.group.e -width 40 -textvariable ::gorilla::subgroup.group
		
		pack $top.group.e -side left -expand yes -fill x
		pack $top.group -side top -expand yes -fill x -pady 10 -padx 10

		ttk::frame $top.buts
		set but1 [ttk::button $top.buts.b1 -width 10 -text [ mc "OK" ] \
			-command "set ::gorilla::guimutex 1"]
		set but2 [ttk::button $top.buts.b2 -width 10 -text [mc "Cancel"] \
			-command "set ::gorilla::guimutex 2"]
		pack $but1 $but2 -side left -pady 10 -padx 20
		pack $top.buts -side bottom -pady 10
	
		bind $top.parent.e <Shift-Tab> "after 0 \"focus $top.buts.b1\""
		bind $top.group.e <Shift-Tab> "after 0 \"focus $top.parent.e\""
		
		bind $top.parent.e <Return> "set ::gorilla::guimutex 1"
		bind $top.group.e <Return> "set ::gorilla::guimutex 1"
		bind $top.buts.b1 <Return> "set ::gorilla::guimutex 1"
		bind $top.buts.b2 <Return> "set ::gorilla::guimutex 2"

		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW gorilla::DestroyAddSubgroupDialog
	} else {
		wm deiconify $top
	}

	# $top.parent configure -text $parentName
	# $top.group configure -text ""
	set ::gorilla::subgroup.parent $parentName
	set ::gorilla::subgroup.group ""

	set oldGrab [grab current .]

	update idletasks
	raise $top
	focus $top.group.e
	catch {grab $top}

	while {42} {
		ArrangeIdleTimeout
		set ::gorilla::guimutex 0
		vwait ::gorilla::guimutex

		set parent [$top.parent.e get]
		set group [$top.group.e get]

		if {$::gorilla::guimutex != 1} {
			break
		}
		#
		# The group name must not be empty
		#

		if {$group == ""} {
			tk_messageBox -parent $top \
				-type ok -icon error -default ok \
				-title [mc "Invalid Group Name"] \
				-message [mc "The group name can not be empty."]
			continue
		}

		#
		# See if the parent's group name can be parsed
		#

		if {[catch {
			set parents [pwsafe::db::splitGroup $parent]
		}]} {
			tk_messageBox -parent $top \
				-type ok -icon error -default ok \
				-title [mc "Invalid Group Name"] \
				-message ["The name of the parent group is invalid."]
			continue
		}

		break
	}

	if {$oldGrab != ""} {
		catch { grab $oldGrab }
	} else {
		catch { grab release $top }
	}

	wm withdraw $top

	if {$::gorilla::guimutex != 1} {
		set ::gorilla::status [mc "Addition of group canceled."]
		return
	}

	lappend parents $group
	set fullGroupName [pwsafe::db::concatGroups $parents]
	AddGroupToTree $fullGroupName

	set piter [list]
	foreach parent $parents {
		lappend piter $parent
		set fullParentName [pwsafe::db::concatGroups $piter]
		set node $::gorilla::groupNodes($fullParentName)
		$::gorilla::widgets(tree) item $node -open 1
	}

	$::gorilla::widgets(tree) item "RootNode" -open 1
	set ::gorilla::status [mc "New group added."]
	# MarkDatabaseAsDirty

}

# ----------------------------------------------------------------------
# Move Node to a new Group
# ----------------------------------------------------------------------
#

proc gorilla::MoveTreeNode {node dest} {
	set nodedata [$::gorilla::widgets(tree) item $node -values]
	set destdata [$::gorilla::widgets(tree) item $dest -values]
	set nodetype [lindex $nodedata 0]
	set desttype [lindex $destdata 0]

	# node6 to node3
	#node7 node1
	# menü move login erscheint nur, wenn ein Login angeklickt ist
	# entsprechend MOVE GROUP nur, wenn tag group aktiviert ist

	if {$nodetype == "Root"} {
		tk_messageBox -parent . \
			-type ok -icon error -default ok \
			-title [ mc "Root Node Can Not Be Moved" ] \
			-message [ mc "The root node can not be moved." ]
		return
	}

	if {$desttype == "RootNode"} {
		set destgroup ""
	} elseif { $desttype == "Login" } {
		# if moving to a "Login", actually move to the parent of the
		# login (which will be a group)
		set dest [ $::gorilla::widgets(tree) parent $dest ]
		set destdata [ $::gorilla::widgets(tree) item $dest -values ]
		lassign $destdata desttype destgroup
	} else {
		set destgroup [lindex $destdata 1]
	}

	#
	# Move a Login
	#

	if {$nodetype == "Login"} {
		set rn [lindex $nodedata 1]
		$::gorilla::db setFieldValue $rn 2 $destgroup
		$::gorilla::widgets(tree) delete $node
		AddRecordToTree $rn
		MarkDatabaseAsDirty
		return
	}
	# bis hier
	#
	# Moving a group to its immediate parent does not have any effect
	#

	if {$dest == [$::gorilla::widgets(tree) parent $node]} {
		return
	}
	
	#
	# When we are moving a group, make sure that destination is not a
	# child of this group
	#

	set destiter $dest
	while {$destiter != "RootNode"} {
		if {$destiter == $node} {
			break
		}
		set destiter [$::gorilla::widgets(tree) parent $destiter]
	}

	if {$destiter != "RootNode" || $node == "RootNode"} {
		tk_messageBox -parent . \
			-type ok -icon error -default ok \
			-title [ mc "Can Not Move Node" ] \
			-message [ mc "Can not move a group to a subgroup of itself." ]
		return
	}

	#
	# Move recursively
	#

	MoveTreeNodeRek $node [pwsafe::db::splitGroup $destgroup]
	MarkDatabaseAsDirty
}

#
# Moves the children of tree node to the newParents group
#

proc gorilla::MoveTreeNodeRek {node newParents} {
	set nodedata [$::gorilla::widgets(tree) item $node -values]
	set nodename [$::gorilla::widgets(tree) item $node -text]

	lappend newParents $nodename
	set newParentName [pwsafe::db::concatGroups $newParents]
	set newParentNode [AddGroupToTree $newParentName]

	foreach child [$::gorilla::widgets(tree) children $node] {
		set childdata [$::gorilla::widgets(tree) item $child -values]
		set childtype [lindex $childdata 0]

		if {$childtype == "Login"} {
			set rn [lindex $childdata 1]
			$::gorilla::db setFieldValue $rn 2 $newParentName
			$::gorilla::widgets(tree) delete $child
			AddRecordToTree $rn
		} else {
			MoveTreeNodeRek $child $newParents
		}
	}

	set oldGroupName [lindex $nodedata 1]
	unset ::gorilla::groupNodes($oldGroupName)
	$::gorilla::widgets(tree) item $newParentNode \
		-open [$::gorilla::widgets(tree) item $node -open]
	$::gorilla::widgets(tree) delete $node
}


#
# ----------------------------------------------------------------------
# Delete Group
# ----------------------------------------------------------------------
#

proc gorilla::DeleteGroup {} {
	ArrangeIdleTimeout

	lassign [ ::gorilla::get-selected-tree-data RETURN ] node type rn
	
	if {$type == "Root"} {
		tk_messageBox -parent . \
			-type ok -icon error -default ok \
			-title [mc "Can Not Delete Root"] \
			-message [mc "The root node can not be deleted."]
		return
	}

	if {$type != "Group"} {
		error "oops"
	}

	if {[llength [$::gorilla::widgets(tree) children $node]] > 0} {
		set answer [tk_messageBox -parent . \
			-type yesno -icon question -default no \
			-title [mc "Delete Group"] \
			-message [mc "Are you sure that you want to delete group and all its contents?"]]

		if {$answer != "yes"} {
			return
		}
		set hadchildren 1
	} else {
		set hadchildren 0
	}

	set ::gorilla::status [mc "Group deleted."]
	gorilla::DeleteGroupRek $node

	if {$hadchildren} {
		MarkDatabaseAsDirty
	}
}

proc gorilla::DeleteGroupRek {node} {
	set children [$::gorilla::widgets(tree) children $node]

	foreach child $children {
		set data [$::gorilla::widgets(tree) item $child -values]
		set type [lindex $data 0]

		if {$type == "Login"} {
			$::gorilla::db deleteRecord [lindex $data 1]
			$::gorilla::widgets(tree) delete $child
		} else {
			DeleteGroupRek $child
		}
	}

	set groupName [lindex [$::gorilla::widgets(tree) item $node -values] 1]
	unset ::gorilla::groupNodes($groupName)
	$::gorilla::widgets(tree) delete $node
}

#
# ----------------------------------------------------------------------
# Rename Group
# ----------------------------------------------------------------------
#

proc gorilla::DestroyRenameGroupDialog {} {
	set ::gorilla::guimutex 2
}

proc gorilla::RenameGroup {} {
	ArrangeIdleTimeout

	lassign [ ::gorilla::get-selected-tree-data RETURN ] node type fullGroupName
	
	if {$type == "Root"} {
		tk_messageBox -parent . \
			-type ok -icon error -default ok \
			-title [mc "Can Not Rename Root"] \
			-message [mc "The root node can not be renamed."]
		return
	}

	if {$type != "Group"} {
		error "oops"
	}

	set groupName [$::gorilla::widgets(tree) item $node -text]
	set parentNode [$::gorilla::widgets(tree) parent $node]
	set parentData [$::gorilla::widgets(tree) item $parentNode -values]
	set parentType [lindex $parentData 0]

	if {$parentType == "Group"} {
		set parentName [lindex $parentData 1]
	} else {
		set parentName ""
	}

	set top .renameGroup

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top -class "Gorilla"
		TryResizeFromPreference $top
		wm title $top [mc "Rename Group"]

		# set title [label $top.title -anchor center -text [mc "Rename Group"]]
		# pack $title -side top -fill x -pady 10

		# set sep1 [ttk::separator $top.sep1 -orient horizontal]
		# pack $sep1 -side top -fill x -pady 10

		ttk::labelframe $top.parent -text [mc "Parent:"] 
		ttk::entry $top.parent.e -width 40 -textvariable ::gorilla::renameGroupParent
		pack $top.parent.e -side left -expand yes -fill x -pady 5 -padx 10
		pack $top.parent -side top -expand yes -fill x -pady 5 -padx 10

		ttk::labelframe $top.group -text [ mc Name ]
		ttk::entry $top.group.e -width 40 -textvariable ::gorilla::renameGroupName
		pack $top.group.e -side top -expand yes -fill x -pady 5 -padx 10
		pack $top.group -side top -expand yes -fill x -pady 5 -padx 10
		bind $top.group.e <Shift-Tab> "after 0 \"focus $top.parent.e\""

		set sep2 [ttk::separator $top.sep2 -orient horizontal]
		pack $sep2 -side top -fill x -pady 10

		ttk::frame $top.buts
		set but1 [ttk::button $top.buts.b1 -width 15 -text [ mc "OK" ] \
			-command "set ::gorilla::guimutex 1"]
		set but2 [ttk::button $top.buts.b2 -width 15 -text [mc "Cancel"] \
			-command "set ::gorilla::guimutex 2"]
		pack $but1 $but2 -side left -pady 10 -padx 20
		pack $top.buts

		bind $top.parent.e <Return> "set ::gorilla::guimutex 1"
		bind $top.group.e <Return> "set ::gorilla::guimutex 1"
		bind $top.buts.b1 <Return> "set ::gorilla::guimutex 1"
		bind $top.buts.b2 <Return> "set ::gorilla::guimutex 2"

		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW gorilla::DestroyRenameGroupDialog
	} else {
		wm deiconify $top
	}

	set ::gorilla::renameGroupParent $parentName
	set ::gorilla::renameGroupName $groupName

	set oldGrab [grab current .]

	update idletasks
	raise $top
	focus $top.group.e
	catch {grab $top}

	while {42} {
		ArrangeIdleTimeout
		set ::gorilla::guimutex 0
		vwait ::gorilla::guimutex

		if {$::gorilla::guimutex != 1} {
			break
		}

		set newParent [$top.parent.e get]
		set newGroup [$top.group.e get]

		#
		# Validate that both group names are valid
		#

		if {$newGroup == ""} {
			tk_messageBox -parent $top \
				-type ok -icon error -default ok \
				-title [mc "Invalid Group Name"] \
				-message [mc "The group name can not be empty."]
			continue
		}

		if {[catch {
			set newParents [pwsafe::db::splitGroup $newParent]
		}]} {
			tk_messageBox -parent $top \
				-type ok -icon error -default ok \
				-title [mc "Invalid Group Name"] \
				-message [mc "The name of the group's parent node\
				is invalid."]
			continue
		}

		#
		# if we got this far, all is well
		#

		break
	}

	if {$oldGrab != ""} {
		catch {grab $oldGrab}
	} else {
		catch {grab release $top}
	}

	wm withdraw $top

	if {$::gorilla::guimutex != 1} {
		return
	}

	if {$parentName == $newParent && $groupName == $newGroup} {
		#
		# Unchanged
		#
		set ::gorilla::status [mc "Group name unchanged."]
		return
	}

	#
	# See if the parent of the new group exists, or create it
	#

	set destparentnode [AddGroupToTree $newParent]
	set destparentdata [$::gorilla::widgets(tree) item $destparentnode -values]
	set destparenttype [lindex $destparentdata 0]

	#
	# Works nearly the same as dragging and dropping
	#

	#
	# When we are moving a group, make sure that destination is not a
	# child of this group
	#

	set destiter $destparentnode
	while {$destiter != "RootNode"} {
		if {$destiter == $node} {
			break
		}
		set destiter [$::gorilla::widgets(tree) parent $destiter]
	}

	if {$destiter != "RootNode" || $node == "RootNode"} {
		tk_messageBox -parent . \
			-type ok -icon error -default ok \
			-title [mc "Can Not Move Node"] \
			-message [mc "Can not move a group to a subgroup\
			of itself."]
		return
	}

	#
	# Move recursively
	#

	if {$newGroup != ""} {
		lappend newParents $newGroup
	}

	set newParentName [pwsafe::db::concatGroups $newParents]
	set newParentNode [AddGroupToTree $newParentName]

	foreach child [$::gorilla::widgets(tree) children $node] {
		set childdata [$::gorilla::widgets(tree) item $child -values]
		set childtype [lindex $childdata 0]

		if {$childtype == "Login"} {
			set rn [lindex $childdata 1]
			$::gorilla::db setFieldValue $rn 2 $newParentName
			$::gorilla::widgets(tree) delete $child
			AddRecordToTree $rn
		} else {
			MoveTreeNodeRek $child $newParents
		}

	}

	unset ::gorilla::groupNodes($fullGroupName)
	$::gorilla::widgets(tree) item $newParentNode \
		-open [$::gorilla::widgets(tree) item $node -open]
	$::gorilla::widgets(tree) delete $node
	set ::gorilla::status [mc "Group renamed."]
	MarkDatabaseAsDirty
}


# ----------------------------------------------------------------------
# Export Database
# ----------------------------------------------------------------------
#

proc gorilla::DestroyExportDialog {} {
	set ::gorilla::guimutex 2
}

proc gorilla::Export {} {
	ArrangeIdleTimeout
	set top .export

	if {$::gorilla::preference(exportShowWarning)} {
		set answer [tk_messageBox -parent . \
				-type yesno -icon warning -default no \
				-title [mc "Export Security Warning"] \
				-message [mc "You are about to export the password\
				database to a plain-text file. The file will\
				not be encrypted or password-protected. Anybody\
				with access can read the file, and learn your\
				user names and passwords. Make sure to store the\
				file in a secure location. Do you want to\
				continue?"] ]
		if {$answer ne "yes"} {
			return
		}
	}

	setup-default-dirname

	if { $::gorilla::DEBUG(CSVEXPORT) } {
		set fileName testexport.csv
	} else {
		set types {
			{{CSV Files} {.csv}}
			{{Text Files} {.txt}}
			{{All Files} *}
		}

		set fileName [ tk_getSaveFile -parent . \
			-title [ mc "Export password database as text ..." ] \
			-defaultextension ".csv" \
			-filetypes $types \
			-initialdir $::gorilla::dirName ]

	};# end if $::gorilla::DEBUG(CSVEXPORT)
	
	if {$fileName == ""} {
		return
	}

	set nativeName [file nativename $fileName]

	set myOldCursor [. cget -cursor]
	. configure -cursor watch
	update idletasks

	if {[catch {
		set txtFile [ open $fileName {WRONLY CREAT TRUNC} ]
	} oops]} {
		. configure -cursor $myOldCursor
		error_popup [ mc "Error Exporting Database" ] \
		            "[ mc "Failed to export password database to" ] ${nativeName}: $oops"
		return
	}

	load-package csv

	::gorilla::Feedback [ mc "Exporting ..." ]

	fconfigure $txtFile -encoding utf-8	

	set separator [subst -nocommands -novariables $::gorilla::preference(exportFieldSeparator)]

	# output a csv header describing what data values are present in each
	# column of the csv file

	set csv_data [ list uuid group title url user ] 

	if { $::gorilla::preference(exportIncludePassword) } { 
		lappend csv_data password
	}

	if { $::gorilla::preference(exportIncludeNotes) } {
		lappend csv_data notes
	}

	puts $txtFile [ ::csv::join $csv_data $separator ]

	# now output the contents of the database

	foreach rn [$::gorilla::db getAllRecordNumbers] {

		set csv_data [ list [ dbget uuid  $rn ] [ dbget group $rn ] \
		                    [ dbget title $rn ] [ dbget url $rn   ] \
		                    [ dbget user  $rn ] ]

		# Password - optional export 
		if {$::gorilla::preference(exportIncludePassword)} {
			lappend csv_data [ dbget password $rn ]
		}

		# Notes - need to escape newlines and slashes.  The CSV module will
		# handle escaping commas and double quotes
		
		if {$::gorilla::preference(exportIncludeNotes)} {
			lappend csv_data [ string map {\\ \\\\ \n \\n} [ dbget notes $rn ] ]
		}

		puts $txtFile [ ::csv::join $csv_data $separator ]

	} ; # end foreach rn in gorilla db

	catch {close $txtFile}
	. configure -cursor $myOldCursor
	::gorilla::Feedback [ mc "Database exported." ]

	return GORILLA_OK
	
} ; # end proc gorilla::Export

# ----------------------------------------------------------------------
# Import data from a CSV file
# ----------------------------------------------------------------------
#

proc gorilla::Import { {input_file ""} } {

	# Import a csv file and add the entries therein to the currently open
	# database

	ArrangeIdleTimeout

	setup-default-dirname

	set types {
		{{CSV Files} {.csv}}
	}

	if { $input_file eq "" } {
		set input_file [ tk_getOpenFile -parent . \
		-title [ mc "Import CSV datafile" ] \
		-defaultextension ".csv" \
		-filetypes $types \
		-initialdir $::gorilla::dirName ]
	}
	
	if { $input_file eq "" } {
		return
	}

	if { [ catch { set infd [ open $input_file {RDONLY} ] } oops ] } {
		ErrorPopup [ mc "Error opening import CSV file" ] \
					"[ mc "Could not access file " ] ${input_file}:\n$oops"
		return GORILLA_OPENERROR
	}

	fconfigure $infd -encoding utf-8

	load-package csv
	# if { [ catch { package require csv } oops ] } {
		# ErrorPopup [ mc "Error loading CSV parsing package." ] \
		           # "[ mc "Could not access the tcllib CSV parsing package." ]\n[ mc "This should not have happened." ]\n[ mc "Unable to continue." ]"
		# return
	# }

	set myOldCursor [. cget -cursor]
	. configure -cursor watch
	update idletasks

	set possible_columns { create-time group last-access last-modified
				last-pass-change lifetime notes password title
				url user uuid }

	if { [ catch { set columns_present [ ::csv::split [ gets $infd ] ] } oops ] } {
		ErrorPopup [ mc "Error parsing CSV file" ] \
		           "[ mc "Error parsing first line of CSV file, unable to continue." ]\n$oops"
		catch { close $infd }
	  	. configure -cursor $myOldCursor
			
		return GORILLA_FIRSTLINEERROR
	}

	# puts "columns_present: $columns_present"
   
	# Must have at least one data column present
	if { [ llength $columns_present ] == 0 } {
		ErrorPopup [ mc "Error, nothing to import." ] \
		            [ mc "No valid import data was found.  Please see\nthe help for details on how to format import\nCSV data files for Password Gorilla." ]
		catch { close $infd }
	  	. configure -cursor $myOldCursor
		return GORILLA_NODATA
	}
   
	# Make sure that only the possible columns are present.  Note, this does
	# not test for duplicate columns, that is intentional.  The result of
	# duplicate columns is that the last duplicate column on a line will
	# override the value of previous occurrences of the same column on that
	# line.
	   
	foreach item $columns_present {
		if { $item ni $possible_columns } {
			lappend error_columns $item
		}
	}
   
	if { [ info exists error_columns ] } {
		ErrorPopup [ mc "Error, undefined data columns" ] \
			"[ mc "The following data items are not recognized as import data items.\nUnable to continue." ]\n[ join $error_columns " " ]" 
		catch { close $infd }
			. configure -cursor $myOldCursor
		return GORILLA_UNDEFINEDCOLUMNS
	}

	# This is utilized below to apply a "default" group to any imports
	# which do not contain a group column in the input data.  It is
	# setup before the loop so that the "group" name is identical for
	# all records in the import batch
	
	if { "group" ni $columns_present } {
		set default_group_name "Newly Imported [ clock format [ clock seconds ] ]"
		if { $::gorilla::DEBUG(CSVIMPORT) } {
			. configure -cursor $myOldCursor
			return GORILLA_ADDDEFAULTGROUP
		}
	}
	
	set new_add_counter 0

	foreach line [ split [ read $infd [ file size $input_file ] ] "\n" ] {

#		puts "line: $line"
		
		if { [ catch { set data [ ::csv::split $line ] } oops ] } {
			lappend error_lines [ list "Unable to parse as CSV" $line ]
			continue
		} ; # end if catch csv::split

		if { [ llength $data ] == 0 } { 
			continue
		}
		
		if { [ llength $data ] != [ llength $columns_present ] } {
			lappend error_lines [ list "Unequal number of columns" $line ]
			continue
		}

		set newrn [ $::gorilla::db createRecord ]
#		puts "newrn: $newrn"		

		set no_errors 1

		foreach key $columns_present value $data {

#			puts "key: $key value $value"
			switch -exact -- $key {

				group {
					if { [ catch { ::pwsafe::db::splitGroup $value } ] } {
						lappend error_lines [ list "Invalid group name" $line ]
						set no_errors 0
					}
					dbset group $newrn $value
				}

				uuid {
					# uuid is allowed to be empty, but if not empty it must be in
					# this format: f29b9ef7-9e62-41e1-7dfd-14ae13986059
					if { ( $value ne "" ) && 
					     ( ! [ regexp {^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$} $value ] ) } {
#					puts "invalid uuid $value"
						lappend error_lines [ list "Invalid UUID field" $line ]
						set no_errors 0
					}
					dbset uuid $newrn $value
				}

				create-time -
				last-access -
				last-modified -
				last-pass-change -
				lifetime {
					if { [ catch { set time [ clock scan $value -format "%Y-%m-%d %k-%M-%S %z" ] } ] } {
						lappend error_lines [ list "Invalid time: field $key" $line ]
						set no_errors 0
					} else {
						dbset $key $newrn $time
					}
				}

				notes {
					dbset notes $newrn [ subst -nocommands -novariables $value ]
				}

				default { dbset $key $newrn $value }

			} ; # end switch

		} ; # end foreach key/value
		
#		puts ""

		if { $no_errors } {
			# setup some reasonable defaults if certain items are not provided
			# in the CSV file

			if { [ info exists default_group_name ] } {
#				puts "setting a default group"
				dbset group $newrn $default_group_name
			}
			
			if {  ( "uuid" ni $columns_present ) 
				&& ( ! [ catch { package present uuid } ] ) } {
#				puts "setting a new uuid"
				dbset uuid $newrn [uuid::uuid generate]
			}
			
			if { "title" ni $columns_present } {
#				puts "setting a default title"
				dbset title $newrn "Newly Imported [ clock format [ clock seconds ] ]"
			}

			AddRecordToTree $newrn
			incr new_add_counter
			
		} else {
			$::gorilla::db deleteRecord $newrn
		}

	} ; # end foreach line in input file
	
	if { [ info exists error_lines ] } {
		if { $::gorilla::DEBUG(CSVIMPORT) } {
			. configure -cursor $myOldCursor
			return [lindex $error_lines 0 0]
		}
		
		# puts "errors exist from import: $error_lines"
		set answer [ tk_messageBox -default yes -icon info \
			-message [ mc "Some records from the CSV file were not imported.\nDo you wish to save a log of skipped records?" ] \
			-parent . -title [ mc "Some records skipped during import" ] -type yesno ]
		if { $answer eq "yes" } {
			set fn [ tk_getSaveFile -parent . -title [ mc "Enter a file into which to save the log" ] ]
			if { $fn ne "" } {
				set outfd [ open $fn {WRONLY CREAT TRUNC} ]
				fconfigure $outfd -encoding utf-8
				foreach item $error_lines {
					puts $outfd [ join $item "\t" ] 
				}
				close $outfd
			} ; # end if fn ne ""
		} ; # end if answer eq yes
	} ; # end if exists error_lines
	
	if { $new_add_counter > 0 } {
		set ::gorilla::status "$new_add_counter [ mc "record(s) successfully imported." ]"
		MarkDatabaseAsDirty
	}

	catch { close $infd } 
  	. configure -cursor $myOldCursor
  	package forget csv
	return GORILLA_OK

} ; # end proc gorilla::Import

proc gorilla::ErrorPopup {title message} {

	# a small helper proc to encapsulate all the details of opening a
	# tk_messageBox with a title and message

	if { $::gorilla::DEBUG(CSVIMPORT) } { return }
	
	tk_messageBox -parent . -type ok -icon error -default ok \
		-title $title \
		-message $message 

} ; # end proc gorilla::ErrorPopup

proc gorilla::setup-default-dirname { } {

	# Makes sure that the global ::gorilla::dirName variable is set to a
	# sensible default if it does not already exist.
	#
	# Side-effect of modifying the global ::gorilla::dirName variable

	if { ! [ info exists ::gorilla::dirName ] } {
		if { [ tk windowingsystem ] == "aqua" } {
			set ::gorilla::dirName "~/Documents"
		} else {
		# pay attention to Windows environment
			set ::gorilla::dirName [ pwd ]
		}
	}

} ; # end proc setup-default-dirname

# ----------------------------------------------------------------------
# Mark database as dirty
# ----------------------------------------------------------------------

proc gorilla::MarkDatabaseAsDirty {} {
	set ::gorilla::dirty 1
	$::gorilla::widgets(tree) item "RootNode" -tags red

	if {[info exists ::gorilla::db]} {
		if {[$::gorilla::db getPreference "SaveImmediately"]} {
			
			if {[info exists ::gorilla::fileName]} {
				gorilla::Save
			} else {
				gorilla::SaveAs
			}
		}
	}

	UpdateMenu
}

# ----------------------------------------------------------------------
# Merge file
# ----------------------------------------------------------------------
#

variable gorilla::fieldNames [ list "" \
	"UUID" \
	"group name" \
	"title" \
	"user name" \
	"notes" \
	"password" \
	"creation time" \
	"password modification time" \
	"last access time" \
	"password lifetime" \
	"password policy" \
	"last modification time" \
	"URL" ]

proc gorilla::DestroyMergeReport {} {
	ArrangeIdleTimeout
	trace remove variable ::gorilla::merge_conflict_data {*}[ lindex [ trace info variable ::gorilla::merge_conflict_data ] 0 ]
	set top .mergeReport
	catch {destroy $top}
	unset ::gorilla::toplevel($top)
}

proc gorilla::DestroyDialog { top } {
	ArrangeIdleTimeout
	catch {destroy $top}
	unset ::gorilla::toplevel($top)
}

proc gorilla::CloseDialog { top } {
	if {[info exists ::gorilla::toplevel($top)]} {
		wm withdraw $top
	}
}

proc gorilla::Merge {} {
	set openInfo [OpenDatabase [mc "Merge Password Database"] "" 0]
	# set openInfo [OpenDatabase "Merge Password Database" "" 0]
	# enthält [list $fileName $newdb]
	
	set action [lindex $openInfo 0]

	if {$action != "Open"} {
		return
	}

	set ::gorilla::status [mc "Merging"]

	set fileName [lindex $openInfo 1]
	set newdb [lindex $openInfo 2]
	set nativeName [file nativename $fileName]

	set totalLogins 0
	set addedNodes [list]
	set conflictNodes [list]
	set identicalLogins 0

	set addedReport [list]
	set conflictReport [list]
	set identicalReport [list]
	set totalRecords [llength [$newdb getAllRecordNumbers]]

	::gorilla::progress init -win . -message [mc "Merging (%d %% done)"]

	foreach nrn [$newdb getAllRecordNumbers] {
		unset -nocomplain rn node
		
		incr totalLogins

		::gorilla::progress update-pbar . [expr {int(100.*$totalLogins/$totalRecords)}]
		
		set ngroup ""
		set ntitle ""
		set nuser ""

		if {[$newdb existsField $nrn 2]} {
			set ngroup [$newdb getFieldValue $nrn 2]
		}

		if {[$newdb existsField $nrn 3]} {
			set ntitle [$newdb getFieldValue $nrn 3]
		}

		if {[$newdb existsField $nrn 4]} {
			set nuser [$newdb getFieldValue $nrn 4]
		}

		#
		# See if the current database has a login with the same,
		# group, title and user
		#

		set found 0

		if {$ngroup == "" || [info exists ::gorilla::groupNodes($ngroup)]} {
			if {$ngroup != ""} {
				set parent $::gorilla::groupNodes($ngroup)
			} else {
				set parent "RootNode"
			}
	
			foreach node [$::gorilla::widgets(tree) children $parent] {
				set data [$::gorilla::widgets(tree) item $node -values]
				set type [lindex $data 0]

				if {$type != "Login"} {
					continue
				}

				set rn [lindex $data 1]

				set title [ ::gorilla::dbget title $rn ]
				set user  [ ::gorilla::dbget user  $rn ]

				if {[string equal $ntitle $title] && \
					[string equal $nuser $user]} {
					set found 1
					break
				}
			}
		}

		if {[info exists title]} {
			pwsafe::int::randomizeVar title user
		}

		#
		# If a record with the same group, title and user was found,
		# see if the other fields are also the same.
		#

		if {$found} {
			#
			# See if they both define the same fields. If one defines
			# a field that the other doesn't have, the logins can not
			# be identical. This works both ways. However, ignore
			# timestamps and the UUID, which may go AWOL between
			# different Password Safe clones.
			#

			set nfields [$newdb getFieldsForRecord $nrn]
			set fields [$::gorilla::db getFieldsForRecord $rn]
			set identical 1

			foreach nfield $nfields {
				if {$nfield == 1 || $nfield == 7 || $nfield == 8 || \
					$nfield == 9 || $nfield == 12} {
					continue
				}
				if {[$newdb getFieldValue $nrn $nfield] == ""} {
					continue
				}
				if {[lsearch -integer -exact $fields $nfield] == -1} {
					set reason "existing login is missing "
					if {$nfield > 0 && \
						$nfield < [llength $::gorilla::fieldNames]} {
						append reason "the " \
							[lindex $::gorilla::fieldNames $nfield] \
							" field"
					} else {
						append reason "field number $nfield"
					}
					set identical 0
					break
				}
			}

			if {$identical} {
				foreach field $fields {
					if {$field == 1 || $field == 7 || $field == 8 || \
						$field == 9 || $field == 12} {
						continue
					}
					if {[$::gorilla::db getFieldValue $rn $field] == ""} {
						continue
					}
					if {[lsearch -integer -exact $nfields $field] == -1} {
						set reason "merged login is missing "
						if {$field > 0 && \
							$field < [llength $::gorilla::fieldNames]} {
							append reason "the " \
								[lindex $::gorilla::fieldNames $field] \
								" field"
						} else {
							append reason "field number $field"
						}
						set identical 0
						break
					}
				}
			}

			#
			# See if fields have the same content
			#
			
			if {$identical} {
				foreach field $fields {
					if {$field == 1 || $field == 7 || $field == 8 || \
						$field == 9 || $field == 12} {
						continue
					}
					if {[$::gorilla::db getFieldValue $rn $field] == "" && \
						[lsearch -integer -exact $nfields $field] == -1} {
						continue
					}
					if {![string equal [$newdb getFieldValue $nrn $field] \
						[$::gorilla::db getFieldValue $rn $field]]} {
						set reason ""
						if {$field > 0 && \
							$field < [llength $::gorilla::fieldNames]} {
								append reason \
									[lindex $::gorilla::fieldNames $field] \
									" differs"
						} else {
							append reason "field number $field differs"
						}
						set identical 0
						break
					}
				}
			}
		}
		# not found
		#
		# If the two records are not identical, then we have a conflict.
		# Add the new record, but with a modified title.
		#
		# If the record has a "Last Modified" field, append that
		# timestamp to the title.
		#
		# Else, append " - merged <timestamp>" to the new record.
		#

		if {$found && !$identical} {
			set timestampFormat "%Y-%m-%d %H:%M:%S"

			if {[$newdb existsField $nrn 3]} {
				set title [$newdb getFieldValue $nrn 3]
			} else {
				set title "<No Title>"
			}

			if {[set index [string first " - modified " $title]] >= 0} {
				set title [string range $title 0 [expr {$index-1}]]
			} elseif {[set index [string first " - merged " $title]] >= 0} {
				set title [string range $title 0 [expr {$index-1}]]
			}

			if {[$newdb existsField $nrn 12]} {
				append title " - modified " [clock format \
			[$newdb getFieldValue $nrn 12] \
				-format $timestampFormat]
			} else {
				append title " - merged " [clock format \
				[clock seconds] \
				-format $timestampFormat]
			}
			$newdb setFieldValue $nrn 3 $title
			pwsafe::int::randomizeVar title
		}

		#
		# Add the record to the database, if this is either a new login
		# that does not exist in this database, or if the login was found,
		# but not identical.
		#

		if {!$found || !$identical} {
			set oldrn [ expr { [ info exists rn ] ? $rn : "" } ]
			set rn [$::gorilla::db createRecord]

			foreach field [$newdb getFieldsForRecord $nrn] {
				$::gorilla::db setFieldValue $rn $field   [$newdb getFieldValue $nrn $field]
			}

			set oldnode [ expr { [ info exists node ] ? $node : "" } ]
			set node [AddRecordToTree $rn]

			if {$found && !$identical} {
				#
				# Remember that there was a conflict
				#

				lappend conflictNodes $node

				set report [mc "Conflict for login %s" $ntitle]
				if {$ngroup != ""} {
					append report " [mc "(in group %s)" $ngroup]"
				}
				append report ": " [mc %s $reason] "."
				lappend conflictReport [ list $report $rn $oldrn $node $oldnode ]

				#
				# Make sure that this node is visible
				#

				set parent [$::gorilla::widgets(tree) parent $node]

				while {$parent != "RootNode"} {
					$::gorilla::widgets(tree) item $parent -open 1
					set parent [$::gorilla::widgets(tree) parent $parent]
				}

			} else {
				lappend addedNodes $node
				set report [mc "Added login %s" $ntitle]
				if {$ngroup != ""} {
					append report " [mc "(in group %s)" $ngroup]"
				}
				append report "."
				lappend addedReport [ list $report $rn ]
			}
		} else {
			incr identicalLogins
			set report [mc "Identical login %s" $ntitle]
			if {$ngroup != ""} {
				append report " [mc "(in group %s)" $ngroup]"
			}
			append report "."
			lappend identicalReport $report
		}

		pwsafe::int::randomizeVar ngroup ntitle nuser
	}

	::gorilla::progress finished .

	itcl::delete object $newdb
	MarkDatabaseAsDirty

	set numAddedLogins [llength $addedNodes]
	set numConflicts [llength $conflictNodes]

	set message [ mc "Merged %s;\n%d %s, %d identical, %d added, %d %s." \
		$nativeName $totalLogins \
		[ expr { $totalLogins == 1 ? [ mc "login" ] : [ mc "logins" ] } ] \
		$identicalLogins $numAddedLogins $numConflicts \
		[ expr { $numConflicts == 1 ? [ mc "conflict" ] : [ mc "conflicts" ] } ] \
	]

	set ::gorilla::status $message

	if {$numConflicts > 0} {
		set default "yes"
		set icon "warning"
	} else {
		set default "no"
		set icon "info"
	}

	# Build a list suitable for passing to ::gorilla::conflict-dialog and
	# save it to the global "conflicts" variable.  This is so that
	# someone can resolve conflicts "later" if they just want to get on
	# with merging right now.  Also append to anything that might be
	# already present, allowing multiple sequential merges to then all
	# be conflict resolved from a single dialog.

	foreach {item} $conflictReport {
		lappend ::gorilla::merge_conflict_data [ lindex $item 2 ] [ lindex $item 1 ] [ lindex $item 4 ] [ lindex $item 3 ]
	}
	UpdateMenu

	set answer [tk_messageBox -parent . -type yesno \
		-icon $icon -default $default \
		-title [mc "Merge Results"] \
		-message "$message\n[ mc "Do you want to view a detailed report?"]"]

	if {$answer != "yes"} {
		return
	}

	set top ".mergeReport"

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top -class "Gorilla"
		wm title $top [mc "Merge Report for $nativeName"]

		set text [text $top.text -relief sunken -width 100 -wrap word \
		-yscrollcommand "$top.vsb set"]

		if {[tk windowingsystem] ne "aqua"} {
			ttk::scrollbar $top.vsb -orient vertical -command "$top.text yview"
		} else {
			scrollbar $top.vsb -orient vertical -command "$top.text yview"
		}
		## Arrange the tree and its scrollbars in the toplevel
		lower [ttk::frame $top.dummy]
		pack $top.dummy -fill both -fill both -expand 1
		grid $top.text $top.vsb -sticky nsew -in $top.dummy
		grid columnconfigure $top.dummy 0 -weight 1
		grid rowconfigure $top.dummy 0 -weight 1
		
		set botframe [ ttk::frame  $top.botframe ]
		set resolve_b  [ ttk::button $botframe.resolve -text [ mc "Resolve Conflicts" ] -state disabled \
			-command [ list catch {::gorilla::conflict-dialog $::gorilla::merge_conflict_data} ] ]

		trace add variable ::gorilla::merge_conflict_data write [ list apply [ list args [ string map [ list %rcb $resolve_b ] {
			if { ( ! [ info exists ::gorilla::merge_conflict_data ] ) ||
			     ( [ llength $::gorilla::merge_conflict_data ] == 0 ) } {
				%rcb configure -state disabled
				# also turn off File->Resolve Conflicts menu entry
				::gorilla::UpdateMenu
			} else {
				%rcb configure -state normal
			}
			} ] ] ]

		if { [ info exists ::gorilla::merge_conflict_data ] && 
		     [ llength $::gorilla::merge_conflict_data ] > 0 } {
			$resolve_b configure -state normal
		}

		set close_b [ttk::button $botframe.but2 -text [mc "Close"] \
			-command "gorilla::DestroyMergeReport"]
		grid $resolve_b $close_b
		grid columnconfigure $botframe all -weight 1
		pack $botframe -side top -fill x -pady 10
		
		bind $top <Prior> "$text yview scroll -1 pages; break"
		bind $top <Next> "$text yview scroll 1 pages; break"
		bind $top <Up> "$text yview scroll -1 units"
		bind $top <Down> "$text yview scroll 1 units"
		bind $top <Home> "$text yview moveto 0"
		bind $top <End> "$text yview moveto 1"
		bind $top <Return> "gorilla::DestroyMergeReport"
		
		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW gorilla::DestroyMergeReport
				
	} else {
		wm deiconify $top
		set text "$top.text"
		set botframe "$top.botframe"
	}

	$text configure -state normal
	$text delete 1.0 end
	$text tag delete {*}[ $text tag names ]

	$text insert end $message
	$text insert end "\n\n"

	$text insert end [string repeat "-" 70]
	$text insert end "\n"
	$text insert end "[mc "Conflicts"]\n"
	$text insert end [string repeat "-" 70]
	$text insert end "\n"
	$text insert end "\n"

	set seq 0
	set default_cursor [ lindex [ $text configure -cursor ] 3 ]

	if {[llength $conflictReport] > 0} {
		foreach report $conflictReport {
			$text tag configure link$seq -foreground blue -underline true

			$text tag bind link$seq <Enter> [ list $text configure -cursor hand2 ]
			$text tag bind link$seq <Leave> [ list $text configure -cursor $default_cursor ]
			$text tag bind link$seq <Button-1> " ::gorilla::ViewEntry [ lindex $report 1 ]
								::gorilla::ViewEntry [ lindex $report 2 ]"

			$text insert end "[ lindex $report 0 ]\n" link$seq
			incr seq
		}
	} else {
		$text insert end "None.\n"
	}

	$text insert end "\n"
	$text insert end [string repeat "-" 70]
	$text insert end "\n"
	$text insert end "Added Logins\n"
	$text insert end [string repeat "-" 70]
	$text insert end "\n"
	$text insert end "\n"

	if {[llength $addedReport] > 0} {
		foreach report $addedReport {
			$text tag configure link$seq -foreground blue -underline true

			$text tag bind link$seq <Enter> [ list $text configure -cursor hand2 ]
			$text tag bind link$seq <Leave> [ list $text configure -cursor $default_cursor ]
			$text tag bind link$seq <Button-1> " ::gorilla::ViewEntry [ lindex $report 1 ] "

			$text insert end "[ lindex $report 0 ]\n" link$seq
			incr seq
		}
	} else {
		$text insert end "None.\n"
	}
	$text insert end "\n"

	$text insert end [string repeat "-" 70]
	$text insert end "\n"
	$text insert end "Identical Logins\n"
	$text insert end [string repeat "-" 70]
	$text insert end "\n"
	$text insert end "\n"
	if {[llength $identicalReport] > 0} {
		foreach report $identicalReport {
			$text insert end $report
			$text insert end "\n"
		}
	} else {
		$text insert end "None.\n"
	}
	$text insert end "\n"

	$text configure -state disabled

	update idletasks
	wm deiconify $top
	raise $top
#	focus $botframe.but
} ; # end ::gorilla::Merge


proc gorilla::Save {} {
	ArrangeIdleTimeout

	#
	# Test for write access to the pwsafe database
	#
	# If not writable, give user the option to change it to writable and
	# retry, or to abort the save operation entirely
	#
	# Work around tcl-Bugs-1852572 regarding "file writable" and samba mounts
	# by simply attempting to open the file in write only append mode (append
	# so as not to destroy the file while testing for write access).  If the
	# open succeeds, we have write permission.

	while { [ catch { set fd [ open $::gorilla::fileName {WRONLY APPEND} ] } ] } {

		# build the message in two stages:
		set message    "[ mc "Warning: Can not save to" ] '[ file normalize $::gorilla::fileName ]' [ mc "because the file permissions are set for read-only access." ]\n\n"
		append message "[ mc "Please change the file permissions to read-write and hit 'Retry' or hit 'Cancel' and use 'File'->'Save As' to save into a different file." ]\n"

		set answer [ tk_messageBox -icon warning -type retrycancel -title [ mc "Warning: Read-only password file" ] -message $message ]

		if { $answer eq "cancel" } {
			return 0
		}
	
	} ; # end while gorilla::fileName read-only

	# don't need the open file descriptor once out of the while loop
	close $fd

	set myOldCursor [. cget -cursor]
	. configure -cursor watch
	update idletasks

	set nativeName [file nativename $::gorilla::fileName]

	if-platform? unix {
		# note - failure to retreive permissions (i.e., db file on
		# Samba share mounted on Linux machine) is not considered a
		# fatal issue
		if { [ catch { set unix_permissions [ file attributes $::gorilla::fileName -permissions ] } m1 m2 ] } {
		  puts stderr "Warning: failure retreiving Unix permissions on file $::gorilla::fileName.\n$m1\n$m2"
		}
	}
	
	#
	# Determine file version. If there is a header field of type 0,
	# it should indicate the version. Otherwise, default to version 2.
	#

	set majorVersion 2

	if {[$::gorilla::db hasHeaderField 0]} {
		set version [$::gorilla::db getHeaderField 0]

		if {[lindex $version 0] == 3} {
			set majorVersion 3
		}
	}
	set pvar [ ::gorilla::progress init -win .status -message [ mc "Saving ... %d %%" ] -max 200 ]

	# avoid gray area during save
	update

	if { [ catch { pwsafe::writeToFile $::gorilla::db $nativeName $majorVersion \
			$pvar } oops ] } {
		::gorilla::progress finished .status
		
		. configure -cursor $myOldCursor
		gorilla::ErrorPopup [ mc "Error Saving Backup of Database"] \
			[mc "Failed to save password database as\n%s: %s" $nativeName $oops ]
		return GORILLA_SAVEBACKUPERROR
	}

	::gorilla::progress finished .status
	
	# The actual data are saved. Now take care of a backup file

	set message [ gorilla::SaveBackup $::gorilla::fileName ]

	if { $message ne "GORILLA_OK" } {
		. configure -cursor $myOldCursor
		gorilla::ErrorPopup  [lindex $message 0] [lindex $message 1]
		return GORILLA_SAVEBACKUPERROR
	}

	. configure -cursor $myOldCursor

	set ::gorilla::dirty 0
	$::gorilla::widgets(tree) item "RootNode" -tags black

	UpdateMenu

	# attempt to restore cached file permissions under unix
	if-platform? unix {
		# note - failure to set cached permissions on the new file
		# is not considered a fatal issue
		if { [ catch { file attributes $::gorilla::fileName -permissions $unix_permissions } m1 m2 ] } {
		  puts stderr "Warning: failure applying cached Unix permissions to file $::gorilla::fileName.\n$m1\n$m2"
		}
	}

	# The actual data are saved. Now take care of a backup file

	if {$::gorilla::preference(keepBackupFile)} {
		set message [ gorilla::SaveBackup $::gorilla::fileName ]
		if { [lindex $message 0] ne "GORILLA_OK" } {
			# gorilla::ErrorPopup  [lindex $message 0] [lindex $message 1]
			set ::gorilla::status [mc "Password database saved but backup copy failed: [lindex $message 1]." ]
			return GORILLA_SAVEBACKUPERROR
		} else {
			set ::gorilla::status [mc "Password database saved with backup copy." ]
			return GORILLA_OK
		}
	}
	set ::gorilla::status [mc "Password database saved."] 
	
	return GORILLA_OK
}

#
# ----------------------------------------------------------------------
# Save As
# ----------------------------------------------------------------------
#

proc gorilla::SaveAs {} {
	ArrangeIdleTimeout

	if {![info exists ::gorilla::db]} {
		gorilla::ErrorPopup [ mc "Nothing To Save" ] \
		[ mc "No password database to save." ]
		return GORILLA_SAVEERROR
	}

	#
	# Determine file version. If there is a header field of type 0,
	# it should indicate the version. Otherwise, default to version 2.
	#

	set majorVersion 2

	if {[$::gorilla::db hasHeaderField 0]} {
		set version [$::gorilla::db getHeaderField 0]

		if {[lindex $version 0] == 3} {
			set majorVersion 3
		}
	}
	if {$majorVersion == 3} {
		set defaultExtension ".psafe3"
	} else {
		set defaultExtension ".dat"
	}

	#
	# Query user for file name
	#

	set fileName [ filename_query Save -parent . \
		-title [ mc "Save password database ..." ] ]

	if {$fileName == ""} {
		return 0
	}

	# -defaultextension seems not to work on Linux
	# set fileName [gorilla::CheckDefaultExtension $fileName $defaultExtension]
	set nativeName [file nativename $fileName]
	
	set myOldCursor [. cget -cursor]
	. configure -cursor watch
	update idletasks

	set pvar [ ::gorilla::progress init -win .status -message [ mc "Saving ... %d %%" ] -max 200 ]

	if { [ catch { pwsafe::writeToFile $::gorilla::db $fileName $majorVersion $pvar } oops] } {
		::gorilla::progress finished .status
		. configure -cursor $myOldCursor
		tk_messageBox -parent . -type ok -icon error -default ok \
			-title [mc "Error Saving Database"] \
			-message [mc "Failed to save password database as \"%s\": %s" \
			$nativeName $oops]
		return 0
	}

	::gorilla::progress finished .status

	# The actual data are saved. Now take care of a backup file

  set ::gorilla::fileName $fileName
	set message [ gorilla::SaveBackup $::gorilla::fileName ]

	if { $message ne "GORILLA_OK" } {
		. configure -cursor $myOldCursor
		gorilla::ErrorPopup  [lindex $message 0] [lindex $message 1]
		return GORILLA_SAVEBACKUPERROR
	}

	# clean up
	
	. configure -cursor $myOldCursor
	set ::gorilla::dirty 0
	$::gorilla::widgets(tree) item "RootNode" -tags black
	
	wm title . "Password Gorilla - $nativeName"
	$::gorilla::widgets(tree) item "RootNode" -text $nativeName
	
	if {$::gorilla::preference(keepBackupFile)} {
		set ::gorilla::status [mc "Password database saved with backup copy" ] 
	} else {
		set ::gorilla::status [mc "Password database saved."] 
	}
	
	# Add file to LRU preference

	set found [lsearch -exact $::gorilla::preference(lru) $nativeName]
	if {$found == -1} {
		set ::gorilla::preference(lru) [linsert $::gorilla::preference(lru) 0 $nativeName]
	} elseif {$found != 0} {
		set tmp [lreplace $::gorilla::preference(lru) $found $found]
		set ::gorilla::preference(lru) [linsert $tmp 0 $nativeName]
	}
	
	UpdateMenu

	# The actual data are saved. Now take care of a backup file

	if {$::gorilla::preference(keepBackupFile)} {
		set message [ gorilla::SaveBackup $::gorilla::fileName ]
		if { [lindex $message 0] ne "GORILLA_OK" } {
			# gorilla::ErrorPopup  [lindex $message 0] [lindex $message 1]
			set ::gorilla::status [mc "Password database saved but backup copy failed: [lindex $message 1]." ]
			return GORILLA_SAVEBACKUPERROR
		} else {
			set ::gorilla::status [mc "Password database saved with backup copy." ]
			return GORILLA_OK
		}
	}
	set ::gorilla::status [mc "Password database saved."] 
	
	return GORILLA_OK
  
} ; # end proc gorilla::SaveAs

proc gorilla::filename_query {type args} {

	if { $type ni {Open Save} } {
		error "type parameter must be one of 'Open' or 'Save'"
	}
	
	set types {	{{Password Database Files} {.psafe3 .dat}}
			{{All Files} *}	}

  if {[tk windowingsystem] == "aqua"} {
    # if MacOSX - remove the .psafe3 type leaving only "*"
    # set types [ lreplace $types 0 0 ]
    set types [list ]
  }

	setup-default-dirname

	tk_get${type}File {*}$args -filetypes $types -initialdir $::gorilla::dirName

} ; # end proc gorilla::filename_query

proc gorilla::SaveBackup { filename } {
	# tries to backup the actual database observing the keepBackupFile flag.
	# If the backup fails an errorType and a errorMessage string filtered
	# by msgcat are returned.
	#
	# If the timestamp flag is set the backup file gets a timestamp appendix
	# according to the local settings
	#
	# filename - name of current database containing full path
	#

	set errorType [ mc "Error Saving Backup of Database" ]

	# create a backup filename based upon timeStampBackup preference

	if { ! $::gorilla::preference(timeStampBackup) } {
		set backupFileName "[file rootname [file tail $filename] ].bak"
	} else {
		# Note: The following characters are reserved in Windows and
		# cannot be used in a file name: < > : " / \ | ? *
		set backupFileName [ file rootname [file tail $filename] ]
		append backupFileName "[clock format [clock seconds] -format "-%Y-%m-%d-%H-%M-%S" ]"
		append backupFileName [file extension $filename]
	}

  # determine where to save the backup based upon preference setting
        
	if { $::gorilla::preference(backupPath) eq "" } {
		# place backup file into same directory as current password db file
		set backupPath [ file dirname $filename ]
	} else {
		# place backup file into users preference directory

		set backupPath $::gorilla::preference(backupPath)
		if { ! [file isdirectory $backupPath] } {
			return [list $errorType [mc "No valid directory. - \nPlease define a valid backup directory\nin the Preferences menu."] ]
		}	elseif { ! [file exists $filename] } {
			return [list $errorType [mc "Unknown file. - \nPlease select a valid database filename."] ]
		}	elseif { [ info exists ::gorilla::isLocked ] && $::gorilla::isLocked } {
				set backupFileName "[ file tail $filename ]~"
		}
	} ; # end if backupPath preference
	
	set backupFile [ file join $backupPath $backupFileName ]

	if {[catch {
		file copy -force -- $filename $backupFile
		} oops]} {
		set backupNativeName [file nativename $backupFileName]
		return $errorType [ mc "Failed to make backup copy of password\ndatabase as %s: \n%s" $backupNativeName $oops ]
	}

	return GORILLA_OK
} ;# end of proc gorilla::SaveBackup

# ----------------------------------------------------------------------
# Rebuild Tree
# ----------------------------------------------------------------------
#

proc gorilla::AddAllRecordsToTree {} {
	foreach rn [$::gorilla::db getAllRecordNumbers] {
		AddRecordToTree $rn
	}
}

proc gorilla::AddRecordToTree {rn} {
	set groupName [ ::gorilla::dbget group $rn ]

	set parentNode [AddGroupToTree $groupName]

	set title [ ::gorilla::dbget title $rn ]

	if { ( [ ::gorilla::dbget user $rn ] ne "" ) && 
	     ( ! $::gorilla::preference(hideLogins) ) } {
		append title " \[" [ ::gorilla::dbget user $rn ] "\]"
	}

	#
	# Insert the new login in alphabetical order, after all groups
	#

	# set childNodes [$::gorilla::widgets(tree) nodes $parentNode]
	set childNodes [$::gorilla::widgets(tree) children $parentNode]

	for {set i 0} {$i < [llength $childNodes]} {incr i} {
		set childNode [lindex $childNodes $i]
		set childData [$::gorilla::widgets(tree) item $childNode -values]
		if {[lindex $childData 0] != "Login"} {
			continue
		}

		set childName [$::gorilla::widgets(tree) item $childNode -text]
		if {[string compare $title $childName] < 0} {
			break
		}
	}

	if {$i >= [llength $childNodes]} {
		set i "end"
	}

	set nodename "node[incr ::gorilla::uniquenodeindex]"
	$::gorilla::widgets(tree) insert $parentNode $i -id $nodename \
		-open 0	\
		-image $::gorilla::images(login) \
		-text $title \
		-values [list Login $rn]
		# -drawcross never
	return $nodename
}

proc gorilla::AddGroupToTree {groupName} {
	if {[info exists ::gorilla::groupNodes($groupName)]} {
		set parentNode $::gorilla::groupNodes($groupName)
	} elseif {$groupName == ""} {
		set parentNode "RootNode"
	} else {
		set parentNode "RootNode"
		set partialGroups [list]
		foreach group [pwsafe::db::splitGroup $groupName] {
			lappend partialGroups $group
			set partialGroupName [pwsafe::db::concatGroups $partialGroups]
			if {[info exists ::gorilla::groupNodes($partialGroupName)]} {
				set parentNode $::gorilla::groupNodes($partialGroupName)
			} else {
				set childNodes [$::gorilla::widgets(tree) children $parentNode]
	
				#
				# Insert group in alphabetical order, before all logins
				#

				for {set i 0} {$i < [llength $childNodes]} {incr i} {
					set childNode [lindex $childNodes $i]
					set childData [$::gorilla::widgets(tree) item $childNode -values]
					if {[lindex $childData 0] != "Group"} {
						break
					}

					set childName [$::gorilla::widgets(tree) item $childNode -text]
					if {[string compare $group $childName] < 0} {
						break
					}
				}
				
				if {$i >= [llength $childNodes]} {
					set i "end"
				}
				
				set nodename "node[incr ::gorilla::uniquenodeindex]"
				
				$::gorilla::widgets(tree) insert $parentNode	$i -id $nodename \
					-open 0 \
					-image $::gorilla::images(group) \
					-text $group \
					-values [list Group $partialGroupName]
				
				set parentNode $nodename
				set ::gorilla::groupNodes($partialGroupName) $nodename
			}
		}
	}

	return $parentNode
}

proc gorilla::FocusRootNode {} {
	focus .tree
	.tree focus "RootNode"
}
#
# Update Menu items
#


proc gorilla::UpdateMenu {} {

	lassign [ ::gorilla::get-selected-tree-data ] node type rn
	
	if { ( $node eq "" ) && ( $type eq "" ) } {
		setmenustate $::gorilla::widgets(main) group disabled
		setmenustate $::gorilla::widgets(main) login disabled
	} else {
		if {$type == "Group" || $type == "Root"} {
			setmenustate $::gorilla::widgets(main) group normal
			setmenustate $::gorilla::widgets(main) login disabled
		} else {
			setmenustate $::gorilla::widgets(main) group disabled
			setmenustate $::gorilla::widgets(main) login normal
		}
	}

	if {[info exists ::gorilla::fileName] && [info exists ::gorilla::db] && $::gorilla::dirty} {
		setmenustate $::gorilla::widgets(main) save normal
	} else {
		setmenustate $::gorilla::widgets(main) save disabled
	}

	if {[info exists ::gorilla::db]} {
		setmenustate $::gorilla::widgets(main) open normal
	} else {
		setmenustate $::gorilla::widgets(main) open disabled
	}
	
	if { [ info exists ::gorilla::merge_conflict_data ] &&
		 ( [ llength $::gorilla::merge_conflict_data ] > 0 ) } {
		setmenustate $::gorilla::widgets(main) conflict normal
	} else {
		setmenustate $::gorilla::widgets(main) conflict disabled
	}

    if { ! $::gorilla::hasDownloadsFile } {
		setmenustate $::gorilla::widgets(main) dld disabled
    }
	
}

proc gorilla::Exit {} {
	ArrangeIdleTimeout

	#
	# Protect against reentrancy, i.e., if the user clicks on the "X"
	# window manager decoration multiple times.
	#

	if {[info exists ::gorilla::exiting] && $::gorilla::exiting} {
		return
	}

	set ::gorilla::exiting 1

	#
	# If the current database was modified, give user a chance to think
	#

	if {$::gorilla::dirty} {
		set myParent [grab current .]

		if {$myParent == ""} {
			set myParent "."
		}

		set answer [tk_messageBox -parent $myParent \
		-type yesnocancel -icon warning -default yes \
		-title [ mc "Save changes?" ] \
		-message [ mc "The current password database is modified. Do you want to save the database? <Yes> saves the database and exits. <No> discards all changes and exits. <Cancel> returns to the main menu." ]]
		
		if {$answer == "yes"} {
			if {[info exists ::gorilla::fileName]} {
				if { [::gorilla::Save] ne "GORILLA_OK" } {
					set ::gorilla::exiting 0
				}
			} else {
				if { [::gorilla::SaveAs] ne "GORILLA_OK" } {
					set ::gorilla::exiting 0
				}
			}
		} elseif {$answer != "no"} {
			set ::gorilla::exiting 0
		}
		if {!$::gorilla::exiting} {
			return 0
		}
	}

	#
	# Save preferences
	#

	SavePreferences

	#
	# Clear the clipboard, if we were meant to do that sooner or later.
	#

	if {[info exists ::gorilla::clipboardClearId]} {
		after cancel $::gorilla::clipboardClearId
		ClearClipboard
	}

	#
	# Goodbye, cruel world
	#

	destroy .
	exit
}

# ----------------------------------------------------------------------
# Clear clipboard
# ----------------------------------------------------------------------
#

proc gorilla::ClearClipboard {} {
	clipboard clear
	clipboard append -- ""

	foreach sel { PRIMARY CLIPBOARD } {
		if {[selection own -selection $sel ] == "."} {
			selection clear -selection $sel
		}
	}

	set ::gorilla::activeSelection 0
	set ::gorilla::status [mc "Clipboard cleared."]
	catch {unset ::gorilla::clipboardClearId}
}

# ----------------------------------------------------------------------
# Clear the clipboard after a configurable number of seconds
# ----------------------------------------------------------------------
#

proc gorilla::ArrangeToClearClipboard { {mult 1} } {
	if {[info exists ::gorilla::clipboardClearId]} {
		after cancel $::gorilla::clipboardClearId
	}

	if {$::gorilla::preference(clearClipboardAfter) == 0} {
		catch {unset ::gorilla::clipboardClearId}
		return
	}

	set seconds $::gorilla::preference(clearClipboardAfter)
	set mseconds [expr {$seconds * 1000 * $mult }]
	if { $mseconds == 0 } { return }
	set ::gorilla::clipboardClearId [after $mseconds ::gorilla::ClearClipboard]
}


# ----------------------------------------------------------------------
# Arrange for an Idle Timeout after a number of minutes
# ----------------------------------------------------------------------
#

proc gorilla::ArrangeIdleTimeout {} {
	if {[info exists ::gorilla::idleTimeoutTimerId]} {
		after cancel $::gorilla::idleTimeoutTimerId
	}

	if {[info exists ::gorilla::db]} {
		set minutes [$::gorilla::db getPreference "IdleTimeout"]

		if {![$::gorilla::db getPreference "LockOnIdleTimeout"] || $minutes <= 0} {
			catch {unset ::gorilla::idleTimeoutTimerId}
			return
		}

	set seconds [expr {$minutes * 60}]
	set mseconds [expr {$seconds * 1000}]
	set ::gorilla::idleTimeoutTimerId [after $mseconds ::gorilla::IdleTimeout]
	}
}


# ----------------------------------------------------------------------
# Idle Timeout
# ----------------------------------------------------------------------


proc gorilla::IdleTimeout {} {
	LockDatabase
}

# ----------------------------------------------------------------------
# Lock Database
# ----------------------------------------------------------------------
#

proc gorilla::CloseLockedDatabaseDialog {} {
	set ::gorilla::lockedMutex 2
}

proc gorilla::LockDatabase {} {
	if {![info exists ::gorilla::db]} {
		return
	}

	if {[info exists ::gorilla::isLocked] && $::gorilla::isLocked} {
		return
	}

	if {[info exists ::gorilla::idleTimeoutTimerId]} {
		after cancel $::gorilla::idleTimeoutTimerId
	}

	ClearClipboard
	set ::gorilla::isLocked 1

	set oldGrab [grab current .]

	# close all open windows and remember their status and location
	foreach tl [array names ::gorilla::toplevel] {
		set ws [wm state $tl]
		switch -- $ws {
			normal -
			iconic -
			zoomed {
				set withdrawn($tl) [ list $ws [ wm geometry $tl ] ]
				wm withdraw $tl
			}
		}
	}
	
	# MacOSX gives access to the menubar as long as the application is launched
	# so we grey out the menuitems
	if {[tk windowingsystem] eq "aqua"} {
		# save current state of menu entries
		set stateofmenus [ getMenuState $::gorilla::widgets(main) ]
		setmenustate $::gorilla::widgets(main) all disabled
		rename ::tk::mac::ShowPreferences ""
	}

	if { $::gorilla::preference(keepBackupFile) } {
    
    if { ![info exists ::gorilla::fileName] } {
      set nosave [tk_dialog .nosave [mc "Database not saved!"] \
      [mc "This database has not been saved. Do you want to save it now?"] \
        "" 0 [mc Yes] [mc No] ]
      if {$nosave} { set message GORILLA_OK
      } else { set message [gorilla::SaveAs] }
      
    } else { set message [ gorilla::SaveBackup $::gorilla::fileName ] }

		if { $message ne "GORILLA_OK" } {
			gorilla::ErrorPopup  [lindex $message 0] [lindex $message 1]
		}
	} ;# endif $::gorilla::preference(keepBackupFile)

	set top .lockedDialog
	if {![info exists ::gorilla::toplevel($top)]} {
		
		toplevel $top -class "Gorilla"
		TryResizeFromPreference $top

		if {$::gorilla::preference(gorillaIcon)} {
			ttk::label $top.splash -image $::gorilla::images(splash)
			pack $top.splash -side left -fill both

			ttk::separator $top.vsep -orient vertical
			pack $top.vsep -side left -fill y -padx 3
		}

		set aframe [ttk::frame $top.right -padding {10 10}]

		# Titel packen	
		# ttk::label $aframe.title -anchor center -font {Helvetica 12 bold}
		ttk::label $aframe.title -anchor center
		pack $aframe.title -side top -fill x -pady 10

		ttk::labelframe $aframe.file -text [mc "Database:"]
		ttk::entry $aframe.file.f -width 40 -state disabled
		pack $aframe.file.f -side left -padx 10 -pady 5 -fill x -expand yes
		pack $aframe.file -side top -pady 5 -fill x -expand yes

		ttk::frame $aframe.mitte
		ttk::labelframe $aframe.mitte.pw -text [mc "Password:"] 
		entry $aframe.mitte.pw.pw -width 20 -show "*" 
		# -background #FFFFCC
		pack $aframe.mitte.pw.pw -side left -padx 10 -pady 5 -fill x -expand 0
		
		pack $aframe.mitte.pw -side left -pady 5 -expand 0

		ttk::frame $aframe.mitte.buts
		set but1 [ttk::button $aframe.mitte.buts.b1 -width 10 -text [ mc "OK" ] \
			-command "set ::gorilla::lockedMutex 1"]
		set but2 [ttk::button $aframe.mitte.buts.b2 -width 10 -text [mc "Exit"] \
			-command "set ::gorilla::lockedMutex 2"]
		pack $but1 $but2 -side left -pady 10 -padx 10
		pack $aframe.mitte.buts -side right

		pack $aframe.mitte -side top -fill x -expand 1 -pady 15
		
		ttk::label $aframe.info -relief sunken -anchor w -padding [list 5 5 5 5]
		pack $aframe.info -side bottom -fill x -expand yes

		bind $aframe.mitte.pw.pw <Return> "set ::gorilla::lockedMutex 1"
		bind $aframe.mitte.buts.b1 <Return> "set ::gorilla::lockedMutex 1"
		bind $aframe.mitte.buts.b2 <Return> "set ::gorilla::lockedMutex 2"
			
		pack $aframe -side right -fill both -expand yes

		set ::gorilla::toplevel($top) $top
		
		wm protocol $top WM_DELETE_WINDOW gorilla::CloseLockedDatabaseDialog
	} else {
		set aframe $top.right
		if { ! $::gorilla::preference(iconifyOnAutolock) } {
			wm deiconify $top
		}
	}

	wm title $top "Password Gorilla"
	$aframe.title configure -text  [ ::gorilla::LockDirtyMessage ]

	# and setup a pair of variable write traces to toggle the title text
	#
	# the toggle happens upon
	# 1) database marked dirty/clean
	# 2) open/close of edit password dialogs

	trace add variable ::gorilla::dirty write [ namespace code [ list ::gorilla::LockDirtyHandler $aframe.title ] ]
	trace add variable ::gorilla::LoginDialog::arbiter write [ namespace code [ list ::gorilla::LockDirtyHandler $aframe.title ] ]
	
	$aframe.mitte.pw.pw delete 0 end
	$aframe.info configure -text [mc "Enter the Master Password."]

	if {[info exists ::gorilla::fileName]} {
		$aframe.file.f configure -state normal
		$aframe.file.f delete 0 end
		$aframe.file.f insert 0 [file nativename $::gorilla::fileName]
		$aframe.file.f configure -state disabled
	} else {
		$aframe.file.f configure -state normal
		$aframe.file.f delete 0 end
		$aframe.file.f insert 0 [mc "<New Database>"]
		$aframe.file.f configure -state disabled
	}

	#
	# Run dialog
	#

	focus $aframe.mitte.pw.pw
	# synchronize Tk's event-loop with Aqua's event-loop
	update idletasks
  
	if {[catch { grab $top } oops]} {
		set ::gorilla::status [mc "error: %s" $oops]
	}
		
	if { $::gorilla::preference(iconifyOnAutolock) } {
		wm iconify $top
	}

	if { ! $::gorilla::DEBUG(TEST) } {		
		while {42} {
			set ::gorilla::lockedMutex 0
			vwait ::gorilla::lockedMutex
	
			if {$::gorilla::lockedMutex == 1} {
				if {[$::gorilla::db checkPassword [$aframe.mitte.pw.pw get]]} {
					break
				}
	
				tk_messageBox -parent $top \
					-type ok -icon error -default ok \
					-title [ mc "Wrong Password" ] \
					-message [ mc "That password is not correct." ]
	
				 # clear the PW entry upon invalid PW
				 $aframe.mitte.pw.pw delete 0 end
						 
			} elseif {$::gorilla::lockedMutex == 2} {
				#
				# This may return, if the database was modified, and the user
				# answers "Cancel" to the question whether to save the database
				# or not.
				#
	
				gorilla::Exit
			}
		}
	}
	
	# restore all closed window statuses and positions
	foreach tl [array names withdrawn] {
		wm state    $tl [ lindex $withdrawn($tl) 0 ]
		wm geometry $tl [ lindex $withdrawn($tl) 1 ]
	}
		
	if {$oldGrab != ""} {
		catch {grab $oldGrab}
	} else {
		catch {grab release $top}
	}

	if { [tk windowingsystem] eq "aqua"} {
		# restore saved menu entry states
		eval $stateofmenus
		eval $::gorilla::MacShowPreferences
	}
		
	wm withdraw $top
	set ::gorilla::status [mc "Welcome back."]

	set ::gorilla::isLocked 0
	wm withdraw .
	wm deiconify .
	raise .
	ArrangeIdleTimeout
	return GORILLA_OK
}

# ----------------------------------------------------------------------

proc gorilla::LockDirtyMessage {} {
  if { $::gorilla::dirty || ( [ dict size $::gorilla::LoginDialog::arbiter ] > 0 ) } {
    return [ mc "Database Locked (with unsaved changes)" ]
  } else {
    return [ mc "Database Locked" ]
  }
}

# ----------------------------------------------------------------------

proc gorilla::LockDirtyHandler { win args } {
  $win configure -text [ ::gorilla::LockDirtyMessage ]
}

# ----------------------------------------------------------------------
# Prompt for a Password
# ----------------------------------------------------------------------
#

proc gorilla::DestroyGetPasswordDialog {} {
	set ::gorilla::guimutex 2
}

proc gorilla::GetPassword {confirm title} {
	set top .passwordDialog-$confirm

	if {![info exists ::gorilla::toplevel($top)]} {
		if {[tk windowingsystem] == "aqua"} {
			toplevel $top -background #ededed -class "Gorilla"
		} else {
			toplevel $top -class "Gorilla"
		}
		TryResizeFromPreference $top

		ttk::labelframe $top.password -text $title -padding [list 10 10]
		ttk::entry $top.password.e -show "*" -width 30 -textvariable ::gorilla::passwordDialog.pw

		pack $top.password.e -side left
		pack $top.password -fill x -pady 15 -padx 15 -expand 1
		
		bind $top.password.e <KeyPress> "+::gorilla::CollectTicks"
		bind $top.password.e <KeyRelease> "+::gorilla::CollectTicks"

		if {$confirm} {
			ttk::labelframe $top.confirm -text [mc "Confirm:"] -padding [list 10 10]
			ttk::entry $top.confirm.e -show "*" -width 30 -textvariable ::gorilla::passwordDialog.c
			pack $top.confirm.e -side left
			pack $top.confirm -fill x -pady 5 -padx 15 -expand 1

			bind $top.confirm.e <KeyPress> "+::gorilla::CollectTicks"
			bind $top.confirm.e <KeyRelease> "+::gorilla::CollectTicks"
			# bind $top.confirm.e <Shift-Tab> "after 0 \"focus $top.password.e\""
			# bind $top.confirm.e <Tab> "after 0 \"focus $top.password.e\""
		}

		ttk::frame $top.buts
		set but1 [ttk::button $top.buts.b1 -width 10 -text [ mc OK ] \
			-command "set ::gorilla::guimutex 1"]
		set but2 [ttk::button $top.buts.b2 -width 10 -text [mc "Cancel"] \
			-command "set ::gorilla::guimutex 2"]
		pack $but1 $but2 -side left -pady 15 -padx 30
		pack $top.buts -fill x -expand 1
		
		bind $top.password.e <Return> "set ::gorilla::guimutex 1"
		bind $top.buts.b1 <Return> "set ::gorilla::guimutex 1"
		bind $top.buts.b2 <Return> "set ::gorilla::guimutex 2"

		if {$confirm} {
			bind $top.confirm.e <Return> "set ::gorilla::guimutex 1"
		}

		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW gorilla::DestroyGetPasswordDialog
	} else {
		wm deiconify $top
	}

	wm title $top $title
	# $top.password configure -text ""
	set ::gorilla::passwordDialog.pw ""

	if {$confirm} {
		# $top.confirm configure -text ""
		set ::gorilla::passwordDialog.c ""
	}

	#
	# Run dialog
	#

	set oldGrab [grab current .]

	update idletasks
	raise $top
	focus $top.password.e
	catch {grab $top}

	while {42} {
		ArrangeIdleTimeout
		set ::gorilla::guimutex 0
		vwait ::gorilla::guimutex

		if {$::gorilla::guimutex != 1} {
			break
		}

		set password [$top.password.e get]

		if {$confirm} {
			set confirmed [$top.confirm.e get]

			if {![string equal $password $confirmed]} {
				tk_messageBox -parent $top \
					-type ok -icon error -default ok \
					-title [ mc "Passwords Do Not Match" ] \
					-message [ mc "The confirmed password does not match." ]
			} else {
				break
			}
		} else {
			break
		}
	}

	set ::gorilla::passwordDialog.pw ""

	if {$oldGrab != ""} {
		catch {grab $oldGrab}
	} else {
		catch {grab release $top}
	}

	wm withdraw $top

	if {$::gorilla::guimutex != 1} {
		error "canceled"
	}

	return $password
}

# ----------------------------------------------------------------------
# Default Password Policy
# ----------------------------------------------------------------------
#

proc gorilla::GetDefaultPasswordPolicy {} {
	array set defaults [list \
		length [$::gorilla::db getPreference "PWLenDefault"] \
		uselowercase [$::gorilla::db getPreference "PWUseLowercase"] \
		useuppercase [$::gorilla::db getPreference "PWUseUppercase"] \
		usedigits [$::gorilla::db getPreference "PWUseDigits"] \
		usesymbols [$::gorilla::db getPreference "PWUseSymbols"] \
		usehexdigits [$::gorilla::db getPreference "PWUseHexDigits"] \
		easytoread [$::gorilla::db getPreference "PWEasyVision"]]
	return [array get defaults]
}

proc gorilla::SetDefaultPasswordPolicy {settings} {
	array set defaults $settings
	if {[info exists defaults(length)]} {
		$::gorilla::db setPreference "PWLenDefault" $defaults(length)
	}
	if {[info exists defaults(uselowercase)]} {
		$::gorilla::db setPreference "PWUseLowercase" $defaults(uselowercase)
	}
	if {[info exists defaults(useuppercase)]} {
		$::gorilla::db setPreference "PWUseUppercase" $defaults(useuppercase)
	}
	if {[info exists defaults(usedigits)]} {
		$::gorilla::db setPreference "PWUseDigits" $defaults(usedigits)
	}
	if {[info exists defaults(usesymbols)]} {
		$::gorilla::db setPreference "PWUseSymbols" $defaults(usesymbols)
	}
	if {[info exists defaults(usehexdigits)]} {
		$::gorilla::db setPreference "PWUseHexDigits" $defaults(usehexdigits)
	}
	if {[info exists defaults(easytoread)]} {
		$::gorilla::db setPreference "PWEasyVision" $defaults(easytoread)
	}
}

# ----------------------------------------------------------------------
# Set the Password Policy
# ----------------------------------------------------------------------
#

proc gorilla::PasswordPolicy {} {
	ArrangeIdleTimeout

	if {![info exists ::gorilla::db]} {
		tk_messageBox -parent . \
			-type ok -icon error -default ok \
			-title [mc "No Database"] \
			-message [mc "Please create a new database, or open an existing\
			database first."]
		return
	}

	set oldSettings [GetDefaultPasswordPolicy]
	set newSettings [PasswordPolicyDialog [mc "Password Policy"] $oldSettings]

	if {[llength $newSettings]} {
		SetDefaultPasswordPolicy $newSettings
		set ::gorilla::status [mc "Password policy changed."]
		MarkDatabaseAsDirty
	}
}

#
# ----------------------------------------------------------------------
# Dialog box for password policy
# ----------------------------------------------------------------------
#

proc gorilla::DestroyPasswordPolicyDialog {} {
	set ::gorilla::guimutex 2
}

proc gorilla::PasswordPolicyDialog {title settings} {
	ArrangeIdleTimeout

	array set ::gorilla::ppd [list \
		length 8 \
		uselowercase 1 \
		useuppercase 1 \
		usedigits 1 \
		usehexdigits 0 \
		usesymbols 0 \
		easytoread 1]
	array set ::gorilla::ppd $settings

		set top .passPolicyDialog

		if {![info exists ::gorilla::toplevel($top)]} {
	toplevel $top -class "Gorilla"
	TryResizeFromPreference $top

	ttk::frame $top.plen -padding [list 0 10 0 0 ]
	ttk::label $top.plen.l -text [mc "Password Length"]
	spinbox $top.plen.s -from 1 -to 999 -increment 1 \
		-width 4 -justify right \
		-textvariable ::gorilla::ppd(length)
	pack $top.plen.l -side left
	pack $top.plen.s -side left -padx 10
	pack $top.plen -side top -anchor w -padx 10 -pady 3

	ttk::checkbutton $top.lower -text [mc "Use lowercase letters"] \
		-variable ::gorilla::ppd(uselowercase)
	ttk::checkbutton $top.upper -text [mc "Use UPPERCASE letters"] \
		-variable ::gorilla::ppd(useuppercase)
	ttk::checkbutton $top.digits -text [mc "Use digits"] \
		-variable ::gorilla::ppd(usedigits)
	ttk::checkbutton $top.hex -text [mc "Use hexadecimal digits"] \
		-variable ::gorilla::ppd(usehexdigits)
	ttk::checkbutton $top.symbols -text [mc "Use symbols (%, \$, @, #, etc.)"] \
		-variable ::gorilla::ppd(usesymbols)
	ttk::checkbutton $top.easy \
		-text [mc "Use easy to read characters only (e.g. no \"0\" or \"O\")"] \
		-variable ::gorilla::ppd(easytoread)
	pack $top.lower $top.upper $top.digits $top.hex $top.symbols \
		$top.easy -anchor w -side top -padx 10 -pady 3

	ttk::separator $top.sep -orient horizontal
	pack $top.sep -side top -fill x -pady 10

	frame $top.buts
	set but1 [ttk::button $top.buts.b1 -width 15 -text "OK" \
		-command "set ::gorilla::guimutex 1"]
	set but2 [ttk::button $top.buts.b2 -width 15 -text [mc "Cancel"] \
		-command "set ::gorilla::guimutex 2"]
	pack $but1 $but2 -side left -pady 10 -padx 20
	pack $top.buts -padx 10

	bind $top.lower <Return> "set ::gorilla::guimutex 1"
	bind $top.upper <Return> "set ::gorilla::guimutex 1"
	bind $top.digits <Return> "set ::gorilla::guimutex 1"
	bind $top.hex <Return> "set ::gorilla::guimutex 1"
	bind $top.symbols <Return> "set ::gorilla::guimutex 1"
	bind $top.easy <Return> "set ::gorilla::guimutex 1"
	bind $top.buts.b1 <Return> "set ::gorilla::guimutex 1"
	bind $top.buts.b2 <Return> "set ::gorilla::guimutex 2"

	set ::gorilla::toplevel($top) $top
	wm protocol $top WM_DELETE_WINDOW gorilla::DestroyPasswordPolicyDialog
		} else {
	wm deiconify $top
		}

	set top .passPolicyDialog

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top
		TryResizeFromPreference $top

		ttk::frame $top.plen -padding [list 0 10 0 0 ]
		ttk::label $top.plen.l -text [mc "Password Length"]
		spinbox $top.plen.s -from 1 -to 999 -increment 1 \
			-width 4 -justify right \
			-textvariable ::gorilla::ppd(length)
		pack $top.plen.l -side left
		pack $top.plen.s -side left -padx 10
		pack $top.plen -side top -anchor w -padx 10 -pady 3

		ttk::checkbutton $top.lower -text [mc "Use lowercase letters"] \
			-variable ::gorilla::ppd(uselowercase)
		ttk::checkbutton $top.upper -text [mc "Use UPPERCASE letters"] \
			-variable ::gorilla::ppd(useuppercase)
		ttk::checkbutton $top.digits -text [mc "Use digits"] \
			-variable ::gorilla::ppd(usedigits)
		ttk::checkbutton $top.hex -text [mc "Use hexadecimal digits"] \
			-variable ::gorilla::ppd(usehexdigits)
		ttk::checkbutton $top.symbols -text [mc "Use symbols (%, \$, @, #, etc.)"] \
			-variable ::gorilla::ppd(usesymbols)
		ttk::checkbutton $top.easy \
			-text [mc "Use easy to read characters only (e.g. no \"0\" or \"O\")"] \
			-variable ::gorilla::ppd(easytoread)
		pack $top.lower $top.upper $top.digits $top.hex $top.symbols \
			$top.easy -anchor w -side top -padx 10 -pady 3

		ttk::separator $top.sep -orient horizontal
		pack $top.sep -side top -fill x -pady 10

		frame $top.buts
		set but1 [ttk::button $top.buts.b1 -width 15 -text [ mc "OK" ] \
			-command "set ::gorilla::guimutex 1"]
		set but2 [ttk::button $top.buts.b2 -width 15 -text [mc "Cancel"] \
			-command "set ::gorilla::guimutex 2"]
		pack $but1 $but2 -side left -pady 10 -padx 20
		pack $top.buts -padx 10

		bind $top.lower <Return> "set ::gorilla::guimutex 1"
		bind $top.upper <Return> "set ::gorilla::guimutex 1"
		bind $top.digits <Return> "set ::gorilla::guimutex 1"
		bind $top.hex <Return> "set ::gorilla::guimutex 1"
		bind $top.symbols <Return> "set ::gorilla::guimutex 1"
		bind $top.easy <Return> "set ::gorilla::guimutex 1"
		bind $top.buts.b1 <Return> "set ::gorilla::guimutex 1"
		bind $top.buts.b2 <Return> "set ::gorilla::guimutex 2"

		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW gorilla::DestroyPasswordPolicyDialog
	} else {
		wm deiconify $top
	}

	set oldGrab [grab current .]

	update idletasks
	wm title $top $title
	raise $top
	focus $top.plen.s
	catch {grab $top}

	set ::gorilla::guimutex 0
	vwait ::gorilla::guimutex

	if {$oldGrab != ""} {
		catch {grab $oldGrab}
	} else {
		catch {grab release $top}
	}

	wm withdraw $top

	if {$::gorilla::guimutex != 1} {
		return [list]
	}

	return [array get ::gorilla::ppd]
}

#
# ----------------------------------------------------------------------
# Generate a password
# ----------------------------------------------------------------------
#

proc gorilla::GeneratePassword {settings} {
	set easyLowercaseLetters "abcdefghkmnpqrstuvwxyz"
	set notEasyLowercaseLetters "ijlo"
	set easyUppercaseLetters [string toupper $easyLowercaseLetters]
	set notEasyUppercaseLetters [string toupper $notEasyLowercaseLetters]
	set easyDigits "23456789"
	set notEasyDigits "01"
	set easySymbols "+-=_@#\$%^&<>/~\\?"
	set notEasySymbols "!|()"

	array set params [list \
		length 0 \
		uselowercase 0 \
		useuppercase 0 \
		usedigits 0 \
		usehexdigits 0 \
		usesymbols 0 \
		easytoread 0]
	array set params $settings

	set symbolSet ""

	if {$params(uselowercase)} {
		append symbolSet $easyLowercaseLetters
		if {!$params(easytoread)} {
			append symbolSet $notEasyLowercaseLetters
		}
	}

	if {$params(useuppercase)} {
		append symbolSet $easyUppercaseLetters
		if {!$params(easytoread)} {
			append symbolSet $notEasyUppercaseLetters
		}
	}

	if {$params(usehexdigits)} {
		if {!$params(uselowercase)} {
			append symbolSet "0123456789abcdef"
		} else {
			append symbolSet "0123456789"
		}
	} elseif {$params(usedigits)} {
		append symbolSet $easyDigits
		if {!$params(easytoread)} {
			append symbolSet $notEasyDigits
		}
	}

	if {$params(usesymbols)} {
		append symbolSet $easySymbols
		if {!$params(easytoread)} {
			append symbolSet $notEasySymbols
		}
	}
 
	set numSymbols [string length $symbolSet]

	if {$numSymbols == 0} {
		error "invalid settings"
	}

	set generatedPassword ""
	for {set i 0} {$i < $params(length)} {incr i} {
		set rand [::isaac::rand]
		set randSymbol [expr {int($rand*$numSymbols)}]
		append generatedPassword [string index $symbolSet $randSymbol]
	}

	return $generatedPassword
}

# ----------------------------------------------------------------------
# Dialog box for database-specific preferences
# ----------------------------------------------------------------------
#

proc gorilla::DestroyDatabasePreferencesDialog {} {
	set ::gorilla::guimutex 2
}

proc gorilla::DatabasePreferencesDialog {} {

	ArrangeIdleTimeout

	set top .dbPrefsDialog

	if {![info exists ::gorilla::db]} {
		return
	}

	foreach pref {IdleTimeout IsUTF8 LockOnIdleTimeout SaveImmediately} {
		set ::gorilla::dpd($pref) [$::gorilla::db getPreference $pref]
	}

	if {!$::gorilla::dpd(LockOnIdleTimeout)} {
		set ::gorilla::dpd(IdleTimeout) 0
	}

	if {[$::gorilla::db hasHeaderField 0]} {
		set oldVersion [lindex [$::gorilla::db getHeaderField 0] 0]
	} else {
		set oldVersion 2
	}

	set ::gorilla::dpd(defaultVersion) $oldVersion

	set ::gorilla::dpd(keyStretchingIterations) \
		[$::gorilla::db cget -keyStretchingIterations]
	set oldKeyStretchingIterations $::gorilla::dpd(keyStretchingIterations)

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top -class "Gorilla"
		wm title $top [mc "Database Preferences"]
		TryResizeFromPreference $top

		ttk::frame $top.il -padding [list 10 15 10 5]
		ttk::label $top.il.l1 -text [mc "Lock when idle after"]
		spinbox $top.il.s -from 0 -to 999 -increment 1 \
				-justify right -width 4 \
				-textvariable ::gorilla::dpd(IdleTimeout)
		ttk::label $top.il.l2 -text [mc "minutes (0=never)"]
		pack $top.il.l1 $top.il.s $top.il.l2 -side left -padx 3
		pack $top.il -side top -anchor w

		ttk::checkbutton $top.si -text [mc "Auto-save database immediately when changed"] \
			-variable ::gorilla::dpd(SaveImmediately)
		pack $top.si -anchor w -side top -pady 3 -padx 10

		ttk::checkbutton $top.ver -text [mc "Use Password Safe 3 format"] \
			-variable ::gorilla::dpd(defaultVersion) \
			-onvalue 3 -offvalue 2
		pack $top.ver -anchor w -side top -pady 3 -padx 10

		ttk::checkbutton $top.uni -text [mc "V2 Unicode support"] \
			-variable ::gorilla::dpd(IsUTF8)
		pack $top.uni -anchor w -side top -pady 3 -padx 10

		# === keystretch spinbox

		ttk::frame $top.stretch -padding [list 10 5]
		spinbox $top.stretch.spin -from 2048 -to 2147483647 -increment 256 \
			-justify right -width 12 \
			-textvariable ::gorilla::dpd(keyStretchingIterations)
		ttk::label $top.stretch.label -text [mc "V3 key stretching iterations"]
		pack $top.stretch.spin $top.stretch.label -side left -padx 3
		pack $top.stretch -anchor w -side top

		# === keystretch delay timer

		set delayf [ ttk::labelframe $top.delay -padding {10 5} -text [ mc "Calculate delay time" ] ]
		pack $delayf -anchor w -side top -fill x -expand true -padx {10 10} -pady {0 2m}
		
		ttk::label  $delayf.feedback -text [ mc "Default: %s" $::gorilla::dpd(keyStretchingIterations) ]
		ttk::button $delayf.compute  -text [ mc "Calculate" ] -command [ namespace code [ subst {
		  $delayf.compute configure -text "[ mc "Calculating" ]"
		  update idletasks
		  $delayf.feedback configure -text \[ mc "%s sec(s) for %d iterations" \
                                   \[ expr { \[ pwsafe::int::keyStretchMsDelay \[ $top.stretch.spin get ] ] / 1000.0 } ] \
                                   \[ $top.stretch.spin get ] ]
		  $delayf.compute configure -text [ mc "Calculate" ]
		  } ] ]
		grid $delayf.feedback $delayf.compute -sticky news -padx {1m 1m} -pady {1m 1m}
		
		# === auto iter computation

		set aiterf [ ttk::labelframe $top.autoiter -padding {10 5} -text [ mc "Calculate iterations" ] ]
		pack $aiterf -anchor w -side top -fill x -expand true -padx {10 10}

		ttk::label $aiterf.label1 -text [ mc "Delay for" ]
		spinbox $aiterf.spin -from 1 -to 600 -increment 1 -justify right -width 5 
		ttk::label $aiterf.spinlabel2 -text [ mc "sec(s)" ]
		ttk::button $aiterf.calculate -text [ mc "Calculate" ] \
		  -command [ namespace code [ subst { 
		    $aiterf.calculate configure -text "[ mc "Calculating" ]"
		    update idletasks
		    $top.stretch.spin set \[ pwsafe::int::calculateKeyStrechForDelay \[ $aiterf.spin get ] ]
		    $aiterf.calculate configure -text [ mc "Calculate" ]
		  } ] ]
		grid $aiterf.label1 $aiterf.spin $aiterf.spinlabel2 $aiterf.calculate -padx {1m 1m} -pady {1m 1m}

		# ===

		ttk::separator $top.sep -orient horizontal
		pack $top.sep -side top -fill x -pady 10

		ttk::frame $top.buts
		set but1 [ttk::button $top.buts.b1 -width 15 -text [ mc "OK" ] \
			-command "set ::gorilla::guimutex 1"]
		set but2 [ttk::button $top.buts.b2 -width 15 -text [mc "Cancel"] \
			-command "set ::gorilla::guimutex 2"]
		pack $but1 $but2 -side left -padx 20
		pack $top.buts -side top -pady 10

		bind $top.uni <Return> "set ::gorilla::guimutex 1"
		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW gorilla::DestroyDatabasePreferencesDialog
	} else {
		wm deiconify $top
	}

	set oldGrab [grab current .]

	update idletasks
	raise $top
	focus $top.buts.b1
	catch {grab $top}

	set ::gorilla::guimutex 0
	vwait ::gorilla::guimutex

	if {$oldGrab != ""} {
		catch {grab $oldGrab}
	} else {
		catch {grab release $top}
	}

	wm withdraw $top

	if {$::gorilla::guimutex != 1} {
		return
	}

	set isModified 0

	if {$::gorilla::dpd(IdleTimeout) > 0} {
		set ::gorilla::dpd(LockOnIdleTimeout) 1
	} else {
		set ::gorilla::dpd(LockOnIdleTimeout) 0
	}

	foreach pref {IdleTimeout IsUTF8 LockOnIdleTimeout SaveImmediately} {
		set oldPref [$::gorilla::db getPreference $pref]
		if {![string equal $::gorilla::dpd($pref) $oldPref]} {
			set isModified 1
			$::gorilla::db setPreference $pref $::gorilla::dpd($pref)
		}
	}

	set newVersion $::gorilla::dpd(defaultVersion)

	if {$newVersion != $oldVersion} {
		$::gorilla::db setHeaderField 0 [list $newVersion 0]
		set isModified 1
	}

	$::gorilla::db configure -keyStretchingIterations \
		$::gorilla::dpd(keyStretchingIterations)

	if {$::gorilla::dpd(keyStretchingIterations) != $oldKeyStretchingIterations} {
		set isModified 1
	}

	if {$isModified} {
		MarkDatabaseAsDirty
	}

	ArrangeIdleTimeout

} ; # end proc gorilla::DatabasePreferencesDialog

# ----------------------------------------------------------------------
# Preferences Dialog
# ----------------------------------------------------------------------
#

proc gorilla::DestroyPreferencesDialog {} {
	set ::gorilla::guimutex 2
}

proc gorilla::PreferencesDialog {} {
	ArrangeIdleTimeout

	set top .preferencesDialog

	# copy current preferences settings to a temp variable to handle
	# "canceling" of preference changes
	
	dict for {pref value} $::gorilla::preference(all-preferences) {
		set ::gorilla::prefTemp($pref) $::gorilla::preference($pref)
	}

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top -class "Gorilla"
		# TryResizeFromPreference $top
		wm title $top [mc "Preferences"]

		ttk::notebook $top.nb

		#
		# First NoteBook tab: (g)eneral (p)re(f)erences
		#

		set gpf $top.nb.gpf

		$top.nb add [ttk::frame $gpf] -text [mc "General"]

		ttk::labelframe $gpf.dca -text [mc "When double clicking a login ..."] \
			-padding [list 5 5]
		ttk::radiobutton $gpf.dca.cp -text [mc "Copy password to clipboard"] \
			-variable ::gorilla::prefTemp(doubleClickAction) \
			-value "copyPassword" 
		ttk::radiobutton $gpf.dca.ed -text [mc "Edit Login"] \
			-variable ::gorilla::prefTemp(doubleClickAction) \
			-value "editLogin"
		ttk::radiobutton $gpf.dca.lb -text [mc "Launch Browser directed to URL"] \
			-variable ::gorilla::prefTemp(doubleClickAction) \
			-value "launchBrowser"
		ttk::radiobutton $gpf.dca.nop -text [mc "Do nothing"] \
			-variable ::gorilla::prefTemp(doubleClickAction) \
			-value "nothing"
		pack $gpf.dca.cp $gpf.dca.ed $gpf.dca.lb $gpf.dca.nop -side top -anchor w -pady 3
		pack $gpf.dca -side top -padx 10 -pady 5 -fill x -expand yes

		ttk::frame $gpf.cc -padding [list 8 5]
		ttk::label $gpf.cc.l1 -text [mc "Clear clipboard after"]
		spinbox $gpf.cc.s -from 0 -to 999 -increment 1 \
			-justify right -width 4 \
			-textvariable ::gorilla::prefTemp(clearClipboardAfter)
		ttk::label $gpf.cc.l2 -text [mc "seconds (0=never)"]
		pack $gpf.cc.l1 $gpf.cc.s $gpf.cc.l2 -side left -padx 3
		pack $gpf.cc -side top -anchor w

		ttk::frame $gpf.lru -padding [list 8 5]
		ttk::label $gpf.lru.l1 -text [mc "Remember"]
		spinbox $gpf.lru.s -from 0 -to 32 -increment 1 \
			-justify right -width 4 \
			-textvariable ::gorilla::prefTemp(lruSize)
		ttk::label $gpf.lru.l2 -text [mc "database names"]
		ttk::button $gpf.lru.c -width 10 -text [mc "Clear"] \
			-command "set ::gorilla::guimutex 3"
		pack $gpf.lru.l1 $gpf.lru.s $gpf.lru.l2 -side left -padx 3
		pack $gpf.lru.c -side right
		pack $gpf.lru -side top -anchor w -pady 3 -fill x

		ttk::checkbutton $gpf.bu -text [mc "Backup database on save"] \
			-variable ::gorilla::prefTemp(keepBackupFile)
		ttk::checkbutton $gpf.geo -text [mc "Remember sizes of dialog boxes"] \
			-variable ::gorilla::prefTemp(rememberGeometries)
		ttk::checkbutton $gpf.gac -text [ mc "Use Gorilla auto-copy" ] \
			-variable ::gorilla::prefTemp(gorillaAutocopy)
		if { $::tcl_platform(platform) eq "x11" } {
			::tooltip::tooltip $gpf.gac [ mc "Automatically copy password associated\nwith login to clipboard after pasting\nof user-name." ]
		} else {
			::tooltip::tooltip $gpf.gac [ mc "This option does not function on\nWindows(TM) or MacOS(TM) platforms.\nSee the help system for details." ]
		}
		pack $gpf.bu $gpf.geo $gpf.gac -side top -anchor w -padx 10 -pady 5



		#
		# Second NoteBook tab: (d)efault (p)re(f)erences
		#

		set dpf $top.nb.dpf
		$top.nb add [ttk::frame $dpf] -text [mc "Defaults"]

		ttk::frame $dpf.il -padding [list 10 10]
		ttk::label $dpf.il.l1 -text [mc "Lock when idle after"]
		spinbox $dpf.il.s -from 0 -to 999 -increment 1 \
			-justify right -width 4 \
			-textvariable ::gorilla::prefTemp(idleTimeoutDefault)
		ttk::label $dpf.il.l2 -text [mc "minutes (0=never)"]
		pack $dpf.il.l1 $dpf.il.s $dpf.il.l2 -side left -padx 3
		pack $dpf.il -side top -anchor w -pady 3

		ttk::checkbutton $dpf.si -text [mc "Auto-save database immediately when changed"] \
			-variable ::gorilla::prefTemp(saveImmediatelyDefault)
		ttk::checkbutton $dpf.ver -text [mc "Use Password Safe 3 format"] \
			-variable ::gorilla::prefTemp(defaultVersion) \
			-onvalue 3 -offvalue 2
		ttk::checkbutton $dpf.uni -text [mc "V2 Unicode support"] \
			-variable ::gorilla::prefTemp(unicodeSupport)
		ttk::checkbutton $dpf.ts -text [mc "Time stamp backup"] \
			-variable ::gorilla::prefTemp(timeStampBackup)

		ttk::frame $dpf.bakpath
# puts $::gorilla::prefTemp(backupPath)
		ttk::entry $dpf.bakpath.e -textvariable ::gorilla::prefTemp(backupPath)
		ttk::label $dpf.bakpath.l -text [mc "Backup path:"]
		ttk::button $dpf.bakpath.b -image $::gorilla::images(browse) \
			-command { eval set ::gorilla::prefTemp(backupPath) \
				[tk_chooseDirectory -initialdir $::gorilla::prefTemp(backupPath) \
				-title [mc "Choose a directory"] ] }
		pack $dpf.bakpath.l -side left
		pack $dpf.bakpath.e -side left -padx 3 -expand 1 -fill x
		pack $dpf.bakpath.b -side left -padx 3

		pack $dpf.si $dpf.ver $dpf.uni $dpf.ts $dpf.bakpath -side top -anchor w -pady 3 -padx 10 -fill x

		ttk::label $dpf.note -justify center -anchor w -wraplen 300 \
			-text [mc "Note: these defaults will be applied to new databases. To change a setting for an existing database, go to \"Customize\" in the \"Security\" menu."]
		pack $dpf.note -side bottom -anchor center -pady 3

		#
		# Third NoteBook tab: export preferences
		#

		set epf $top.nb.epf
		$top.nb add [ttk::frame $epf -padding [list 10 10]] -text [mc "Export"]

		ttk::checkbutton $epf.password -text [mc "Include password field"] \
			-variable ::gorilla::prefTemp(exportIncludePassword)
		ttk::checkbutton $epf.notes -text [mc "Include \"Notes\" field"] \
			-variable ::gorilla::prefTemp(exportIncludeNotes) 

		ttk::frame $epf.fs
		ttk::label $epf.fs.l -text [mc "Field separator"] -width 20 -anchor w
		spinbox $epf.fs.e \
			-values [list , \; :] \
			-textvariable ::gorilla::prefTemp(exportFieldSeparator) \
			-width 2 \
			-state readonly \
			-relief sunken
			
		pack $epf.fs.l $epf.fs.e -side left
		ttk::checkbutton $epf.warning -text [mc "Show security warning"] \
			-variable ::gorilla::prefTemp(exportShowWarning) 
				
		pack $epf.password $epf.notes $epf.warning $epf.fs \
			-anchor w -side top -pady 3

		#
		# Fourth NoteBook tab: Display
		#
		
		set languages [gorilla::getAvailableLanguages]
    
		# format: {en English de Deutsch ...}
		# Fehlerabfrage für falschen prefTemp(lang) Eintrag in der gorillarc
		if {[lsearch $languages $::gorilla::prefTemp(lang)] == -1} {
			set ::gorilla::prefTemp(lang) en
		}
		set ::gorilla::fullLangName [dict get $languages $::gorilla::prefTemp(lang)]

		set display $top.nb.display
		$top.nb add [ttk::frame $display -padding [list 10 10]] -text [mc "Display"]
		
		ttk::frame $display.lang -padding {10 10}
		ttk::label $display.lang.label -text [mc "Language:"] -width 9
		ttk::menubutton $display.lang.mb -textvariable ::gorilla::fullLangName \
			-width 8 -direction right
		set m [menu $display.lang.mb.menu -tearoff 0]
		$display.lang.mb configure -menu $m

		foreach {lang name} $languages {
			$m add radio -label $name -variable ::gorilla::prefTemp(lang) -value $lang \
				-command "set ::gorilla::fullLangName $name"
		}

		pack $display.lang.label $display.lang.mb -side left
		pack $display.lang -anchor w
		
		# font options
		
		ttk::frame $display.size -padding {10 10}
		ttk::label $display.size.label -text "[mc "Size"]:" -width 9
		ttk::menubutton $display.size.mb -textvariable ::gorilla::prefTemp(fontsize) \
			-width 8 -direction right
		set m [menu $display.size.mb.menu -tearoff 0]
		$display.size.mb configure -menu $m
		
		set sizes "8 9 10 11 12 14 16"
		foreach {size} $sizes {
			$m add radio -label $size -variable ::gorilla::prefTemp(fontsize) -value $size \
				-command [ list ::apply { {size} {
					font configure TkDefaultFont -size $size
					font configure TkTextFont    -size $size
					font configure TkMenuFont    -size $size
					font configure TkCaptionFont -size $size
					font configure TkFixedFont   -size $size
					# note - this has an explicit dependency upon Treeview using TkDefaultFont for display
					ttk::style configure gorilla.Treeview -rowheight [ expr { 2 + [ font metrics TkDefaultFont -linespace ] } ]
					} } $size ]
		}
		
		pack $display.size.label $display.size.mb -side left
		pack $display.size -anchor w
		
		# gorilla icon in OpenDatabase
		
		ttk::checkbutton $display.icon \
			-variable ::gorilla::prefTemp(gorillaIcon) \
			-text [mc "Show Gorilla Icon"]
		pack $display.icon -anchor w

		# auto iconify upon lock
		
		ttk::checkbutton $display.autoiconify \
			-variable ::gorilla::prefTemp(iconifyOnAutolock) \
			-text [mc "Iconify upon auto-lock"]
		pack $display.autoiconify -anchor w -pady 5

		# hide logins in main window
		
		ttk::checkbutton $display.hideLogins \
			-variable ::gorilla::prefTemp(hideLogins) \
			-text [mc "Hide login name in tree view" ]
		pack $display.hideLogins -anchor w -pady 5
		::tooltip::tooltip $display.hideLogins [ mc "This option takes effect after exiting\nand restarting of Password Gorilla" ]

		#
		# Fifth NoteBook tab: Browser
		#

		$top.nb add [ set browser [ ttk::frame $top.nb.browser -padding [ list 10 0 ] ] ] -text [ mc "Browser" ]
		ttk::label $browser.lexe -text [ mc "Browser executable to launch (required):" ]
		ttk::entry $browser.exe -textvariable ::gorilla::prefTemp(browser-exe)
		ttk::label $browser.lparam -text [ mc "Command line parameter (if any) to pass (optional):" ]
		ttk::entry $browser.param -textvariable ::gorilla::prefTemp(browser-param)
		ttk::button $browser.findgui -text [ mc "Find Browser" ] -command "set ::gorilla::prefTemp(browser-exe) \[ tk_getOpenFile -parent $browser \]"
		ttk::style configure biwrap.TLabel -wraplength 75
		ttk::label $browser.inst  -style biwrap.TLabel -text [ mc "If a command line parameter is provided, it must contain the character sequence: %url%. This sequence will be replaced with the actual URL during launch. See the help system for details." ]
		bind $browser.inst <Configure> "ttk::style configure biwrap.TLabel -wraplength \[ winfo width $browser.inst \]"
		ttk::checkbutton $browser.autocopyuserid \
			-variable ::gorilla::prefTemp(autocopyUserid) \
			-text [ mc "Also copy username to clipboard" ]
		::tooltip::tooltip $browser.autocopyuserid [ mc "When selected the username\nfrom the login entry will also\nbe copied to the clipboard\nwhen opening a browser." ]

		# note - switch to ttk::spinbox when upgrading to tcl/tk 8.5.9 or better
		set subframe [ ttk::frame $browser.acmf ]
		::tooltip::tooltip $subframe [ mc "Determines how Password\nGorilla handles clearing the\nclipboard.\n\nRange zero to twenty.\n\nSee Help for details." ]
		spinbox $subframe.spin -from 0 -to 20 -increment 1 -width 3 \
			-command { set ::gorilla::prefTemp(autoclearMultiplier) %s } \
			-validatecommand { ::gorilla::PreferencesSpinBoxValidate %P } \
			-validate all
		$subframe.spin set $::gorilla::prefTemp(autoclearMultiplier)
		ttk::label $subframe.spinlbl -text [mc "Clipboard autoclear multiplier"]
		pack $subframe.spin $subframe.spinlbl -side left -padx {0 2m}

		grid $browser.lexe    -sticky nw  -pady { 5m 0 }
		grid $browser.exe     -sticky new 
		grid $browser.findgui -sticky ne  -pady { 1m 5m }
		grid $browser.lparam  -sticky nw
		grid $browser.param   -sticky new 
		grid $browser.inst    -sticky new -pady { 2m 0 }
		grid $browser.autocopyuserid -sticky new -pady {2m 0}
		grid $subframe        -sticky new -pady { 2m 2m }

		#
		# End of NoteBook tabs
		#

		# $top.nb compute_size
		# $top.nb raise gpf
		pack $top.nb -side top -fill both -expand yes -ipady 10

		#
		# Bottom
		#

		# Separator $top.sep -orient horizontal
		# pack $top.sep -side top -fill x -pady 7

		ttk::frame $top.buts
		set but1 [ttk::button $top.buts.b1 -width 15 -text [ mc "OK" ] \
			-command "set ::gorilla::guimutex 1"]
		set but2 [ttk::button $top.buts.b2 -width 15 -text [mc "Cancel"] \
			-command "set ::gorilla::guimutex 2"]
		pack $but1 $but2 -side left -pady 10 -padx 20
		pack $top.buts -side top -ipady 10 -fill both

		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW gorilla::DestroyPreferencesDialog
	} else {
		wm deiconify $top
	}

	set oldGrab [grab current .]

	update idletasks
	raise $top
	focus $top.buts.b1
	catch {grab $top}

	while {42} {
		ArrangeIdleTimeout
		set ::gorilla::guimutex 0
		vwait ::gorilla::guimutex

		if {$::gorilla::guimutex == 1} {
			break
		} elseif {$::gorilla::guimutex == 2} {
			break
		} elseif {$::gorilla::guimutex == 3} {
			set ::gorilla::preference(lru) [list]
			set ::gorilla::status [mc "History deleted. After a restart the list will be empty."]
		}
	}

	if {$oldGrab != ""} {
		catch {grab $oldGrab}
	} else {
		catch {grab release $top}
	}

	wm withdraw $top

	if {$gorilla::guimutex != 1} {
		return
	}

	# copy the temporary preferences back into the global preferences
	# array
	dict for {pref value} $::gorilla::preference(all-preferences) {
		set ::gorilla::preference($pref) $::gorilla::prefTemp($pref)
	}

}

proc gorilla::Preferences {} {
	gorilla::PreferencesDialog
}

proc gorilla::PreferencesSpinBoxValidate { value } {
	if { ( ! [ string is integer -strict $value ] ) || ( ( $value < 0 ) || ( 20 < $value ) ) } { 
		return 0
	} else { 
		return 1
	} 
} ; # end proc gorilla::PreferencesSpinBoxValidate


# ----------------------------------------------------------------------
# Save Preferences
# ----------------------------------------------------------------------
#

# Results:
# 	returns 1 if platform is Windows and registry save was successful
#		returns 0 if platform is Mac or Linux doing nothing 
proc gorilla::SavePreferencesToRegistry {} {
	if {![info exists ::tcl_platform(platform)] || \
		$::tcl_platform(platform) != "windows" || \
		[catch {package require registry}]} {
		return 0
	}

	set key {HKEY_CURRENT_USER\Software\FPX\Password Gorilla}

	if {![regexp {Revision: ([0-9.]+)} $::gorilla::Version dummy revision]} {
		set revision "<unknown>"
	}

	registry set $key revision $revision sz

	#
	# Note: findInText omitted on purpose. It might contain a password.
	#

	foreach {pref type} {caseSensitiveFind dword \
		clearClipboardAfter dword \
		defaultVersion dword \
		doubleClickAction sz \
		exportFieldSeparator sz \
		exportIncludeNotes dword \
		exportIncludePassword dword \
		exportShowWarning dword \
		findInAny dword \
		findInNotes dword \
		findInPassword dword \
		findInTitle dword \
		findInURL dword \
		findInUsername dword \
		idleTimeoutDefault dword \
		keepBackupFile dword \
		lruSize dword \
		rememberGeometries dword \
		saveImmediatelyDefault dword \
		unicodeSupport dword} {
		if {[info exists ::gorilla::preference($pref)]} {
			registry set $key $pref $::gorilla::preference($pref) $type
		}
	}

	if {[info exists ::gorilla::preference(lru)]} {
		if {[info exists ::gorilla::preference(lruSize)]} {
			set lruSize $::gorilla::preference(lruSize)
		} else {
			set lruSize 10
		}

		if {[llength $::gorilla::preference(lru)] > $lruSize} {
			set lru [lrange $::gorilla::preference(lru) 0 [expr {$lruSize-1}]]
		} else {
			set lru $::gorilla::preference(lru)
		}

		registry set $key lru $lru multi_sz
	}

	if {![info exists ::gorilla::preference(rememberGeometries)] || \
		$::gorilla::preference(rememberGeometries)} {
		foreach top [array names ::gorilla::toplevel] {
			if {[scan [wm geometry $top] "%dx%d" width height] == 2} {
				registry set $key "geometry,$top" "${width}x${height}"
			}
		}
	} elseif {[info exists ::gorilla::preference(rememberGeometries)] && \
			!$::gorilla::preference(rememberGeometries)} {
		foreach value [registry values $key geometry,*] {
			registry delete $key $value
		}
	}

	return 1
}

proc gorilla::SavePreferencesToRCFile {} {
	if {[info exists ::gorilla::preference(rc)]} {
		set fileName $::gorilla::preference(rc)
	} else {
		if {[info exists ::env(HOME)] && [file isdirectory $::env(HOME)]} {
			set homeDir $::env(HOME)
		} else {
			set homeDir "~"
		}

		#
		# On the Mac, use $HOME/Library/Preferences/gorilla.rc
		# Elsewhere, use $HOME/.gorillarc
		#

		if {[tk windowingsystem] == "aqua" && \
		[file isdirectory [file join $homeDir "Library" "Preferences"]]} {
			set fileName [file join $homeDir "Library" "Preferences" "gorilla.rc"]
		} else {
			set fileName [file join $homeDir ".gorillarc"]
		}
	}

	if { [catch {set f [open $fileName "w"]}] } {
		return 0
	}

	if {![regexp {Revision: ([0-9.]+)} $::gorilla::Version dummy revision]} {
		set revision "<unknown>"
	}

	puts $f "revision=$revision"

	#
	# Note: findThisText omitted on purpose. It might contain a password.
	#

	dict for {pref value} $::gorilla::preference(all-preferences) {
		# lru and exportFieldSeparator are handled specially below
		if { $pref ni { lru exportFieldSeparator findThisText } } {
			puts $f "$pref=[ quoteBackslashes $::gorilla::preference($pref) ]"
		}
	}

	puts $f "exportFieldSeparator=\"[string map {\t \\t} $::gorilla::preference(exportFieldSeparator)]\""

	set lruSize $::gorilla::preference(lruSize)

	if {[llength $::gorilla::preference(lru)] > $lruSize} {
		set lru [lrange $::gorilla::preference(lru) 0 [expr {$lruSize-1}]]
	} else {
		set lru $::gorilla::preference(lru)
	}

	foreach file $lru {
		puts $f "lru=\"[ quoteBackslashes $file ]\""
	}

	if {$::gorilla::preference(rememberGeometries)} {
		foreach top [array names ::gorilla::toplevel] {
			if {[scan [wm geometry $top] "%dx%d" width height] == 2} {
				puts $f "geometry,$top=${width}x${height}"
			}
		}
	}

	if {[catch {close $f}]} {
		gorilla::ErrorPopup [mc "Error"] [mc "Error while saving RC-File"]
		return 0
	}
	return 1
}

proc gorilla::quoteBackslashes { str } {
  string map {\\ \\\\} $str
}

proc gorilla::SavePreferences {} {
	if {[info exists ::gorilla::preference(norc)] && $::gorilla::preference(norc)} {
		return 0
	}
	SavePreferencesToRCFile
	return 1
}

# ----------------------------------------------------------------------
# Load Preferences
# ----------------------------------------------------------------------
#

proc gorilla::LoadPreferencesFromRegistry {} {
	if {![info exists ::tcl_platform(platform)] || \
		$::tcl_platform(platform) != "windows" || \
		[catch {package require registry}]} {
		return 0
	}

	set key {HKEY_CURRENT_USER\Software\FPX\Password Gorilla}

	if {[catch {registry values $key}]} {
		return 0
	}

	if {![regexp {Revision: ([0-9.]+)} $::gorilla::Version dummy revision]} {
		set revision "<unmatchable>"
	}

	if {[llength [registry values $key revision]] == 1} {
		set prefsRevision [registry get $key revision]
	} else {
		set prefsRevision "<unknown>"
	}

	if {[llength [registry values $key lru]] == 1} {
		set ::gorilla::preference(lru) [registry get $key lru]
	}

	foreach {pref type} {caseSensitiveFind boolean \
		clearClipboardAfter integer \
		defaultVersion integer \
		doubleClickAction ascii \
		exportFieldSeparator ascii \
		exportIncludeNotes boolean \
		exportIncludePassword boolean \
		exportShowWarning boolean \
		findInAny boolean \
		findInNotes boolean \
		findInPassword boolean \
		findInTitle boolean \
		findInURL boolean \
		findInUsername boolean \
		findThisText ascii \
		idleTimeoutDefault integer \
		keepBackupFile boolean \
		lruSize integer \
		rememberGeometries boolean \
		saveImmediatelyDefault boolean \
		unicodeSupport integer} {
		if {[llength [registry values $key $pref]] == 1} {
			set value [registry get $key $pref]
			if {[string is $type $value]} {
				set ::gorilla::preference($pref) $value
			}
		}
	}

	if {[info exists ::gorilla::preference(rememberGeometries)] && \
			$::gorilla::preference(rememberGeometries)} {
		foreach value [registry values $key geometry,*] {
			set data [registry get $key $value]
			if {[scan $data "%dx%d" width height] == 2} {
				set ::gorilla::preference($value) "${width}x${height}"
			}
		}
	}

	#
	# If the revision numbers of our preferences don't match, forget
	# about window geometries, as they might have changed.
	#

	if {![string equal $revision $prefsRevision]} {
		foreach geo [array names ::gorilla::preference geometry,*] {
			unset ::gorilla::preference($geo)
		}
	}

	return 1
}

proc gorilla::LoadPreferencesFromRCFile {} {

   # The (rc) entry in the preferences array is utilized to hold the value
   # from the command line -rc switch

	if { [ info exists ::gorilla::preference(rc) ] } {
		set fileName $::gorilla::preference(rc)
	} else {
		if { [ info exists ::env(HOME) ] && [ file isdirectory $::env(HOME) ] } {
			set homeDir $::env(HOME)
		} else {
			set homeDir "~"
		}

		#
		# On the Mac, use $HOME/Library/Preferences/gorilla.rc
		# Elsewhere, use $HOME/.gorillarc
		#

		if { [tk windowingsystem] == "aqua" && \
			[ file isdirectory [ file join $homeDir "Library" "Preferences" ] ] } {
			set fileName [ file join $homeDir "Library" "Preferences" "gorilla.rc" ]
		} else {
			set fileName [ file join $homeDir ".gorillarc" ]
		}

	} ; # end if info exists ::gorilla::preference(rc)

	if { ! [ regexp {Revision: ([0-9.]+)} $::gorilla::Version -> revision ] } {
		set revision "<unmatchable>"
	}

	set prefsRevision "<unknown>"

	if { [ catch { set f [ open $fileName ] } ] } {
		return 0
	}

	while { ! [ eof $f ] } {
		set line [ string trim [ gets $f ] ]
		if { [ string index $line 0 ] == "#" } {
			continue
		}

		set temp [ split $line = ] 

		if { [ llength $temp ] != 2 } {
			continue
		}
		
		lassign $temp pref value
		
		set pref [ string trim $pref ]
		# the subst is to perform backslash substitutions upon the value of the preference
		set value [ subst -nocommands -novariables [ string trim [ string trim $value "\"" ] ] ]

		switch -glob -- $pref {
			lru {
				if { [ apply [ lindex [ dict get $::gorilla::preference(all-preferences) lru ] 1 ] $value ] } {
					lappend ::gorilla::preference($pref) $value
				}
			}

			revision {
				set prefsRevision $value
			}

			geometry,* {
				if {[scan $value "%dx%d" width height] == 2} {
					set ::gorilla::preference($pref) "${width}x${height}"
				}
			}

			default {
				if { ! [ dict exists $::gorilla::preference(all-preferences) $pref ] } {
					continue
				}
				# apply the validator proc from the preferences definition list to the value
				if { [ apply [ lindex [ dict get $::gorilla::preference(all-preferences) $pref ] 1 ] $value ] } {
					set ::gorilla::preference($pref) $value
				}
				
			}
		} ; # end switch pref

	} ; # end while ! eof f

	# MacOS launches default browser with "open http://url"
	if {[tk windowingsystem] == "aqua" && $::gorilla::preference(browser-exe) eq "" }	{
			set ::gorilla::preference(browser-exe) "open"
	}

	# initialize locale and fonts from the preference values

	mclocale $::gorilla::preference(lang)

	# Load msgcat data into the global namespace so that it is visible
	# from both the ::gorilla and ::pwsafe namespaces.
	namespace eval :: { mcload [file join $::gorilla::Dir msgs] }
	
	set value $::gorilla::preference(fontsize) 
	font configure TkDefaultFont -size $value
	font configure TkTextFont    -size $value
	font configure TkMenuFont    -size $value
	font configure TkCaptionFont -size $value
	font configure TkFixedFont   -size $value
	# undocumented option for ttk::treeview
	# note - this has an explicit dependency upon Treeview using TkDefaultFont for display
	ttk::style configure gorilla.Treeview -rowheight [ expr { 2 + [ font metrics TkDefaultFont -linespace ] } ]

	#
	# If the revision numbers of our preferences don't match, forget
	# about window geometries, as they might have changed.
	#

	if {![string equal $revision $prefsRevision]} {
		foreach geo [array names ::gorilla::preference geometry,*] {
			unset ::gorilla::preference($geo)
		}
	}

	catch {close $f}
	return 1

} ; # end proc gorilla::LoadPreferencesFromRCFile

proc gorilla::LoadPreferences {} {
	if {[info exists ::gorilla::preference(norc)] && \
		$::gorilla::preference(norc)} {
		return 0
	}
	LoadPreferencesFromRCFile
	return 1
}

# ----------------------------------------------------------------------
# Change the password
# ----------------------------------------------------------------------
#

proc gorilla::ChangePassword {} {
	ArrangeIdleTimeout

	if {![info exists ::gorilla::db]} {
		tk_messageBox -parent . \
			-type ok -icon error -default ok \
			-title [ mc "No Database" ] \
			-message [ mc "Please create a new database, or open an existing\ndatabase first." ]
		return
	}

	if {[catch {set currentPassword [GetPassword 0 [mc "Current Master Password:"]]} err]} {
		# canceled
		return
	}
	if {![$::gorilla::db checkPassword $currentPassword]} {
		tk_messageBox -parent . \
			-type ok -icon error -default ok \
			-title [ mc "Wrong Password" ] \
			-message [ mc "That password is not correct." ]
		return
	}

	pwsafe::int::randomizeVar currentPassword

	if {[catch {set newPassword [GetPassword 1 [mc "New Master Password:"]] } err]} {
		tk_messageBox -parent . \
			-type ok -icon info -default ok \
			-title [ mc "Password Not Changed" ] \
			-message [ mc "You canceled the setting of a new password.\nTherefore, the existing password remains in effect." ]
		return
	}
	$::gorilla::db setPassword $newPassword
	pwsafe::int::randomizeVar newPassword
	set ::gorilla::status [mc "Master password changed."]
	MarkDatabaseAsDirty
}

# ----------------------------------------------------------------------
# X Selection Handler
# ----------------------------------------------------------------------
#

proc gorilla::XSelectionHandler {offset maxChars} {
	switch -- $::gorilla::activeSelection {
		0 {
			set data ""
		}
		1 {
			set data [gorilla::GetSelectedUsername]
			if { $::gorilla::preference(gorillaAutocopy) } {
				after idle { after 200 { ::gorilla::CopyToClipboard Password } }
			}
		}
		2 {
			set data [gorilla::GetSelectedPassword]
		}
		3 {
			set data [gorilla::GetSelectedURL]
		}
		default {
			set data ""
		}
	}

	return [string range $data $offset [expr {$offset+$maxChars-1}]]
}

# ----------------------------------------------------------------------
# Copy data to the Clipboard
# ----------------------------------------------------------------------
#

proc gorilla::CopyToClipboard { what {mult 1} } {

	# Copies a data value to the clipboard
	#
	# what - One of "URL" "Username" or "Password"
	# mult - Clipboard clear time multiplication factor, optional, defaults to 1
	#
	# Consolidates all of the copy to clipboard management code into a
	# single proc.

	switch -exact -- $what {
		Username { set ::gorilla::activeSelection 1 }
		Password { set ::gorilla::activeSelection 2 }
		URL      { set ::gorilla::activeSelection 3 }
		default  { error [mc "gorilla::CopyToClipboard: parameter %s not one of 'Username', 'Password', 'URL'" [mc $what]] }
	}

	ArrangeIdleTimeout

	set item [ gorilla::GetSelected$what ]

	if {$item == ""} {
		set ::gorilla::status [ mc "Can not copy %s to clipboard: no %s defined." [ mc $what ] [ mc $what ] ]
	} else {
		switch -exact -- [ tk windowingsystem ] {
			aqua    -
			win32   { # win32 and aqua only support "clipboard"
				clipboard clear
				clipboard append -- [ ::gorilla::GetSelected$what ]
			}
			x11     -
			default { # x11 supports PRIMARY and
				  # CLIPBOARD x11 style clipboards

				# setup to return data for both PRIMARY and
				# CLIPBOARD so that no matter how a user
				# pastes, they will receive the data they
				# expect

				foreach sel { PRIMARY CLIPBOARD } {
					selection clear -selection $sel
					selection own   -selection $sel .
				} ; # end foreach sel 

			}
		}

		ArrangeToClearClipboard $mult
		set ::gorilla::status [ mc "Copied %s to clipboard." [ mc $what ] ]
		
	} ; # end if item == ""

} ; # end proc gorilla::CopyToClipboard

# ----------------------------------------------------------------------
# Helper procs to get various items from selected db records
# ----------------------------------------------------------------------
#

proc gorilla::GetSelectedURL {} {
	if {[catch {set rn [gorilla::GetSelectedRecord]}]} {
		return
	}

	#
	# Password Safe v3 has a dedicated URL field.
	#

	if {[$::gorilla::db existsField $rn 13]} {
		return [ ::gorilla::dbget url $rn ]
	}

	#
	# Password Safe v2 kept the URL in the "Notes" field.
	#

	if {![$::gorilla::db existsField $rn 5]} {
		return
	}

	set notes [ ::gorilla::dbget notes $rn ]
	if {[set index [string first "url:" $notes]] != -1} {
		incr index 4
		while {$index < [string length $notes] && \
			[string is space [string index $notes $index]]} {
			incr index
		}
		if {[string index $notes $index] == "\""} {
			incr index
			set URL ""
			while {$index < [string length $notes]} {
				set c [string index $notes $index]
				if {$c == "\\"} {
					append URL [string index $notes [incr index]]
				} elseif {$c == "\""} {
					break
				} else {
					append URL $c
				}
				incr index
			}
		} else {
			if {![regexp -start $index -- {\s*(\S+)} $notes dummy URL]} {
				set URL ""
			}
		}
	} elseif {![regexp -nocase -- {http(s)?://\S*} $notes URL]} {
		set URL ""
	}

	return $URL
}


# ----------------------------------------------------------------------

proc gorilla::GetSelectedPassword {} {
	# Retreive the password of the selected item in the treeview
	if {[catch {set rn [gorilla::GetSelectedRecord]} err]} {
		return
	}
	if {![$::gorilla::db existsField $rn 6]} {
		return
	}

	return [ ::gorilla::dbget password $rn ]
}

# ----------------------------------------------------------------------

proc gorilla::GetSelectedRecord {} {
	# Obtain the db record number of the selected item in the treeview

	lassign [ ::gorilla::get-selected-tree-data ] node type rn 

	if { ( $node eq "" ) && ( $type eq "" ) } {
		error "oops"
	}

	if {$type != "Login"} {
		error "oops"
	}

	return $rn
}

proc gorilla::GetSelectedUsername {} {
	# Retreive the username of the selected item in the treeview
	if {[catch {set rn [gorilla::GetSelectedRecord]}]} {
		return
	}

	if {![$::gorilla::db existsField $rn 6]} {
		return
	}

	return [ ::gorilla::dbget user $rn ]
}

# ----------------------------------------------------------------------
# Miscellaneous
# ----------------------------------------------------------------------
#

proc gorilla::DestroyAboutDialog {} {
	ArrangeIdleTimeout
	set top .about
	catch {destroy $top}
	unset ::gorilla::toplevel($top)
}

proc tkAboutDialog {} {
	##about dialog code goes here
	gorilla::About
} 

proc gorilla::About {} {
	ArrangeIdleTimeout
	set top .about

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top -class "Gorilla"
		
		set w .about.mainframe
		
		if {![regexp {Revision: ([0-9.]+)} $::gorilla::Version dummy revision]} {
			set revision "<unknown>"
		}
		
		ttk::frame $w -padding {10 10}
		ttk::label $w.image -image $::gorilla::images(splash)
		ttk::label $w.title -text "[ mc "Password Gorilla" ] $revision" \
			-font {sans 16 bold} -padding {10 10}
		ttk::label $w.description -text [ mc "Gorilla will protect your passwords and help you to manage them with a pwsafe 3.2 compatible database" ] -wraplength 350 -padding {10 0}
		ttk::label $w.copyright \
			-text "\u00a9 2004-2009 Frank Pillhofer\n\u00a9 2010-2013 Zbigniew Diaczyszyn and\n\u00a9 2010-2013 Richard Ellis" \
			-font {sans 9} -padding {10 0}
		ttk::label $w.url -text "https://github.com/zdia/gorilla" -foreground blue \
			-font {sans 10}

		set stdopts [ list -padding {10 0} -font {sans 9} -wraplength 350 ]
		lappend ctr [ ttk::label $w.contributors -text [ mc "Contributors" ] {*}$stdopts -font {sans 10} ]
		lappend ctr [ ttk::label $w.contrib1 -text "\u2022 [ mc "Gorilla artwork contributed by %s" "Andrew J. Sniezek." ]" {*}$stdopts ]
		lappend ctr [ ttk::label $w.contrib2 -text "\u2022 [ mc "German translation by %s" "Zbigniew Diaczyszyn" ]" {*}$stdopts ]
		lappend ctr [ ttk::label $w.contrib3 -text "\u2022 [ mc "Russian translation by %s" "Evgenii Terechkov" ]" {*}$stdopts ]
		lappend ctr [ ttk::label $w.contrib4 -text "\u2022 [ mc "Italian translation by %s" "Marco Ciampa" ]" {*}$stdopts ]
		lappend ctr [ ttk::label $w.contrib5 -text "\u2022 [ mc "French translation by %s" "Benoit Mercier, Alexandre Raymond" ]" {*}$stdopts ]
		lappend ctr [ ttk::label $w.contrib6 -text "\u2022 [ mc "Spanish translation by %s" "Juan Roldan Ruiz" ]" {*}$stdopts ]
		lappend ctr [ ttk::label $w.contrib7 -text "\u2022 [ mc "Portuguese translation by %s" "Daniel Bruno" ]" {*}$stdopts ]

		set I [ expr { [ info exists ::sha2::accel(critcl) ] && $::sha2::accel(critcl) ? "C" : "Tcl" } ]
		ttk::label $w.exten -text [ mc "Using %s sha256 extension." $I ] {*}$stdopts
		
		ttk::frame $w.buttons
		ttk::button $w.buttons.license -text [mc License] -command gorilla::License
		ttk::button $w.buttons.close -text [mc "Close"] -command gorilla::DestroyAboutDialog
		pack $w.buttons.license $w.buttons.close -side left -padx 30
					
		pack $w.image -side top
		pack $w.title -side top -pady 5
		pack $w.description -side top
		pack $w.copyright -side top -pady 5 -fill x
		pack $w.url -side top -pady 5 
		pack {*}$ctr -side top -pady 0 -fill x
		pack $w.exten -side top -pady {2m 0} -fill x
		pack $w.buttons -side bottom -pady 10
		pack $w
		
		wm title $top [mc "About Password Gorilla"]

		bind $top <Return> "gorilla::DestroyAboutDialog"
	
		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW gorilla::DestroyAboutDialog
	} else {
		set w "$top.mainframe"
	}
	
	update idletasks
	wm deiconify $top
	raise $top
	focus $w.buttons.close
	wm resizable $top 0 0
}

proc gorilla::Help {} {
	ArrangeIdleTimeout

	# ReadHelpFiles is looking in the given directory 
	# for a file named help.txt
	::Help::ReadHelpFiles $::gorilla::Dir $::gorilla::preference(lang)
	::Help::Help Overview
}

proc gorilla::License {} {
	ArrangeIdleTimeout
	ShowTextFile .license [mc "Password Gorilla License"] "LICENSE.txt"
}

proc gorilla::DestroyTextFileDialog {top} {
	ArrangeIdleTimeout
	catch {destroy $top}
	unset ::gorilla::toplevel($top)
}

proc gorilla::ShowTextFile {top title fileName} {
	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top -class "Gorilla"

		wm title $top $title

		set text [text $top.text -relief sunken -width 80 \
			-yscrollcommand "$top.vsb set"]

		if {[tk windowingsystem] ne "aqua"} {
			ttk::scrollbar $top.vsb -orient vertical -command "$top.text yview"
		} else {
			scrollbar $top.vsb -orient vertical -command "$top.text yview"
		}

		## Arrange the tree and its scrollbars in the toplevel
		lower [ttk::frame $top.dummy]
		pack $top.dummy -fill both -fill both -expand 1
		grid $top.text $top.vsb -sticky nsew -in $top.dummy
		grid columnconfigure $top.dummy 0 -weight 1
		grid rowconfigure $top.dummy 0 -weight 1

		set botframe [ttk::frame $top.botframe]
		set botbut [ttk::button $botframe.but -width 10 -text [mc "Close"] \
				-command "gorilla::DestroyTextFileDialog $top"]
		pack $botbut
		pack $botframe -side top -fill x -pady 10

		bind $top <Prior> "$text yview scroll -1 pages; break"
		bind $top <Next> "$text yview scroll 1 pages; break"
		bind $top <Up> "$text yview scroll -1 units"
		bind $top <Down> "$text yview scroll 1 units"
		bind $top <Home> "$text yview moveto 0"
		bind $top <End> "$text yview moveto 1"
		bind $top <Return> "gorilla::DestroyTextFileDialog $top"

		$text configure -state normal
		$text delete 1.0 end

		set filename [file join $::gorilla::Dir $fileName]
		if {[catch {
				set file [open $filename]
				$text insert 1.0 [read $file]
				close $file}]} {
			$text insert 1.0 "Oops: file not found: $fileName"
		}

		$text configure -state disabled

		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW "gorilla::DestroyTextFileDialog $top"
	} else {
		set botframe "$top.botframe"
	}

	update idletasks
	wm deiconify $top
	raise $top
	focus $botframe.but
	wm resizable $top 0 0
}

# ----------------------------------------------------------------------
# Find
# ----------------------------------------------------------------------
#

proc gorilla::CloseFindDialog {} {
	set top .findDialog
	if {[info exists ::gorilla::toplevel($top)]} {
		wm withdraw $top
	}
}

proc gorilla::Find {} {
	ArrangeIdleTimeout

	if {![info exists ::gorilla::db]} {
		return
	}

	set top .findDialog

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top -class "Gorilla"
		TryResizeFromPreference $top
		wm title $top "[mc Find]"

		ttk::frame $top.text -padding [list 10 10]
		ttk::label $top.text.l -text [mc "Find Text:"] -anchor w -width 10
		ttk::entry $top.text.e -width 40 \
				-textvariable ::gorilla::preference(findThisText)
		pack $top.text.l $top.text.e -side left
		
		ttk::labelframe $top.find -text [mc "Find Options ..."] \
			-padding [list 10 10]
		ttk::checkbutton $top.find.any -text [mc "Any field"] \
				-variable ::gorilla::preference(findInAny)
		ttk::checkbutton $top.find.title -text [mc "Title"] -width 10 \
				-variable ::gorilla::preference(findInTitle)
		ttk::checkbutton $top.find.username -text [mc "Username"] \
				-variable ::gorilla::preference(findInUsername)
		ttk::checkbutton $top.find.password -text [mc "Password"] \
				-variable ::gorilla::preference(findInPassword)
		ttk::checkbutton $top.find.notes -text [mc "Notes"] \
				-variable ::gorilla::preference(findInNotes)
		ttk::checkbutton $top.find.url -text [ mc "URL" ] \
				-variable ::gorilla::preference(findInURL)
		ttk::checkbutton $top.find.case -text [mc "Case sensitive find"] \
				-variable ::gorilla::preference(caseSensitiveFind)
		
		grid $top.find.any  $top.find.title $top.find.password -sticky nsew
		grid  ^ $top.find.username $top.find.notes -sticky nsew
		grid  ^  $top.find.url -sticky nsew
		grid $top.find.case -sticky nsew
		
		grid columnconfigure $top.find 0 -weight 1
		
		ttk::frame $top.buts -padding [list 10 10]
		set but1 [ttk::button $top.buts.b1 -width 10 -text [mc "Find"] \
						-command "::gorilla::RunFind"]
		set but2 [ttk::button $top.buts.b2 -width 10 -text [mc "Close"] \
						-command "::gorilla::CloseFindDialog"]
		pack $but1 $but2 -side left -pady 10 -padx 20 -fill x -expand 1
		
		pack $top.buts -side bottom -expand yes -fill x -padx 20 -pady 5
		pack $top.text -side top -expand yes -fill x -pady 5
		pack $top.find -side left -expand yes -fill x -padx 20 -pady 5
		
		bind $top.text.e <Return> "::gorilla::RunFind"


		# if any then all checked
		# $top.find.case state selected

		bind $top.text.e <Return> "::gorilla::RunFind"

		set ::gorilla::toplevel($top) $top
		
		wm attributes $top -topmost 1
		focus $top.text.e
		update idletasks
		wm protocol $top WM_DELETE_WINDOW gorilla::CloseFindDialog
		
	} else {
		wm deiconify $top
		# Dialog_Wait
	}

	#
	# Start with the currently selected node, if any.
	#

	set selection [$::gorilla::widgets(tree) selection]
	if {[llength $selection] > 0} {
		set ::gorilla::findCurrentNode [lindex $selection 0]
	} else {
		set ::gorilla::findCurrentNode [lindex [$::gorilla::widgets(tree) children {}] 0]
	}
}

proc gorilla::FindNextNode {node} {
	#
	# If this node has children, return the first child.
	#
	set children [$::gorilla::widgets(tree) children $node]

	if {[llength $children] > 0} {
		return [lindex $children 0]
	}

	while {42} {
		#
		# Go to the parent, and find its next child.
		#
		set parent [$::gorilla::widgets(tree) parent $node]
		set children [$::gorilla::widgets(tree) children $parent]
		set indexInParent [$::gorilla::widgets(tree) index $node]
		incr indexInParent
# gets stdin
# break
		if {$indexInParent < [llength $children]} {
			set node [lindex $children $indexInParent]
			break
		}

		#
		# Parent doesn't have any more children. Go up one level.
		#

		set node $parent
		#
		# If we are at the root node, return its first child (wrap around).
		#

		if {$node == {} } {
			set node [lindex [$::gorilla::widgets(tree) children {}] 0]
			break
		}

		#
		# Find the parent's next sibling (Geschwister)
		#
	} ;# end while
	return $node
}

proc gorilla::FindCompare {needle haystack caseSensitive} {
	if {$caseSensitive} {
		set cmp [string first $needle $haystack]
	} else {
		set cmp [string first [string tolower $needle] [string tolower $haystack]]
	}

	return [expr {($cmp == -1) ? 0 : 1}]
}

proc gorilla::RunFind {} {

	# The call to "tree exists" below is to prevent an error message in the
	# instance that the node referenced by "findCurrentNode" has been deleted
	# from the tree prior to calling "RunFind"
	
	if { [ info exists ::gorilla::findCurrentNode ]
	  && [ $::gorilla::widgets(tree) exists $::gorilla::findCurrentNode ] } {
		set ::gorilla::findCurrentNode [::gorilla::FindNextNode $::gorilla::findCurrentNode]
	} else {
		set ::gorilla::findCurrentNode [lindex [$::gorilla::widgets(tree) children {}] 0]
	}
	
	set text $::gorilla::preference(findThisText)
	set node $::gorilla::findCurrentNode

	set found 0
	set recordsSearched 0
	set totalRecords [llength [$::gorilla::db getAllRecordNumbers]]
	
 	while {!$found} {
# puts "\n--- Runfind while-schleife: next node is $node"

		# set node [::gorilla::FindNextNode $node]
		
		set data [$::gorilla::widgets(tree) item $node -values]
		set type [lindex $data 0]


		
		if {$type == "Group" || $type == "Root"} {
			set node [::gorilla::FindNextNode $node]
			if {$node == $::gorilla::findCurrentNode} {
				break
			}
			continue
		}
		
		incr recordsSearched
		set percent [expr {int(100.*$recordsSearched/$totalRecords)}]
		set ::gorilla::status "Searching ... ${percent}%"
		update idletasks

		set rn [lindex $data 1]
		set fa $::gorilla::preference(findInAny)
		set cs $::gorilla::preference(caseSensitiveFind)
		if {($fa || $::gorilla::preference(findInTitle)) && \
			[$::gorilla::db existsField $rn 3]} {
				if {[FindCompare $text [ ::gorilla::dbget title $rn ] $cs]} {
					set found 3
					break
				}
		}

		if {($fa || $::gorilla::preference(findInUsername)) && \
			[$::gorilla::db existsField $rn 4]} {
				if {[FindCompare $text [ ::gorilla::dbget user $rn ] $cs]} {
					set found 4
					break
				}
		}

		if {($fa || $::gorilla::preference(findInPassword)) && \
			[$::gorilla::db existsField $rn 6]} {
				if {[FindCompare $text [ ::gorilla::dbget password $rn ] $cs]} {
					set found 6
					break
				}
		}

		if {($fa || $::gorilla::preference(findInNotes)) && \
			[$::gorilla::db existsField $rn 5]} {
				if {[FindCompare $text [ ::gorilla::dbget notes $rn ] $cs]} {
					set found 5
					break
				}
		}

		if {($fa || $::gorilla::preference(findInURL)) && \
			[$::gorilla::db existsField $rn 13]} {
				if {[FindCompare $text [ ::gorilla::dbget url $rn ] $cs]} {
					set found 13
					break
				}
		}

		set node [::gorilla::FindNextNode $node]
		
		if {$node == $::gorilla::findCurrentNode} {
			#
			# Wrapped around.
			#
			break
		}
	} ;# end while loop

	if {!$found} {
		set ::gorilla::status [mc "Text not found."]
		return
	}
	#
	# Text found.
	#

	#
	# Make sure that all of node's parents are open.
	#

	set parent [$::gorilla::widgets(tree) parent $node]

	while {$parent != "RootNode"} {
		$::gorilla::widgets(tree) item $parent -open 1
		set parent [$::gorilla::widgets(tree) parent $parent]
	}

	#
	# Make sure that the node is visible.
	#

	$::gorilla::widgets(tree) see $node
	$::gorilla::widgets(tree) selection set $node

	#
	# Report.
	#

	switch -- $found {
		3 {
			set ::gorilla::status "Found matching title."
		}
		4 {
			set ::gorilla::status "Found matching username."
		}
		5 {
			set ::gorilla::status "Found matching notes."
		}
		6 {
			set ::gorilla::status "Found matching password."
		}
		13 {
			set ::gorilla::status "Found matching URL."
		}
		default {
			set ::gorilla::status "Found match."
		}
	}

	#
	# Remember.
	#

	set ::gorilla::findCurrentNode $node
}

proc gorilla::FindNext {} {
	if { [ info exists ::gorilla::findCurrentNode ] } {
		set ::gorilla::findCurrentNode [::gorilla::FindNextNode $::gorilla::findCurrentNode]
		gorilla::RunFind
	} else {
		# if no find state - just jump into a regular "find" operation
		gorilla::Find
	}
}

proc gorilla::getAvailableLanguages {  } {
	set files [glob -tail -path "$::gorilla::Dir/msgs/" *.msg]
	set msgList [list ]    ;# en.msg exists
	
	foreach file $files {
		lappend msgList [lindex [split $file "."] 0]
	}
	
	# FIXME: This dictionary of possible languages has to be expanded
	set langFullName [list en English de Deutsch fr Fran\u00e7ais es Espa\u00f1ol ru Russian it Italiano pt Portuguese]

	# create langList from *.msg pool
	set langList {}
	foreach lang $msgList {
		set res [lsearch $langFullName $lang]
		lappend langList [lindex $langFullName $res] [lindex $langFullName [incr res]]
	}
	return $langList
}

# ----------------------------------------------------------------------
# Icons
# ----------------------------------------------------------------------
#

set ::gorilla::images(application) [image create photo -file [file join $::gorilla::PicsDir application.gif]]

set ::gorilla::images(browse) [image create photo -file [file join $::gorilla::PicsDir browse.gif]]

set ::gorilla::images(group) [image create photo -file [file join $::gorilla::PicsDir group.gif]]

set ::gorilla::images(login) [image create photo -file [file join $::gorilla::PicsDir login.gif]]

# vgl. auch Quelle: http://www.clipart-kiste.de/archiv/Tiere/Affen/affe_08.gif

set ::gorilla::images(splash) [image create photo -file [file join $::gorilla::PicsDir splash.gif]]

proc gorilla::CheckDefaultExtension {name extension} {
	set res [split $name .]
	if {[llength $res ] == 1} {
		set name [join "$res $extension" .]
	}
	return $name
}

proc gorilla::ViewLogin {} {
	ArrangeIdleTimeout

	# proc gorilla::GetRnFromSelectedNode

	lassign [ ::gorilla::get-selected-tree-data RETURN ] node type rn

	if {$type == "Group" || $type == "Root"} {
		set ::gorilla::status [ mc "Please select a login entry first." ]
		return
	}

	gorilla::ViewEntry $rn
 
} ; # end gorilla::ViewLogin

proc gorilla::ViewEntry {rn} {
	# proposed by Richard Ellis, 04.08.2010
	# ViewLogin: non modal and everything disabled
	# EditLogin: modal dialog with changes saved
	
	ArrangeIdleTimeout

	#
	# Set up dialog
	#

	# dervive a unique toplevel name
	set seq 0
	while { [ winfo exists .view$seq ] } {
		incr seq
	}

	set top .view$seq
	
	if {[info exists ::gorilla::toplevel($top)]} {
		
		wm deiconify $top
		
	} else {
	
		toplevel $top -class "Gorilla"
		wm title $top [ mc "View Login" ]
		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW "gorilla::DestroyDialog $top"
		
		# now create infoframe and populate it

		set infoframe [ ttk::frame $top.if -padding {5 5} ]

		foreach {child childname} { group Group title Title url URL 
						user Username pass Password 
						lpc {Last Password Change}
						mod {Last Modified} 
						uuid UUID } {
			
			ttk::label $infoframe.${child}L -text [mc ${childname}]:
			ttk::label $infoframe.${child}E -width 40 -background white
	
			grid $infoframe.${child}L $infoframe.${child}E -sticky ew -pady 5
			
		}		

		ttk::label $infoframe.notesL -text [mc Notes]:
		ttk::label $infoframe.notesE -width 40 -background white -anchor nw -justify left

		# automatic word wrap width adjustment of the notes widget
		# based upon window width
                
		bind $infoframe.notesE <Configure> "$infoframe.notesE configure -wraplength \[ expr \[ winfo width $infoframe.notesE \] - 2 \]"

		# the minus 2 in the bind command above is to work around
		# bug # 3049971 in the ttk::label implementation in tk 8.5.5
		# where if the wraplength is equal to the window width, or
		# one less than the widow width, then certain pixel widths
		# result in no word wrapping at all, see
		# https://sourceforge.net/tracker/index.php?func=detail&aid=3049971&group_id=11464&atid=111464
	
		grid $infoframe.notesL $infoframe.notesE -sticky news -pady 5                
	
		grid columnconfigure $infoframe 1 -weight 1
		grid rowconfigure $infoframe $infoframe.notesE -weight 1
		
		$infoframe.groupE configure -text [ ::gorilla::dbget group            $rn ]
		$infoframe.titleE configure -text [ ::gorilla::dbget title            $rn ]
		$infoframe.userE  configure -text [ ::gorilla::dbget user             $rn ]
		$infoframe.notesE configure -text [ ::gorilla::dbget notes            $rn ]
		$infoframe.passE  configure -text [ string repeat "*" [ string length [ ::gorilla::dbget password $rn ] ] ]
		$infoframe.lpcE   configure -text [ ::gorilla::dbget last-pass-change $rn "<unknown>" ] 
		$infoframe.modE   configure -text [ ::gorilla::dbget last-modified    $rn "<unknown>" ]
		$infoframe.urlE   configure -text [ ::gorilla::dbget url              $rn ]
		$infoframe.uuidE  configure -text [ ::gorilla::dbget uuid             $rn ]

		# now create button frame and populate it
                	
		set buttonframe [ ttk::frame $top.bf -padding {10 10} ]
		
		ttk::button $buttonframe.close -text [mc "Close"] -command "gorilla::DestroyDialog $top"
		ttk::button $buttonframe.showpassw -text [mc "Show Password"] \
			-command [ list ::gorilla::ViewEntryShowPWHelper $buttonframe.showpassw $infoframe.passE $rn ]
		
		pack $buttonframe.showpassw -side top -fill x
		pack $buttonframe.close -side top -fill x -pady 5
		
		grid $infoframe $buttonframe -sticky news
		grid columnconfigure $top 0 -weight 1
		grid rowconfigure    $top 0 -weight 1
	}

} ; # end proc gorilla::ViewEntry

#
# ----------------------------------------------------------------------
# A helper proc to make the show password button an actual toggle button
# ----------------------------------------------------------------------
#

proc gorilla::ViewEntryShowPWHelper { button entry rn } {
	if { [ $button cget -text ] eq [ mc "Show Password" ] } {
		$entry configure -text [ ::gorilla::dbget password $rn ]
		$button configure -text [ mc "Hide Password" ]
	} else {
		$entry configure -text [ string repeat "*" [ string length [ ::gorilla::dbget password $rn ] ] ]
		$button configure -text [ mc "Show Password" ]
	}

} ; # end proc gorilla::ViewEntryShowPWHelper

#
# ----------------------------------------------------------------------
# A helper proc to fill ttk::comboxes with password "group" listings
# ----------------------------------------------------------------------
#

proc gorilla::fill-combobox-with-grouplist { win } {

	# handles filling in the entries in the dropdown list for the group
	# combo box - done this way for two reasons: 1) the dropdown box
	# will always reflect the current group names; and 2) I am
	# contemplating allowing a "limit the list" capability based upon
	# the current value of the combo box

	# There is a dependency upon the ::gorilla::groupNodes global
	# variable

	$win configure -values [ lsort [ array names ::gorilla::groupNodes ] ]

} ; # end proc gorilla::fill-combobox-with-grouplist

#
# ----------------------------------------------------------------------
# A helper proc to obtain type and record number of selected tree entry
# ----------------------------------------------------------------------
#

proc gorilla::get-selected-tree-data { {returninfo {}} } {

	# Returns the type (group/login) and db record number of the
	# selected ttk::treeview entry
	#
	# If nothing in tree is selected, then what is returned depends upon
	# the returninfo variable.  If returninfo is empty, return an empty
	# three element list.  If returninfo is the word RETURN, then
	# perform a -code return to cause the calling proc to return. 
	# Otherwise, feed the contents of returninfo through mc and set the
	# gorilla::status variable, and then return a -code return.

	if { [ llength [ set sel [ $::gorilla::widgets(tree) selection ] ] ] == 0 } {

		# nothing selected - what we return depends upon
		# $returninfo, one of an empty list, a code of return, or
		# setting of the status variable followed by a code of
		# return
		
		switch -- $returninfo {
			{} { return [ list {} {} {} ] }
			{RETURN} { return -code return }
			default { set ::gorilla::status [ mc $returninfo ]
				return -code return
			}
		}
	}

	set node [ lindex $sel 0 ]
	set data [ $::gorilla::widgets(tree) item $node -values ]

	return [ list $node {*}[ lrange $data 0 1 ] ]

} ; # end proc ???

#
# ----------------------------------------------------------------------
# Launch a browser to the current selected records URL
# ----------------------------------------------------------------------
#

proc gorilla::LaunchBrowser { rn } {

	# add quotes around the URL value to protect it from most issues
	# with {*} expansion
	set URL \"[ dbget url $rn ]\"
	if { $URL eq "" } { 
		set ::gorilla::status [ mc "The selected login does not contain a URL value." ]
	} elseif { $::gorilla::preference(browser-exe) eq "" } {
		set ::gorilla::status [ mc "Browser launching is not configured. See help." ]
	} else {
		set param $::gorilla::preference(browser-param)
		if { $param ne "" } {
			if { [ string match "*%url%*" $param ] } {
				set URL [ string map [ list %url% $URL ] $param ]
			} else {
				set ::gorilla::status [ mc "Browser parameter lacks '%url%' string. See help." ]
				return
			}
		}
		if { [ catch { exec $::gorilla::preference(browser-exe) {*}$URL & } mesg ] } {
			tk_dialog .errorurl [ mc "Error" ] "[ mc "Error launching browser, the OS error message is:" ]\n\n$mesg" "" "" [ mc "Oh well..." ]
		} else {
			set ::gorilla::status "[ mc "Launched browser:" ] $::gorilla::preference(browser-exe)"
			if { $::gorilla::preference(autocopyUserid) } {
				::gorilla::CopyToClipboard Username $::gorilla::preference(autoclearMultiplier)
			}
				
		}
	}

} ; # end proc gorilla::LaunchBrowser

#
# ----------------------------------------------------------------------
# DB access by name: dbget, dbset, dbunset
# ----------------------------------------------------------------------
#

# A namespace  ensemble to make retrieval from the gorilla::db object more
# straightforward (retrieval of record elements by name instead of number). 
# This also consolidates almost all of the "if record exists" and "if field
# exists" checks into one place, simplifying the dialog builder code above,
# as well as consolidating the date formatting code into one single
# location.

# Example: dbget title

# At the moment there is a dependency upon the global ::gorilla::db
# variable/object.  A future change might be to pass in the database object
# into which to perform the lookup as well.

namespace eval ::gorilla::dbget {

        # Generate a set of procs which will be the subcommands of the dbget
        # ensemble, the procs simply chain over to a generic "get-record"
        # proc, passing "get-record" the record number value that corresponds
        # to the field the subcommand name represents.
        
        # The "get-date-record" proc is the same idea, except it formats
        # returning data as a date instead of returning the integer value
        # representing seconds from epoch.
        
        # As all of the subcommand procs are identical (except for calling
        # get-record vs get-date-record) generate them in a loop instead of
        # enumerating them.

	foreach {procname recnum} [ list  uuid 1  group 2  title 3  user 4 username 4 \
					notes 5  password 6  url 13 ] {

		proc $procname { rn {default ""} } [ string map [ list %recnum $recnum ] {
			get-record %recnum $rn $default
		} ]

	} ; # end foreach procname,recnum

        foreach {procname recnum} [ list  create-time 7  last-pass-change 8  last-access 9 \
        				 lifetime 10 last-modified 12 ] {

		proc $procname { rn {default ""} } [ string map [ list %recnum $recnum ] {
			get-date-record %recnum $rn $default
		} ]

	} ; # end foreach procname,recnum

	namespace export uuid group title user username notes password url create-time last-pass-change last-access lifetime last-modified

	# get-record -> a helper proc for the ensemble that hides in one place all
	# the complexity of checking for a records/fields existance and returning
	# a default value when something does not exist
  
 	proc get-record { element recnum default } {

		if { ( [ $::gorilla::db existsRecord $recnum ] ) \
			&& ( [ $::gorilla::db existsField  $recnum $element ] ) } {
				return [ $::gorilla::db getFieldValue $recnum $element ]
		}

		return $default

	} ; # end proc get-record

	# get-date-record -> a second helper proc to consolidate formatting of
	# date values in one place.  This calls the get-record helper, and
	# then either formats a date value or returns the default if the
	# formatting fails.  A future modification could be to provide
	# custom language specific date formatting.

	proc get-date-record { element recnum default } {

		set datetime [ get-record $element $recnum $default ]

		if { [ catch { set formatted [ clock format $datetime \
				-format "%Y-%m-%d %H:%M:%S" ] } ] } {
	 		return $default
	 	} else {
	 		return $formatted
	 	}

	} ; # end proc get-date-record
	
  	namespace ensemble create

} ; # end namespace eval ::gorilla::dbget

# A namespace ensemble to make setting fields to the gorilla::db object more
# straightforward (setting of record elements by name instead of number). 

# At the moment there is a dependency upon the global ::gorilla::db
# variable/object.  A future change might be to pass in the database object
# into which to perform the lookup as well.

namespace eval ::gorilla::dbset {

        # Generate a set of procs which will be the subcommands of the dbset
        # ensemble, the procs simply chain over to the ::gorilla::db object
        # with the proper parameters to set a numeric record number
        # corresponding to the record name.
        
        # As all of the subcommand procs are identical (except for scanning
        # a date/time vs. assuming it is an integer generate them in a pair
        # of loops instead of enumerating them.

        # note - field #11 is marked as reserved in the pwsafe v3
        # documentation
        
	foreach {procname fieldnum} [ list  uuid 1  group 2  title 3  user 4 username 4 \
					notes 5  password 6  create-time 7 \
					last-pass-change 8   last-access 9 \
        				lifetime 10          last-modified 12 \
        				url 13 ] {

		proc $procname { rn value } [ string map [ list %fieldnum $fieldnum ] {
			$::gorilla::db setFieldValue $rn %fieldnum $value

		} ]

	} ; # end foreach procname,fieldnum

        foreach {procname fieldnum} [ list  create-time-string 7  last-pass-change-string 8  last-access-string 9 \
        				 lifetime-string 10 last-modified-string 12 ] {

		proc $procname { rn value } [ string map [ list %fieldnum $fieldnum ] {
			$::gorilla::db setFieldValue $rn %fieldnum [ clock scan $value -format "%Y-%m-%d %H:%M:%S" ]
		} ]

	} ; # end foreach procname,fieldnum

	namespace export uuid group title user username notes password url create-time last-pass-change last-access lifetime last-modified

  	namespace ensemble create

} ; # end namespace eval ::gorilla::dbset

namespace eval ::gorilla::dbunset {

        # Generate a set of procs which will be the subcommands of the dbunset
        # ensemble, the procs simply chain over to the ::gorilla::db object
        # with the proper parameters to unset a numeric record number
        # corresponding to the record name.
        
        # As all of the subcommand procs are identical generate them in a
        # loop instead of enumerating them.

        # note - field #11 is marked as reserved in the pwsafe v3
        # documentation
        
	foreach {procname fieldnum} [ list  uuid 1  group 2  title 3  user 4 \
					notes 5  password 6  create-time 7 \
					last-pass-change 8   last-access 9 \
        				lifetime 10          last-modified 12 \
        				url 13 ] {

		proc $procname { rn } [ string map [ list %fieldnum $fieldnum ] {
			$::gorilla::db unsetFieldValue $rn %fieldnum
		} ]

	} ; # end foreach procname,fieldnum

	namespace export uuid group title user notes password url create-time last-pass-change last-access lifetime last-modified

  	namespace ensemble create

} ; # end namespace eval ::gorilla::dbunset

# ----------------------------------------------------------------------

proc ::gorilla::addRufftoHelp { menu } {

	# Appends an entry to the menu passed in that will call the Ruff!
	# documentation processor to produce source docs.
	#
	# menu - The menu proc to which to append the ruff command entry
	#
	# This needs ruff! and struct::list from tcllib - both should be
	# installed properly for this option to work

	if { ( ! [ catch { package require ruff         } ] ) \
	  && ( ! [ catch { package require struct::list } ] ) } {
	  
	  	proc ::gorilla::makeRuffdoc { } {
			# document all namespaces, except for tcl/tk system namespaces
			# (tk, ttk, itcl, etc.)
			set nslist [ ::struct::list filterfor z [ namespace children :: ] \
			{ ! [ regexp {^::(ttk|uuid|msgcat|pkg|tcl|auto_mkindex_parser|itcl|sha2|tk|struct|ruff|textutil|cmdline|critcl|activestate|platform)$} $z ] } ]
			::ruff::document_namespaces html $nslist -output gorilladoc.html -recurse true
		}
		
		$menu add command -label [mc "Generate gorilladoc.html"] -command ::gorilla::makeRuffdoc
	}

} ; # end proc addRufftoHelp

# ----------------------------------------------------------------------

#
# ----------------------------------------------------------------------
# Drag and Drop for ttk::treeview widget
# ----------------------------------------------------------------------
#

namespace eval ::gorilla::dnd {

	namespace ensemble create

	variable dragging      0        ; # flag to indicate if user is dragging items

	variable selectedItems [ list ]	; # list of items (tree node names) that
	                                  # need to be "moved" to perform the move
	                                  # action

	variable clickPx       -Inf     ; # mouse cursor x position at start of drag
	variable clickPy       -Inf     ; # mouse cursor y position at start of drag

	# ----------------------------------------------------------------------


	namespace export init
	proc ::gorilla::dnd::init { tree } {

		# Adds drag and drop bindings to the tree widget command passed as a
		# parameter
		#
		# tree - name of tree widget onto which to add DND bindings

		bind $tree <ButtonPress-1>    +[ namespace code "press   $tree %x %y" ]
		bind $tree <Button1-Motion>   +[ namespace code "motion  $tree %x %y" ]
		bind $tree <ButtonRelease-1>  +[ namespace code "release $tree %x %y" ]
		bind $tree <<TreeviewSelect>> +[ namespace code "select  $tree" ]

		# create - but do not map yet - a label to use as a drag indicator
		ttk::label $tree.dnd

		#ruff
		# Attaches event bindings to the widget passed as the sole parameter for
		# handling drag and drop operations.  Also creates a single label widget
		# as a child of the parameter which will be utilized as a drag
		# indicator.
		#
		# tree - the widget name to attach the event bindings.  The created
		#        label will be a child of this widget
		
	} ; # end ::gorilla::dnd::init

	# ----------------------------------------------------------------------

	proc ::gorilla::dnd::select { tree } {
		variable dragging
		variable selectedItems
		
		if { ! $dragging } {
			set tempitems [ $tree selection ]
			
			# keep only items that are 1) visible 2) not a child of an item
			# already in the list
			
			set selectedItems [ list ]
			set labeltexts    [ list ]
			foreach item $tempitems {

				# bbox is documented as returning empty list for a not visible item
				if { [ llength [ $tree bbox $item ] ] == 0 } {
					continue
				}

				# at this point the item is visible, so add its label to the
				# labeltexts list

				lappend labeltexts [ $tree item $item -text ]
				
				# skip if parent item already in selection list
				if { [ $tree parent $item ] in $tempitems } {
					continue
				}

				# otherwise remember the item as a move candidate
				lappend selectedItems $item

			} ; # end foreach item in tempitems

 			# put the selected item names into the label widget that is the drag
 			# feedback indicator

			$tree.dnd configure -text [ join $labeltexts "\n" ]

		} ; # end if not dragging

		#ruff
		# Called by event loop when treeview selection changes 
		#
		# tree - the name of the treeview widget
		#
		# If a drag is happening then retreives the list of selected treeview
		# rows and stores them in a namespace varaible in prepraration for a
		# drag operation occurring.  Also inserts the names of the rows in the
		# drag label as feedback to a user for what items are being dragged.
		#
		# If a drag is not happening then do nothing.

	} ; # end proc ::gorilla::dnd::select

	# ----------------------------------------------------------------------

	proc ::gorilla::dnd::press {tree x y} {
		variable clickPx     -Inf
		variable clickPy     -Inf
		
		# can not drag empty area of tree, nor root node of tree - leave set to
		# -Inf in those cases
		
		if { ( [ $tree identify row $x $y ] ni {"" RootNode} ) } {
			set clickPx $x
			set clickPy $y
		} ; # end if selrow ni ""/RootNode

		#ruff
		# Called by mouse button press event to record the x,y position of the
		# mouse cursor in preparation for a possible drag occurring.
		#
		# tree - the tree widget 
		# x - x mouse cursor position
		# y - y mouse cursor position

	} ; # end proc ::gorilla::dnd::press

	# ----------------------------------------------------------------------

	proc ::gorilla::dnd::motion {tree x y} {
		variable dragging
		variable clickPx
		variable clickPy

		# the -Inf default for clickP[xy] is the magic which makes this code
		# below work.  Any x,y position subtracted from -Inf is still -Inf, and
		# -Inf is always smaller than zero, so as long as Px,Py are -Inf, a drag
		# will never initiate

		# a small hysteresis of 5 pixels of motion before we decide that a drag
		# is occurring
		if { ( ! $dragging )
		  && ( 
		          ( [ expr { abs( $clickPx - $x ) } ] > 5 )
		       || ( [ expr { abs( $clickPy - $y ) } ] > 5 ) 
		     ) } {
			set dragging 1
		}

		if { $dragging } {

			# I do not understand why, but configuring -cursor on the tree did not
			# work, yet configuring it on .  did work properly.
			. configure -cursor double_arrow

			set selrow [ $tree identify row $x $y ]
			if { $selrow ne "" } {
				$tree selection set $selrow
				# the "see" causes edge scrolling to happen automatically
				$tree see $selrow
			}

			# use place to position the drag indicator - the +5 pixels positions
			# it just to the right of the cursor bitmap so it does not overlap
			# with the cursor

			place $tree.dnd -x [ expr { $x + 5 } ] -y $y -anchor w

		} ; # end if dragging

		#ruff
		# Called by mouse motion event to both decide when to initiate a drag
		# and to animate the drag as it occurs
		#
		# tree - the tree widget
		# x - new mouse x position
		# y - new mouse y position

	} ; # end proc ::gorilla::dnd::motion

	# ----------------------------------------------------------------------

	proc ::gorilla::dnd::release {tree x y} {
		variable dragging
		variable selectedItems

		if { $dragging } {
			# clean up
			set dragging 0
			place forget $tree.dnd

			set dropIdx [ $tree identify row $x $y ]

			# can not drop into empty section of tree
			if { $dropIdx ne "" } {
				. configure -cursor watch
				update idletasks
				foreach item $selectedItems {
					::gorilla::MoveTreeNode $item $dropIdx
				}
				# if a drop occurs while "find" state exists, set "find" state to
				# the root of the tree
				if { [ info exists ::gorilla::findCurrentNode ] } {
					set ::gorilla::findCurrentNode [lindex [$::gorilla::widgets(tree) children {}] 0]
				}
			}

			. configure -cursor {}

		} ; # end if dragging
		
		#ruff
		# Called by mouse button release event.  If a drag was occurring then
		# handle actually performing the "move" of the selected items to the
		# destination location in the tree.
		#
		# tree - the tree widget
		# x - mouse x position of release event
		# y - mouse y position of release event

	} ; # end proc ::gorilla::dnd::release

} ; # end namespace eval ::gorilla::dnd

proc ::gorilla::conflict-dialog { conflict_list } {

	# Creates a toplevel dialog for use in handling merge conflicts in a
	# straightforward manner
	#
	# conflict_list - a list of database record ID numbers that are in
	# conflict, each pair of ID numbers is one conflict, first number is the
	# current DB entry, second number is the new merged DB entry

	::gorilla::ArrangeIdleTimeout

	if { ( [ llength $conflict_list ] % 4 ) != 0 } {
		error "conflict_list must have a multiple of four elements"
	}

	if { [ llength $conflict_list ] == 0 } {
		return
	}

	# find a unique toplevel name - this linear search is technically
	# inefficient, but unless someone has thousands of these windows open, the
	# actual inefficiency is miniscule.  And if someone has thousands of these
	# windows open, they likely have a much larger window management nightmare
	# on their hands anyway.

	# this code always builds a new toplevel window, and destroys the toplevel
	# when it completes.  
  
	set seq -1
	set top .conflict-dialog[ incr seq ]
	while { [ winfo exists $top ] } {
	  set top .conflict-dialog[ incr seq ]
	}

	# build toplevel and the outer tabset 
	toplevel $top 
	wm withdraw $top
	wm title $top [ mc "Conflict Merge Tool" ]
	# put the toplevel into the "hide these windows upon lock" array
	set ::gorilla::toplevel($top) $top

	# and set things up so if the user closes the window, the entry in the
	# "hide" array is removed
	wm protocol $top WM_DELETE_WINDOW [ list apply [ list {} "unset -nocomplain ::gorilla::toplevel($top) \n destroy $top" ] ]

	set tabs [ ttk::notebook ${top}.tabs ]
	pack $top.tabs -side top -expand true -fill both

	ttk::style configure conflict.TLabelframe.Label -background lightgreen
	ttk::style configure conflict.TLabelframe       -background lightgreen 
	ttk::style configure conflict.TRadiobutton      -background lightgreen  

	# now fill the tabset with one tab per conflict pair

	set seq 0
	foreach { current_dbidx merged_dbidx current_tree_node merged_tree_node } $conflict_list {

		# if either of current or merged dbidx values no longer exist in the db,
		# then remove them from the global conflict list and do nothing more
		# with them
		if { ( ! [ $::gorilla::db existsRecord $current_dbidx ] ) ||
		     ( ! [ $::gorilla::db existsRecord $merged_dbidx  ] ) } {
			::gorilla::remove-from-conflict-list $current_dbidx $merged_dbidx $current_tree_node $merged_tree_node
			UpdateMenu
		  continue
		}

		set container [ ttk::frame ${tabs}.tab[ incr seq ] ]
		set ns ::merger::$container
		namespace eval $ns { }

		# remove the namespace when the container is deleted
		trace add command $container delete [ list ::apply [ list args  [ list namespace delete $ns ] ] ]
		
		$tabs insert end $container -sticky news -text [ mc "Conflict %d" $seq ] -padding { 2m 2m 2m 0m }

		# build out the actual "difference" view widgets within the container frame		

		set merge_widgets [ ::gorilla::build-merge-widgets $container $ns $current_dbidx $merged_dbidx ]

		# now build a button frame to hold the control buttons for this tab
		set bf [ ::ttk::frame ${container}.buttonf ]

		grid [ ::ttk::button $bf.save   -text [ mc "Combine and Save" ] -state disabled ] \
		     [ ::ttk::button $bf.reset  -text [ mc "Reset Values"     ] ] \
		     [ ::ttk::button $bf.ignore -text [ mc "Ignore Conflict"  ] ] -sticky news -padx {5m 5m}
		grid columnconfigure $bf all -weight 1

		$bf.save   configure -command [ list ${ns}::save-data-to-db $current_dbidx $merged_dbidx $current_tree_node $merged_tree_node $container $tabs ]
		$bf.reset  configure -command [ list ${ns}::reset-widgets ]		
		$bf.ignore configure -command [ list ::gorilla::merge-destroy $container $tabs ]
		
		set feedback [ ::ttk::label $container.feedback -text "" -relief sunken -padding {1m 1m 1m 1m} ]

		pack $feedback $bf -side bottom -pady {0m 2m} -fill x

		# Build a custom proc to handle setting the feedback message plus
		# managing an after event to clear the message after twenty seconds
		#
		# Everything wrapped in "catch" because a user might close the window,
		# thereby destroying it, before the after has fired.

		proc ${ns}::feedback {message} [ string map [ list %feedback $feedback %ns $ns ] {
			catch { %feedback configure -text $message }
			catch { after cancel [ set %ns::feedback_after_id ] }
			set %ns::feedback_after_id [ after 20000 {catch {%feedback configure -text ""}} ]
		} ]

		# Build a custom proc to handle changing the state of the save button from disabled to normal
		# $merge_widgets format {rb1 en1 rb2 en2 item var}
		# first extract the radio button shared variable names from the list, and setup a write trace to fire save-button-mgr
		set rbvars [ list ]
		foreach {rb1 en1 rb2 en2 item var} $merge_widgets {
		  lappend rbvars $var
		}
		
		proc ${ns}::save-button-mgr {args} [ string map [ list %rbvars $rbvars %savebutton $bf.save ] {
			foreach rbvar {%rbvars} {
				if { [ set $rbvar ] eq "" } {
					# performing the disablment here prevents a "flashing" of the save button
					# after it has been enabled once
					%savebutton configure -state disabled
					return
				}
			}
			%savebutton configure -state normal
		} ]

	} ; # end foreach current_dbidx, merged_dbidx in conflict_list
	
	# make sure at least one tab was created, otherwise it means that there
	# was nothing to show
	if { [ llength [ $tabs tabs ] ] == 0 } {
		destroy $top
		# nothing to show means that there should be nothing in the conflict data list as well
		set ::gorilla::merge_conflict_data [ list ]
		unset ::gorilla::toplevel($top)
		UpdateMenu
		set ::gorilla::status [ mc "No existing merge conflicts were found." ]
		return
	}

	# prevent the window from shrinking spontaneously when the taller tabs are
	# closed
	after 2000 [ subst -nocommands {catch {wm minsize $top [ winfo width $top ] [ winfo height $top ]} } ]

	wm deiconify $top
  
} ; # end proc ::gorilla::conflict-dialog

# ----------------------------------------------------------------------

proc text+vsb {path args} {

	# Creates a text plus vertical scrollbar combo widget.
	#
	# path - the path name to create.  This will also be the name that is used
	# to access the embedded text widget
	# args - additional arguments, passed directly to the embedded text widget
	#
	# returns the input $path name
		
	ttk::frame $path
	set text [ text ${path}.text {*}$args ]
	set vsb  [ ttk::scrollbar ${path}.vsb -orient vertical -command [ list $text yview ] ]
	$text configure -yscrollcommand [ list $vsb set ]

	grid $text $vsb -sticky news
	grid columnconfigure $path 0 -weight 1
	grid rowconfigure    $path 0 -weight 1

	# Now map the frame name to access the internal text widget instead of the
	# frame.  But first hide the frame name so it does not get destroyed as
	# part of the remapping

	rename $path $path.text.frame
	interp alias {} $path {} $text
	
	return $path
} ; # end proc text+vsb

# ----------------------------------------------------------------------

proc ::gorilla::build-merge-widgets { container ns current_dbidx merged_dbidx } {

	# Builds the actual contents of each conflict tab in the tabset
	#
	# container - the outer "frame" into which to build the widgets
	# ns - the namespace assigned to this conflict pair
	# current_dbidx - the gorillaDB index value of the existing db entry
	# merged_dbidx - the gorilalDB index value of the entry that was
	# merged into this db and conflicted with an existing entry

	set seq -1
	
	foreach {item widget} {group    ::ttk::entry 
	                       title    ::ttk::entry 
	                       url      ::ttk::entry
	                       username ::ttk::entry
	                       password ::ttk::entry
	                       notes    text+vsb } {
	
		set labelframe [ ::ttk::labelframe ${container}.${item} -text [ mc [ string totitle $item ] ] ]

		# make sure the radiobutton -variable exists
		set ${ns}::rb$item ""

		set en1 [ $widget ${labelframe}.en1 -width 60 ]
		set en2 [ $widget ${labelframe}.en2 -width 60 ]
		set rb1 [ ::ttk::radiobutton ${labelframe}.rb1 -text [ mc Current ] -variable ${ns}::rb$item -value [ list $en1 get ] ]
		set rb2 [ ::ttk::radiobutton ${labelframe}.rb2 -text [ mc Merged  ] -variable ${ns}::rb$item -value [ list $en2 get ] ]

		# The after idle calls below are necessary because the variable attached
		# to the radio button is not set set until after this button release
		# binding has fired.  The save-button-mgr proc queries the variable
		# values to adjust the save button state.  An after idle firing will
		# allow the variable to be set by the radio button bindings before
		# save-button-mgr queries the same variable.

		bind $rb1 <ButtonRelease-1> +[ list after idle ${ns}::save-button-mgr ]
		bind $rb2 <ButtonRelease-1> +[ list after idle ${ns}::save-button-mgr ]
			  
		grid $rb1 $en1 -sticky news 
		grid $rb2 $en2 -sticky news
		grid configure $rb1 -padx {2m 0m} -pady {0m 2m}
		grid configure $rb2 -padx {2m 0m} -pady {0m 2m}
		grid configure $en1 -padx {0m 2m} -pady {0m 2m}
		grid configure $en2 -padx {0m 2m} -pady {0m 2m}

		grid columnconfigure $labelframe 1 -weight 1
			
		pack $labelframe -side top -pady {0m 2m} -fill x

		# save entry/text names, the db item number, and radio button variable
		# name for use later in filling the widgets with data from the db and managing the save button

		lappend entries $rb1 $en1 $rb2 $en2 $item ${ns}::rb$item
			  
		# special extras for text widgets and password entry

		switch $item {
			notes {

				$rb1 configure -value [ list $en1 get 0.0 end-1c ]
				$rb2 configure -value [ list $en2 get 0.0 end-1c ]

				# the max/min below constrains the height of the text widgets to be
				# somewhere between 5 lines and 10 lines depending on the amount of
				# data in the database notes field
				set height [ max 5 \
					   [ llength [ split [ ::gorilla::dbget $item $current_dbidx ] "\n" ] ] \
					   [ llength [ split [ ::gorilla::dbget $item $merged_dbidx  ] "\n" ] ] \
				]
				$en1 configure -height [ min 10 $height ]
				$en2 configure -height [ min 10 $height ]

			# end notes arm
			}

			password {
				$en1 configure -show *
				$en2 configure -show *
				foreach widget [ list $en1 $en2 ] {
					bind $widget <Button-3> +[ list ::apply { {args} {
						foreach win $args {
							$win configure -show [ expr { [ $win cget -show ] eq "*" ? {} : "*" } ]
						}
					} } $en1 $en2 ]
				} ; # end foreach widget

			# end password arm
			}

		} ; # end switch item

	} ; # end foreach item,widget

	# finally, now that we know all the widget names, build a reset proc that
	# knows how to set the widgets and texts to the current data in the
	# database and a save proc that knows how to extract data from the entries
	# and save to the database

	proc ${ns}::reset-widgets {} [ string map [ list %entries $entries \
							 %current_dbidx $current_dbidx \
							 %merged_dbidx $merged_dbidx ] {

		::gorilla::ArrangeIdleTimeout
		foreach {rb1 en1 rb2 en2 item var} {%entries} {

			if { $item ne "notes" } {
				$en1 delete 0 end
				$en2 delete 0 end
			} else {
				$en1 delete 0.0 end
				$en2 delete 0.0 end
			}

			$en1 insert end [ ::gorilla::dbget $item %current_dbidx ]
			$en2 insert end [ ::gorilla::dbget $item %merged_dbidx  ]

			if { [ ::gorilla::dbget $item %current_dbidx ] eq [ ::gorilla::dbget $item %merged_dbidx ] } {
				$rb1 invoke
				$rb2 configure -style {}
				[ winfo parent $rb1 ] configure -style {}
			} else {
				$rb1 configure -style conflict.TRadiobutton
				$rb2 configure -style conflict.TRadiobutton
				[ winfo parent $rb1 ] configure -style conflict.TLabelframe
			}

		}
	} ]

	# and immediately call the reset proc to initially fill the widgets

	${ns}::reset-widgets

	# also build a proc to save the selected entries to the gorilla db,
	# delete the duplicate conflicting db entry, and close out this
	# tabset

	proc ${ns}::save-data-to-db { current_dbidx merged_dbidx current_tree_node merged_tree_node container tabs} [ string map [ list %ns $ns ] {

		::gorilla::ArrangeIdleTimeout

		# verify that all radio buttons are checked
		set missing [ list ]
		foreach item {group title url username password notes} {
			if { ( ! [ info exists %ns::rb$item ] ) || ( [ set %ns::rb$item ] eq "" ) } {
				lappend missing [ mc [ string totitle $item ] ]
			} ; # end if var does not exist or is empty
		} ; # end foreach item

		if { [ llength $missing ] > 0 } {
			%ns::feedback "[ mc "A selection is required for:" ] [ join $missing ", " ]"
			return
		} ; # end if llength missing > 0

		foreach item {group title url username password notes} {
			::gorilla::dbset $item $current_dbidx [ {*}[ set %ns::rb$item ] ] 
		}
		
		$::gorilla::db deleteRecord $merged_dbidx

		# if multiple conflicts occur, then a user may have deleted the tree
		# node in another conflict resolution tab or session - prevent user
		# visible errors in that case
		catch { $::gorilla::widgets(tree) delete $current_tree_node }
		catch { $::gorilla::widgets(tree) delete $merged_tree_node  }

		::gorilla::AddRecordToTree $current_dbidx

		::gorilla::merge-destroy $container $tabs
		
		::gorilla::remove-from-conflict-list $current_dbidx $merged_dbidx $current_tree_node $merged_tree_node

	} ] ; # end proc {ns}::save-data-to-db

	# return the widget names to our caller so it can make use of them
	# to adjust the state of the "save" button

	return $entries
  
} ; # end proc ::gorilla::build-merge-widgets

# ----------------------------------------------------------------------

proc ::gorilla::merge-destroy { container tabset } { 

	# Called to destroy a merge widget set.  Also checks to see if the
	# tabset of the toplevel window becomes empty due to the destruction of
	# the last contained merge widget set and if so also destroys the toplevel
	#
	# container - the container to destroy
	# tabset - the tabset to check for emptiness

	::gorilla::ArrangeIdleTimeout

	set top [ winfo toplevel $container ]

	destroy $container

	if { [ llength [ $tabset tabs ] ] == 0 } {
		destroy $top
		# remove the toplevel name from the "windows to hide upon lock" array
		unset ::gorilla::toplevel($top)
		# disable the "merge conflict" menu entry
		UpdateMenu
	}

} ; # end proc ::gorilla::merge-destroy

# ----------------------------------------------------------------------

proc ::gorilla::remove-from-conflict-list { current_dbidx merged_dbidx current_tree_node merged_tree_node } {

		# remove this entry from the global merge conflict data list

		# An O(N) complexity removal for now - thankfully this list will be no
		# longer than the number of password entries, and so the O(N) complexity
		# factor should not be a huge loss.

		set temp [ list ]
		
		foreach {a b c d} $::gorilla::merge_conflict_data {
		  if { ( $a ne $current_dbidx     ) &&
		       ( $b ne $merged_dbidx      ) &&
		       ( $c ne $current_tree_node ) &&
		       ( $d ne $merged_tree_node  ) } {
				lappend temp $a $b $c $d
			}
		}

		set ::gorilla::merge_conflict_data  $temp

} ; # end proc ::gorilla::remove-from-conflict-list


# ======================================================================
# Lookup for new Version
# ======================================================================


# ----------------------------------------------------------------------
proc gorilla::versionIsNewer { server } {
  
  # server - Version downloaded from version.txt on server
  # format is: n.n.n(...)
  # returns 1 if server version is newer otherwise 0
  
  regexp {Revision: ([0-9.]+)} $::gorilla::Version dummy version

	set localList [split $version .]
	set serverList [split $server .]

	foreach remote $serverList local $localList {
		if { $remote > $local } {
      return 1
		} else {
			continue
		}
	}
  return 0
}

# ----------------------------------------------------------------------
proc gorilla::versionCheckHttp { url {flag 0} } {
# ----------------------------------------------------------------------
  # tries to connect to the passed url and returns results
  # url - see downloads.txt
  # flag - the optional validate flag prevents downloading the whole data
  # if there is a check for the large binaries
  # returns { 0 errortext } || { fileLen http::data }
  
  set result ""
  
  if { [ catch { set token [::http::geturl $url -validate $flag ] } oops ] } {
    
    # in error case no http::cleanup necessary
    return [list 0 "Error: $oops -\n\nTried: $url"]

  } elseif { [::http::status $token] ne "ok" } {

      set result [list 0 "[::http::error $token]"]

  } elseif { [string index [::http::ncode $token] 0] != 2 } {

      # codes beginning with 2 are ok.
      set result [list 0 "[::http::code $token]"]

  } else {

      # get file length and http::data
      set result [list [dict get [http::meta $token] Content-Length] [http::data $token]]
  }
  http::cleanup $token
  return $result
}

# ----------------------------------------------------------------------
proc gorilla::versionGet { platform } {
  
  # /sources/downloads.txt contains download sites
  # version.txt on the server contains version information
  #
  # platform - The user's actual Tk windowingsystem
  # returns list: version url || 0 errormessage
  
  set fh [open $::gorilla::Dir/downloads.txt r]
  set data [read $fh]
  close $fh
  
  lassign $data mirrors

  #
  # connect to mirrors
  #
  
  foreach mirror $mirrors {
    
    set url $mirror/version.txt
    set error 0
    
    lassign [gorilla::versionCheckHttp $url] fileLen data

    if { $fileLen == 0 } { set error 1 }

  } ;# end foreach mirror

  if { $error } { return [list 0 "Last mirror: $url\n\n$data"] }

  #
  # extract version data 
  #
  
  set version [dict get $data $platform version]
  set exe [dict get $data $platform executable $::tcl_platform(machine)]

  return [list $version $mirror/$exe]
  
} ;# end proc gorilla::versionGet

# ----------------------------------------------------------------------
proc gorilla::versionCallback { w token total current } {
  $w configure -value $current
}

# ----------------------------------------------------------------------
proc gorilla::versionDownload { url } {
  # url - url of new version
  
  #
  # define target location
  #
  
	if { $::gorilla::preference(backupPath) eq "" } {
    if {[tk windowingsystem] == "aqua"} {
      set backupPath "~/Downloads"
    } else {
      set backupPath "~"
    } 
	} else {
		# place backup file into user''s preference directory
		set backupPath $::gorilla::preference(backupPath)
		if { ! [file isdirectory $backupPath] } {
			gorilla::ErrorPopup [mc "No valid directory. - \nPlease define a valid backup directory\nin the Preferences menu."]
      return DIR_ERROR
		}
	} 
	
	set filename [ file join $backupPath [file tail $url] ]

  #
  # check the connection
  #
    
  lassign [gorilla::versionCheckHttp $url 1] fileLen message

  if { $fileLen == 0 } {
    gorilla::ErrorPopup [mc "Http Error"] $message
    return
  }

  #
  # prepare display
  #

  ttk::frame .status-dl -relief sunken
  ttk::progressbar .status-dl.pb -mode determinate -orient horizontal \
    -value 0 -maximum $fileLen
  ttk::label .status-dl.lb -text [mc "Downloading %s: " $url ] -relief sunken
  grid .status-dl.lb .status-dl.pb -sticky news
  grid columnconfigure .status-dl 1 -weight 1
  grid .status-dl - -sticky news

  #
  # start download
  #
  
  set out [open $filename w]  
  
  if { [catch {set download [::http::geturl $url -channel $out \
            -progress [ list gorilla::versionCallback .status-dl.pb ] -blocksize 4096]} oops] } {
    
    gorilla::ErrorPopup "[mc "Http error"]" $oops
    
  } else {
    
    # go on and check file size

    if { [file size $filename] != $fileLen } {
      
      gorilla::ErrorPopup "[mc "Download Error"]" "[mc "Downloaded File has wrong size."]"
      
    } else {
      
      tk_messageBox -title [mc "Download finished"] \
        -message [mc "The new version was successfully downloaded as\n%s." [ file nativename $filename ] ] \
        -icon info -type ok
    }
  }
  http::cleanup $download
  destroy .status-dl
  close $out
  return
  
} ;# end proc gorilla::versionDownload

# ----------------------------------------------------------------------
proc gorilla::versionLookup {} {
  
  # Look if there is a new version on the mirrors defined in 
  # /source/downloads.txt. The version data are lying in the file 
  # version.txt on the mirrors
  
  load-package http
  
  switch [tk windowingsystem] {
    x11     { set platform Linux }
    win32   { set platform Windows }
    aqua    { set platform MacOSX }
    default { set platform unknown }
  }
  
  if { $platform eq "unknown" } {
    gorilla::ErrorPopup [mc Error] [mc "Unknown windowing system"]
    return
  }
  
  lassign [gorilla::versionGet $platform] version url
  
  if { $version == 0 } {
    gorilla::ErrorPopup [mc "Connection error"] $url
    return
  }

  if { ! [gorilla::versionIsNewer $version] } {
    set message [mc "No new version available"]
    tk_messageBox -message $message -icon info -type ok 
    return
  } 
  
  set message "[ mc "You are running version %s." [ regexp {Revision: ([0-9.]+)} $::gorilla::Version dummy actual ; set actual ] ]\n\n"

  append message "[mc "There is a new version %s for %s." $version $platform]"
  append message "\n\n[mc "Shall I download the new version?"]"
  
  # Tk font default style is ugly bold
  option add *Dialog.msg.font {Arial 11}
  set answer [tk_dialog .download [mc "New version available"] $message "" 0 [mc "Executable"] [mc "Sourcecode"] [mc "Cancel"] ]
  
  switch $answer {
    0          { gorilla::versionDownload $url }
    1          { gorilla::versionDownload [regsub [file tail $url] $url gorilla-$version.zip] }
    default    { return }
  }
  
  return
  
} ;# end proc gorilla::versionLookup

#
# ----------------------------------------------------------------------
# Init
# ----------------------------------------------------------------------
#

if {[tk windowingsystem] == "aqua"} {
	# we have to delete the psn_nr in argv
	if {[string first "-psn" [lindex $argv 0]] == 0} { set argv [lrange $argv 1 end]}

	set ::gorilla::MacShowPreferences {
		proc ::tk::mac::ShowPreferences {} {
			gorilla::PreferencesDialog
		}
	}

	proc ::tk::mac::Quit {} {
		gorilla::Exit
	}
  
  proc tk::mac::ShowHelp {} {
    gorilla::Help
  } 
}
	
proc usage {} {
	puts stdout "usage: $::argv0 \[Options\] \[<database>\]"
	puts stdout " Options:"
	puts stdout "   --rc <name>  Use <name> as configuration file (not the Registry)."
	puts stdout "   --norc       Do not use a configuration file (or the Registry)."
	puts stdout "   <database>   Open <database> on startup."
}

if {$::gorilla::init == 0} {
	if {[string first "-norc" $argv0] != -1} {
		set ::gorilla::preference(norc) 1
	}

	set haveDatabaseToLoad 0
	set databaseToLoad ""
	array set ::gorilla::DEBUG {
		TCLTEST 0 \
		TEST 0 \
		CSVEXPORT 0 \
		CSVIMPORT 0 \
	}

	# set argc [llength $argv]	;# obsolete

	for {set i 0} {$i < $argc} {incr i} {
		switch -- [lindex $argv $i] {
			--sourcedoc {
					# Need ruff! and struct::list from tcllib - 
          # Ruff! is installed under /utilities/ruff

          lappend auto_path "$::gorilla::Dir/../utilities/ruff"

					foreach pkg { ruff struct::list } {
						if { [ catch { package require $pkg } ] } {
							puts stderr "Could not load package $pkg, aborting documentation processing."
              exit
						}
					} ; # end foreach pkg

          # document all namespaces, except for tcl/tk system namespaces
          # (tk, ttk, itcl, etc.)
          set nslist [ ::struct::list filterfor z [ namespace children :: ] \
          { ! [ regexp {^::(ttk|uuid|msgcat|pkg|tcl|auto_mkindex_parser|itcl|sha2|tk|struct|ruff|textutil|cmdline|critcl|activestate|platform)$} $z ] } ]
          
          if { [ catch { ::ruff::document_namespaces html $nslist -output $::gorilla::Dir/../utilities/gorilladoc.html -recurse true } oops ] } {
            puts stderr "Could not generate documentation - $oops."
            exit
          }
          
					# cleanup after ourselves
					unset -nocomplain nslist pkg z 
          
          puts "Documentation file $::gorilla::Dir/../utilities/gorilladoc.html has been successfully generated."
          exit
				}
			--norc -
			-norc {
				set ::gorilla::preference(norc) 1
			}
			--rc -
			-rc {
				if {$i+1 >= $argc} {
					puts stderr "Error: [lindex $argv $i] needs a parameter."
					exit 1
				}
				incr i
				set ::gorilla::preference(rc) [lindex $argv $i]
			}
			--help -
			-help {
				usage
				exit 0
			}
			--chkmsgcat -
			-chkmsgcat {
				# Redefine mcunknown to dump to stderr unknown msgcat translations
				# in a format almost suitable for adding to the msgcat files.  The
				# one difference is that each line is prefixed with the locale ID to
				# which it belongs.  Note, no effort is made to filter duplicates. 
				# sort and uniq will already handle that task externally to
				# PWGorilla.
				#
				# I realized this would work after reading the msgcat(n) man page.
				proc ::msgcat::mcunknown {locale src_string} {
				  puts stderr "$locale \"[ string map [ list "\n" "\\n" ] $src_string ]\" \"\" \\"
				  return $src_string
				}			
			}
			--tcltest {
				# TCLTEST 1 and TEST 1:
				# skip the OpenDatabase dialog and load testdb.psafe3
				array set ::gorilla::DEBUG { TCLTEST 1 TEST 1 }
			}
			--test {
				array set ::gorilla::DEBUG { TEST 1 }
			}
			default {
				if {$haveDatabaseToLoad} {
					usage
					exit 0
				}
				set haveDatabaseToLoad 1
				set databaseToLoad [lindex $argv $i]
			}
		}
	} ; unset i
}

gorilla::Init
gorilla::LoadPreferences
gorilla::InitGui
set ::gorilla::init 1

if {$haveDatabaseToLoad} {
	set action [gorilla::Open $databaseToLoad]
} else {
	set action [gorilla::Open]
}

if {$action == "Cancel"} {
	destroy .
	exit		
} ; unset action haveDatabaseToLoad databaseToLoad

if { [tk windowingsystem] eq "aqua" } {
	eval $gorilla::MacShowPreferences
}

wm deiconify .
raise .
update

set ::gorilla::status [mc "Welcome to the Password Gorilla."]

if { $::gorilla::DEBUG(TCLTEST) } {
	set argv ""
	source [file join $::gorilla::Dir .. unit-tests RunAllTests.tcl]
}
