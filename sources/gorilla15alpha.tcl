#! /bin/sh
# the next line restarts using wish \
exec tclsh8.5 "$0" ${1+"$@"}

#
# ----------------------------------------------------------------------
# Password Gorilla, a password database manager
# Copyright (c) 2005 Frank Pilhofer
# modified for use with wish8.5, ttk-Widgets and with German localisation
# modified GUI to work without bwidget
# z.dia@gmx.de
# tested with ActiveTcl 8.5.7
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
# ----------------------------------------------------------------------
#
# gorilla2a.tcl gespeichert 14.11.2009
# gorilla1.5a1 gespeichert 20.12.2009
# gorilla1.5a2 gepeichert 14.01.2010
# pushed to http:/github.com/zdia/gorilla

package provide app-gorilla15alpha 1.0

set ::gorillaVersion {$Revision: 1.5alpha $}
set ::gorillaDir [file dirname [info script]]

# ----------------------------------------------------------------------
# Make sure that our prerequisite packages are available. Don't want
# that to fail with a cryptic error message.
# ----------------------------------------------------------------------
#

if {[catch {package require Tk 8.5} oops]} {
		#
		# Someone's trying to run this application with pure Tcl and no Tk.
		#

		puts "This application requires Tk 8.5, which does not seem to be available. \
			You are working with [info patchlevel]"
		puts $oops
		exit 1
}

option add *Dialog.msg.font {Sans 9}
option add *Dialog.msg.wrapLength 6i

# ----------------------------------------------------------------------
# Let's hurry to show the user an animated gif
# ----------------------------------------------------------------------
toplevel .start

ttk::frame .start.frame -padding [list 10 12] -borderwidth 5 -relief ridge
ttk::progressbar .start.frame.progress -mode indeterminate -maximum 20
ttk::label .start.frame.info -text "Loading Password Gorilla ..."
wm overrideredirect .start 1
wm geometry .start +200+200
pack .start.frame.progress .start.frame.info -side top -pady 5 -fill x
pack .start.frame
.start.frame.progress start 

if {[catch {package require Tcl 8.5}]} {
		wm withdraw .
		tk_messageBox -type ok -icon error -default ok \
			-title "Need more recent Tcl/Tk" \
			-message "The Password Gorilla requires at least Tcl/Tk 8.5\
			to run. This smells like Tcl/Tk [info patchlevel].\
			Please upgrade."
		exit 1
}

#
# The isaac package should be in the current directory
#

foreach file {isaac.tcl} {
	if {[catch {source [file join $::gorillaDir $file]} oops]} {
puts "$::gorillaDir $file"
puts $oops
		wm withdraw .
		tk_messageBox -type ok -icon error -default ok \
			-title "Need $file" \
			-message "The Password Gorilla requires the \"$file\"\
			package. This seems to be an installation problem, as\
			this file ought to be part of the Password Gorilla\
			distribution."
		exit 1
	}
}

#
# There may be a copy of Itcl in our directory
#

foreach testitdir [glob -nocomplain [file join $::gorillaDir itcl*]] {
    if {[file isdirectory $testitdir]} {
	lappend auto_path $testitdir
    }
}

#
# Look for Itcl, or, failing that, tcl++
#

if {[catch {package require Itcl}]} {
		#
		# If we can't have Itcl, can we load tcl++?
		# Itcl is included in tclkit and ActiveState...
		#

		foreach testtclppdir [glob -nocomplain [file join $::gorillaDir tcl++*]] {
	if {[file isdirectory $testtclppdir]} {
			lappend auto_path $testtclppdir
	}
		}

		if {[catch {
	package require tcl++
		}]} {
	wm withdraw .
	tk_messageBox -type ok -icon error -default ok \
		-title "Need \[Incr Tcl\]" \
		-message "The Password Gorilla requires the \[incr Tcl\]\
		add-on to Tcl. Please install the \[incr Tcl\] package."
	exit 1
		}

		#
		# When using tcl++, fool the other packages (twofish, blowfish
		# and pwsafe) into thinking that Itcl is present. The original
		# tcl++ didn't want to be so bold.
		#

	namespace eval ::itcl {
	namespace import -force ::tcl++::class
	namespace import -force ::tcl++::delete
		}

		package provide Itcl 3.0
}

#
# The pwsafe, blowfish, twofish and sha1 packages may be in subdirectories
#

foreach subdir {sha1 blowfish twofish pwsafe msgs} {
	set testDir [file join $::gorillaDir $subdir]
	if {[file isdirectory $testDir]} {
		lappend auto_path $testDir
	}
}

if {[catch {package require msgcat} oops]} {
		puts "error: $oops"
		exit 1
}

namespace import msgcat::*
mcload [file join $::gorillaDir msgs]

if {[catch {package require pwsafe} oops]} {
	wm withdraw .
	tk_messageBox -type ok -icon error -default ok \
		-title "Need PWSafe" \
		-message "The Password Gorilla requires the \"pwsafe\" package.\
		This seems to be an installation problem, as the pwsafe package\
		ought to be part of the Password Gorilla distribution."
	exit 1
}

#
# If installed, we can use the uuid package (part of Tcllib) to generate
# UUIDs for new logins, but we don't depend on it.
#

catch {package require uuid}

#
# ----------------------------------------------------------------------
# Prepare
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

		# Some default preferences

		set ::gorilla::preference(defaultVersion) 3
		set ::gorilla::preference(unicodeSupport) 1
		set ::gorilla::preference(lru) [list]
		# added 27.11.2009 zdia
		set ::gorilla::preference(rememberGeometries) 1
		
}

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

proc gorilla::ClearStatus {} {
	catch {unset ::gorilla::statusClearId}
	set ::gorilla::status ""
}

proc gorilla::InitGui {} {

		# option add *Button.font {Helvetica 10 bold}
		# option add *title.font {Helvetica 16 bold}
		option add *Menu.tearOff 0
		# themed widgets brauchen font etc nicht, wird von styles geregelt
		# keine Hilfstexte in der unteren Fensterleiste wie in bwidget, ist nicht üblich
		
	menu .mbar
	. configure -menu .mbar

# Struktur im menu_desc(ription):
# label	widgetname {item tag command shortcut}

		set meta Control
		set menu_meta Ctrl
		
		if {[tk windowingsystem] == "aqua"}	{
			set meta Command
			set menu_meta Cmd
		}

set ::gorilla::menu_desc {
	File	file	{"New ..." {} gorilla::New "" ""
							"Open ..." {} "gorilla::Open" $menu_meta O
							"Merge ..." open gorilla::Merge "" ""
							Save save gorilla::Save $menu_meta S
							"Save As ..." open gorilla::SaveAs "" ""
							separator "" "" "" ""
							"Export ..." open gorilla::Export "" ""
							separator "" "" "" ""
							"Preferences ..." {} gorilla::Preferences "" ""
							separator "" "" "" ""
							Exit {} gorilla::Exit $menu_meta X
							}	
	Edit	edit	{"Copy Username" login gorilla::CopyUsername $menu_meta U
							"Copy Password" login gorilla::CopyPassword $menu_meta P
							"Copy URL" login gorilla::CopyURL $menu_meta W
							separator "" "" "" ""
							"Clear Clipboard" "" gorilla::ClearClipboard $menu_meta C
							separator "" "" "" ""
							"Find ..." open gorilla::Find $menu_meta F
							"Find next" open gorilla::RunFind $menu_meta G
							}
	Datensatz	login	{ "Add Login ..." open gorilla::AddLogin $menu_meta A
							"Edit Login ..." open gorilla::EditLogin $menu_meta E
							"Delete Login" login gorilla::DeleteLogin "" ""
							"Move Login ..." login gorilla::MoveLogin "" ""
							separator "" "" "" ""
							"Add Group ..." open gorilla::AddGroup "" ""
							"Add Subgroup ..." group gorilla::AddSubgroup "" ""
							"Rename Group ..." group gorilla::RenameGroup "" ""
							"Move Group ..." group gorilla::MoveGroup "" ""
							"Delete Group" group gorilla::DeleteGroup "" ""
							}
	Manage	manage { "Password Policy ..." open gorilla::PasswordPolicy "" ""
							"Database Preferences ..." open gorilla::DatabasePreferencesDialog "" ""
							separator "" "" "" ""
							"Change Master Password ..." open gorilla::ChangePassword "" ""
							}
	Help	help	{ "Help ..." "" gorilla::Help "" ""
							"License ..." "" gorilla::License "" ""
							separator "" "" "" ""
							"About ..." "" gorilla::About "" ""
							}
}	

	foreach {menu_name menu_widget menu_itemlist} $::gorilla::menu_desc {
		
		.mbar add cascade -label [mc $menu_name] -menu .mbar.$menu_widget
	
		menu .mbar.$menu_widget
		
		set taglist ""
		
		foreach {menu_item menu_tag menu_command meta_key shortcut} $menu_itemlist {
	
			# erstelle für jedes widget eine Tag-Liste
			lappend taglist $menu_tag
	
			if {$menu_item eq "separator"} {
				.mbar.$menu_widget add separator
			} else {
				eval set meta_key $meta_key
				set shortcut [join "$meta_key $shortcut" +]
				.mbar.$menu_widget add command -label [mc $menu_item] \
					-command $menu_command -accelerator $shortcut
			} 	
			set ::gorilla::tag_list($menu_widget) $taglist
		} 
	}

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
		-yscroll ".vsb set" -xscroll ".hsb set" -show tree]
	.tree tag configure red -foreground red
	.tree tag configure black -foreground black

	if {[tk windowingsystem] ne "aqua"} {
			ttk::scrollbar .vsb -orient vertical -command ".tree yview"
			ttk::scrollbar .hsb -orient horizontal -command ".tree xview"
	} else {
			scrollbar .vsb -orient vertical -command ".tree yview"
			scrollbar .hsb -orient horizontal -command ".tree xview"
	}
	ttk::label .status -relief sunken -padding [list 5 2]
	pack .status -side bottom -fill x

	## Arrange the tree and its scrollbars in the toplevel
	lower [ttk::frame .dummy]
	pack .dummy -fill both -fill both -expand 1
	grid .tree .vsb -sticky nsew -in .dummy
	grid columnconfigure .dummy 0 -weight 1
	grid rowconfigure .dummy 0 -weight 1
	
	bind .tree <Double-Button-1> {gorilla::TreeNodeDouble [.tree focus]}
	bind $tree <Button-3> {gorilla::TreeNodePopup [gorilla::GetSelectedNode]}
	bind .tree <<TreeviewSelect>> gorilla::TreeNodeSelectionChanged
	
		# On the Macintosh, make the context menu also pop up on
		# Control-Left Mousebutton and button 2 <right-click>
		
		catch {
			if {[tk windowingsystem] == "aqua"} {
					bind .tree <$meta-Button-1> {gorilla::TreeNodePopup [gorilla::GetSelectedNode]}
					bind .tree <Button-2> {gorilla::TreeNodePopup [gorilla::GetSelectedNode]}
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
		bind . <$meta-x> {.mbar.file invoke 10}
		
		bind . <$meta-u> {.mbar.edit invoke 0}
		bind . <$meta-p> {.mbar.edit invoke 1}
		bind . <$meta-w> {.mbar.edit invoke 2}
		bind . <$meta-c> {.mbar.edit invoke 4}
		bind . <$meta-f> {.mbar.edit invoke 6}
		bind . <$meta-g> {.mbar.edit invoke 7}

		bind . <$meta-a> {.mbar.login invoke 0}
		bind . <$meta-e> {.mbar.login invoke 1}
		
		# bind . <$meta-L> "gorilla::Reload"
		# bind . <$meta-R> "gorilla::Refresh"
		# bind . <$meta-C> "gorilla::ToggleConsole"
		# bind . <$meta-q> "gorilla::Exit"

		#
		# Handler for the X Selection
		#

		selection handle . gorilla::XSelectionHandler

		#
		# Handler for the WM_DELETE_WINDOW event, which is sent when the
		# user asks the window manager to destroy the application
		#

		wm protocol . WM_DELETE_WINDOW gorilla::Exit


}

#
# Initialize the Pseudo Random Number Generator
#

proc gorilla::InitPRNG {{seed ""}} {
		#
		# Try to compose a not very predictable seed
		#

		append seed "20041201"
		append seed [clock seconds] [clock clicks] [pid]
		append seed [winfo id .] [winfo geometry .] [winfo pointerxy .]
		set hashseed [pwsafe::int::sha1isz $seed]

		#
		# Init PRNG
		#

		isaac::srand $hashseed
		set ::gorilla::isPRNGInitialized 1
}

proc setmenustate {widget tag_pattern state} {
	if {$tag_pattern eq "all"} {
		# disable all menu_widget in $::gorilla::menu_desc
		return
	}
	foreach {menu_name menu_widget menu_itemlist} $::gorilla::menu_desc {
		set result [lsearch -all $::gorilla::tag_list($menu_widget) $tag_pattern]
		foreach index $result {
			$widget.$menu_widget entryconfigure $index -state $state
		}	
	}
}

proc gorilla::EvalIfStateNormal {menuentry index} {
	if {[$menuentry entrycget $index -state] == "normal"} {
		eval [$menuentry entrycget 0 -command]
	}
}

# ----------------------------------------------------------------------
# Tree Management: Select a node
# ----------------------------------------------------------------------
#

proc gorilla::GetSelectedNode { } {
	# returns node at mouse position
	set xpos [winfo pointerx .]
	set ypos [winfo pointery .]
	set rootx [winfo rootx .]
	set rooty [winfo rooty .]

	set relx [incr xpos -$rootx]
	set rely [incr ypos -$rooty]

	return [.tree identify row $relx $rely]
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
		if {[info exists ::gorilla::preference(doubleClickAction)]} {
				switch -- $::gorilla::preference(doubleClickAction) {
					copyPassword {
						gorilla::CopyPassword
					}
					editLogin {
						gorilla::EditLogin
					}
				default {
					# do nothing
				}
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
		-command "gorilla::PopupAddLogin"
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

		tk_popup $::gorilla::widgets(popup,Group) $xpos $ypos
}

proc gorilla::PopupAddLogin {} {
		set node [lindex [$::gorilla::widgets(tree) selection] 0]
		set data [$::gorilla::widgets(tree) item $node -values]
		set type [lindex $data 0]

		if {$type == "Group"} {
	gorilla::AddLoginToGroup [lindex $data 1]
		} elseif {$type == "Root"} {
	gorilla::AddLoginToGroup ""
		}
}

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
		if {![info exists ::gorilla::widgets(popup,Login)]} {
	set ::gorilla::widgets(popup,Login) [menu .popupForLogin]
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
		-label [mc "Edit Login"] \
		-command "gorilla::PopupEditLogin"
	$::gorilla::widgets(popup,Login) add separator
	$::gorilla::widgets(popup,Login) add command \
		-label [mc "Delete Login"] \
		-command "gorilla::PopupDeleteLogin"
		}

		tk_popup $::gorilla::widgets(popup,Login) $xpos $ypos
}

proc gorilla::PopupEditLogin {} {
		gorilla::EditLogin
}

proc gorilla::PopupCopyUsername {} {
		gorilla::CopyUsername
}

proc gorilla::PopupCopyPassword {} {
		gorilla::CopyPassword
}

proc gorilla::PopupCopyURL {} {
		gorilla::CopyURL
}

proc gorilla::PopupDeleteLogin {} {
		DeleteLogin
}


# ----------------------------------------------------------------------
# New
# ----------------------------------------------------------------------
#

#
# Attempt to resize a toplevel window based on our preference
#

proc gorilla::TryResizeFromPreference {top} {
	if {![info exists ::gorilla::preference(rememberGeometries)] || \
			!$::gorilla::preference(rememberGeometries)} {
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
		-message [ mc "The current password database is modified.\
		Do you want to save the current database before creating\
		the new database?"]]

		# switch $answer {}
		# yes {}
		# no {aktuelle Datenbank schließen, Variable neu initialisieren}
		# default {return}
		
		if {$answer == "yes"} {
			if {[info exists ::gorilla::fileName]} {
				if {![::gorilla::Save]} {
					return
				}
			} else {
				if {![::gorilla::SaveAs]} {
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

	if { [catch {set password [GetPassword 1 "New Database: Choose Master Password"]} \
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

	if {[info exists ::gorilla::preference(saveImmediatelyDefault)]} {
		$::gorilla::db setPreference SaveImmediately \
		$::gorilla::preference(saveImmediatelyDefault)
	}

	if {[info exists ::gorilla::preference(idleTimeoutDefault)]} {
		if {$::gorilla::preference(idleTimeoutDefault) > 0} {
			$::gorilla::db setPreference LockOnIdleTimeout 1
			$::gorilla::db setPreference IdleTimeout \
			$::gorilla::preference(idleTimeoutDefault)
		} else {
			$::gorilla::db setPreference LockOnIdleTimeout 0
		}
	}

	if {[info exists ::gorilla::preference(defaultVersion)]} {
		if {$::gorilla::preference(defaultVersion) == 3} {
			$::gorilla::db setHeaderField 0 [list 3 0]
		}
	}

	if {[info exists ::gorilla::preference(unicodeSupport)]} {
		$::gorilla::db setPreference IsUTF8 \
		$::gorilla::preference(unicodeSupport)
	}

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
	set ::gorilla::status [mc "Add logins using \"Add Login\" in the \"Login\" menu."]
	. configure -cursor $myOldCursor

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

proc gorilla::OpenPercentTrace {name1 name2 op} {

	if {![info exists ::gorilla::openPercentLastUpdate]} {
		set ::gorilla::openPercentLastUpdate [clock clicks -milliseconds]
		return
	}
	set now [clock clicks -milliseconds]
	set td [expr {$now - $::gorilla::openPercentLastUpdate}]
	# time difference
	if {$td < 200} {
		return
	}

	set ::gorilla::openPercentLastUpdate $now

	if {$::gorilla::openPercent > 0} {
		set info [format "Opening ... %2.0f %%" $::gorilla::openPercent]
		$::gorilla::openPercentWidget configure -text $info
		update idletasks
	}
}

;# proc gorilla::OpenDatabase {title defaultFile} {}
	
# proc gorilla::OpenDatabase {title {defaultFile ""}} {
proc gorilla::OpenDatabase {title {defaultFile ""} {allowNew 0}} {
	
	ArrangeIdleTimeout
	set top .openDialog

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top
		TryResizeFromPreference $top

		set aframe [ttk::frame $top.right -padding [list 10 10]]

		ttk::label $aframe.info -anchor w -width 70 -relief sunken \
			-background #F6F69E -padding [list 5 5 5 5]

		ttk::labelframe $aframe.file -text [mc "Database:"] -width 40

		ttk::combobox $aframe.file.cb -width 40
		ttk::button $aframe.file.sel -image $::gorilla::images(browse) \
			-command "set ::gorilla::guimutex 3"

		pack $aframe.file.cb -side left -padx 10 -pady 10 -fill x -expand yes
		pack $aframe.file.sel -side right -padx 10 

		ttk::labelframe $aframe.pw -text [mc "Password:"] -width 40
		ttk::entry $aframe.pw.pw -width 40 -show "*"
		pack $aframe.pw.pw -side left -padx 10 -pady 10 -fill x -expand yes

		bind $aframe.pw.pw <KeyPress> "+::gorilla::CollectTicks"
		bind $aframe.pw.pw <KeyRelease> "+::gorilla::CollectTicks"

		frame $aframe.buts
		set but1 [ttk::button $aframe.buts.b1 -width 10 -text "OK" \
			-command "set ::gorilla::guimutex 1"]
		set but2 [ttk::button $aframe.buts.b2 -width 10 -text [mc "Cancel"] \
			-command "set ::gorilla::guimutex 2"]
		set but3 [ttk::button $aframe.buts.b3 -width 10 -text [mc "New"] \
			-command "set ::gorilla::guimutex 4"]
		pack $but1 $but2 $but3 -side left -pady 10 -padx 30 -fill x -expand 1

		pack $aframe.file -side top -padx 10 -pady 10 -fill x -expand yes
		pack $aframe.pw -side top -padx 10 -pady 5  -fill x -expand yes
		pack $aframe.buts -side top -padx 10 -pady 5 -fill x -expand yes
		pack $aframe.info -side top	-padx 10 -pady 5 -fill x -expand yes
	
		bind $aframe.file.cb <Return> "set ::gorilla::guimutex 1"
		bind $aframe.pw.pw <Return> "set ::gorilla::guimutex 1"
		bind $aframe.buts.b1 <Return> "set ::gorilla::guimutex 1"
		bind $aframe.buts.b2 <Return> "set ::gorilla::guimutex 2"
		bind $aframe.buts.b3 <Return> "set ::gorilla::guimutex 4"
		
		pack $aframe
		
		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW gorilla::DestroyOpenDatabaseDialog
		} else {
			set aframe $top.right
			wm deiconify $top
		}

	wm title $top $title
	$aframe.pw.pw delete 0 end

	if {[info exists ::gorilla::preference(lru)] \
			&& [llength $::gorilla::preference(lru)] } {
		$aframe.file.cb configure -values $::gorilla::preference(lru)
		$aframe.file.cb current 0
	}

	if {$allowNew} {
		set info [mc "Select a database, and enter its password. Click \"New\" to create a new database."]
		$aframe.buts.b3 configure -state normal
	} else {
		set info "Select a database, and enter its password."
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
		grab $top

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
			-title "No File" \
			-message "Please select a password database."
		continue
			}

			if {![file readable $fileName]} {
		tk_messageBox -parent $top -type ok -icon error -default ok \
			-title "File Not Found" \
			-message "The password database\
			\"$nativeName\" does not exists or can not\
			be read."
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

		set ::gorilla::openPercent 0
		set ::gorilla::openPercentWidget $aframe.info
		trace add variable ::gorilla::openPercent [list "write"] \
	::gorilla::OpenPercentTrace
		if {[catch {set newdb [pwsafe::createFromFile $fileName $password \
					 ::gorilla::openPercent]} oops]} {
			pwsafe::int::randomizeVar password
			trace remove variable ::gorilla::openPercent [list "write"] \
				::gorilla::OpenPercentTrace
			unset ::gorilla::openPercent
		. configure -cursor $dotOldCursor
		$top configure -cursor $myOldCursor

		tk_messageBox -parent $top -type ok -icon error -default ok \
			-title "Error Opening Database" \
			-message "Can not open password database\
			\"$nativeName\": $oops"
		$aframe.info configure -text $info
		$aframe.pw.pw delete 0 end
		continue
		}
		# all seems well
		trace remove variable ::gorilla::openPercent [list "write"] \
	::gorilla::OpenPercentTrace
		unset ::gorilla::openPercent

		. configure -cursor $dotOldCursor
		$top configure -cursor $myOldCursor
		pwsafe::int::randomizeVar password
		break
	} elseif {$::gorilla::guimutex == 3} {
			set types {
		{{Password Database Files} {.psafe3 .dat}}
		{{All Files} *}
			}

			if {![info exists ::gorilla::dirName]} {
		set ::gorilla::dirName [pwd]
			}

			set fileName [tk_getOpenFile -parent $top \
				-title "Browse for a password database ..." \
				-defaultextension ".psafe3" \
				-filetypes $types \
				-initialdir $::gorilla::dirName]
			
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
		$aframe.pw.pw configure -text ""
# set $aframe.pw.entry ""
		if {$oldGrab != ""} {
	grab $oldGrab
		} else {
	grab release $top
		}

		wm withdraw $top
		update

    #
    # Re-enable the main menu.
    #

    setmenustate $::gorilla::widgets(main) all enabled

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

		if {[info exists ::gorilla::preference(lru)]} {
			set found [lsearch -exact $::gorilla::preference(lru) $nativeName]
			if {$found == -1} {
# not found
				set ::gorilla::preference(lru) [linsert $::gorilla::preference(lru) 0 $nativeName]
			} elseif {$found != 0} {
				set tmp [lreplace $::gorilla::preference(lru) $found $found]
				set ::gorilla::preference(lru) [linsert $tmp 0 $nativeName]
			}
		} else {
			set ::gorilla::preference(lru) [list $nativeName]
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
			-title "Save changes?" \
			-message "The current password database is modified.\
			Do you want to save the database?\n\
			\"Yes\" saves the database, and continues to the \"Open File\" dialog.\n\
			\"No\" discards all changes, and continues to the \"Open File\" dialog.\n\
			\"Cancel\" returns to the main menu."]
		if {$answer == "yes"} {
			if {[info exists ::gorilla::fileName]} {
				if {![::gorilla::Save]} {
					return
				}
			} else {
				if {![::gorilla::SaveAs]} {
					return
				}
			}
		} elseif {$answer != "no"} {
			return
		}
	 }

	set openInfo [OpenDatabase [mc "Open Password Database"] $defaultFile 1]
	
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

	set ::gorilla::status [mc "Password database $nativeName loaded."]
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

	AddAllRecordsToTree
	UpdateMenu
	return "Open"
}



# ----------------------------------------------------------------------
# Add a Login
# ----------------------------------------------------------------------


proc gorilla::AddLogin {} {
	gorilla::PopupAddLogin
	# AddLoginToGroup ""
}

# ----------------------------------------------------------------------
# Add a Login to a Group
# ----------------------------------------------------------------------

proc gorilla::AddLoginToGroup {group} {
	ArrangeIdleTimeout

	if {![info exists ::gorilla::db]} {
		tk_messageBox -parent . \
		-type ok -icon error -default ok \
		-title "No Database" \
		-message "Please create a new database, or open an existing\
		database first."
		return
	}

# r-ecord n-umber
	set rn [$::gorilla::db createRecord]

	if {$group != ""} {
		$::gorilla::db setFieldValue $rn 2 $group
	}

	if {![catch {package present uuid}]} {
		$::gorilla::db setFieldValue $rn 1 [uuid::uuid generate]
	}

	$::gorilla::db setFieldValue $rn 7 [clock seconds]

	set res [LoginDialog $rn]
	if {$res == 0} {
		# canceled
		$::gorilla::db deleteRecord $rn
		set ::gorilla::status [mc "Addition of new login canceled."]
		return
	}

	set ::gorilla::status [mc "New login added."]
	AddRecordToTree $rn
	MarkDatabaseAsDirty
}

# ----------------------------------------------------------------------
# Edit a Login
# ----------------------------------------------------------------------
#

proc gorilla::EditLogin {} {
	ArrangeIdleTimeout

	if {[llength [set sel [$::gorilla::widgets(tree) selection]]] == 0} {
		return
	 }
	set node [lindex $sel 0]
	set data [$::gorilla::widgets(tree) item $node -values]
	set type [lindex $data 0]

	if {$type == "Group" || $type == "Root"} {
		return
	}

	set rn [lindex $data 1]

	if {[$::gorilla::db existsField $rn 2]} {
		set oldGroupName [$::gorilla::db getFieldValue $rn 2]
	} else {
		set oldGroupName ""
	}

	set res [LoginDialog $rn]

	if {$res == 0} {
		set ::gorilla::status [mc "Login unchanged."]
		# canceled
		return
	}

	if {[$::gorilla::db existsField $rn 2]} {
		set newGroupName [$::gorilla::db getFieldValue $rn 2]
	} else {
		set newGroupName ""
	}

	if {$oldGroupName != $newGroupName} {
		$::gorilla::widgets(tree) delete $node
		AddRecordToTree $rn
	} else {
		if {[$::gorilla::db existsField $rn 3]} {
			set title [$::gorilla::db getFieldValue $rn 3]
		} else {
			set title ""
		}

		if {[$::gorilla::db existsField $rn 4]} {
			append title " \[" [$::gorilla::db getFieldValue $rn 4] "\]"
		}

		$::gorilla::widgets(tree) item $node -text $title
	}

	set ::gorilla::status [mc "Login modified."]
	MarkDatabaseAsDirty
}

# ----------------------------------------------------------------------
# Move a Login
# ----------------------------------------------------------------------
#

proc gorilla::MoveLogin {} {
	gorilla::MoveDialog Login
}

proc gorilla::MoveGroup {} {
	gorilla::MoveDialog Group
}

proc gorilla::MoveDialog {type} {
	ArrangeIdleTimeout
	if {[llength [set sel [$::gorilla::widgets(tree) selection]]] == 0} {
		return
	}
	set node [lindex $sel 0]
	set data [$::gorilla::widgets(tree) item $node -values]
	set nodetype [lindex $data 0]

	set top .moveDialog
	
	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top
		TryResizeFromPreference $top
		wm title $top [mc "Move $type"]

		ttk::labelframe $top.source -text [mc $type] -padding [list 10 10]
		ttk::entry $top.source.e -width 40 -textvariable ::gorilla::MoveDialogSource
		ttk::labelframe $top.dest \
		-text [mc "Destination Group with format <Group.Subgroup> :"] \
		-padding [list 10 10]
		ttk::entry $top.dest.e -width 40 -textvariable ::gorilla::MoveDialogDest
		# Format: group.subgroup
		pack $top.source.e -side left -expand yes -fill x
		pack $top.source -side top -expand yes -fill x -pady 10 -padx 10
		pack $top.dest.e -side left -expand yes -fill x
		pack $top.dest -side top -expand yes -fill x -pady 10 -padx 10

		ttk::frame $top.buts
		set but1 [ttk::button $top.buts.b1 -width 10 -text "OK" \
		 -command "set ::gorilla::guimutex 1"]
		set but2 [ttk::button $top.buts.b2 -width 10 -text [mc "Cancel"] \
			 -command "set ::gorilla::guimutex 2"]
		pack $but1 $but2 -side left -pady 10 -padx 20
		pack $top.buts -side bottom -pady 10
	
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
		set ::gorilla::MoveDialogSource [lindex $data 1]		
	} elseif {$nodetype == "Login"} {
		set rn [lindex $data 1]
		if {[$::gorilla::db existsField $rn 3]} {
			set ::gorilla::MoveDialogSource [$::gorilla::db getFieldValue $rn 3]
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
	grab $top
	
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
					-title "Invalid Group Name" \
					-message "The group name can not be empty."
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
				-title "Invalid Group Name" \
				-message "The name of the parent group is invalid."
			continue
		}
		# all seems well
		break
	}

	if {$oldGrab != ""} {
		grab $oldGrab
	} else {
		grab release $top
	}

	wm withdraw $top

	if {$::gorilla::guimutex != 1} {
		set ::gorilla::status [mc "Moving of $type canceled."]
		return
	}

	gorilla::MoveTreeNode $node $destNode
	
	$::gorilla::widgets(tree) item $destNode -open 1
	$::gorilla::widgets(tree) item "RootNode" -open 1
	set ::gorilla::status [mc "$type moved."]
	MarkDatabaseAsDirty
}


# ----------------------------------------------------------------------
# Delete a Login
# ----------------------------------------------------------------------
#

proc gorilla::DeleteLogin {} {
	ArrangeIdleTimeout

	if {[llength [set sel [$::gorilla::widgets(tree) selection]]] == 0} {
		return
	}

	set node [lindex $sel 0]
	set data [$::gorilla::widgets(tree) item $node -values]
	set type [lindex $data 0]
	set rn [lindex $data 1]

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
	set sel [$::gorilla::widgets(tree) selection]

	if {[llength $sel] == 0} {
		
		# No selection. Add to toplevel
		#
		gorilla::AddSubgroupToGroup ""
		
	} else {
		set node [lindex $sel 0]
		set data [$::gorilla::widgets(tree) item $node -values]
		set type [lindex $data 0]

		if {$type == "Group"} {
			gorilla::AddSubgroupToGroup [lindex $data 1]
		} elseif {$type == "Root"} {
			gorilla::AddSubgroupToGroup ""
		} else {
			
			# A login is selected. Add to its parent group.
			#
			set parent [$::gorilla::widgets(tree) parent $node]
			if {[string equal $parent "RootNode"]} {
				gorilla::AddSubgroupToGroup ""
			} else {
				set pdata [$::gorilla::widgets(tree) item $node -values]
				gorilla::AddSubgroupToGroup [lindex $pdata 1]
			}
		}
	}
}

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
			-title "No Database" \
			-message "Please create a new database, or open an existing\
			database first."
		return
	}

	set top .subgroupDialog

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top
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
		set but1 [ttk::button $top.buts.b1 -width 10 -text "OK" \
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
	grab $top

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
					-title "Invalid Group Name" \
					-message "The group name can not be empty."
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
				-title "Invalid Group Name" \
				-message "The name of the parent group is invalid."
			continue
		}

		break
	}

	if {$oldGrab != ""} {
		grab $oldGrab
	} else {
		grab release $top
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
# node6 to node3
#node7 node1
# menü move login erscheint nur, wenn ein Login angeklickt ist
# entsprechend MOVE GROUP nur, wenn tag group aktiviert ist

	if {$nodetype == "Root"} {
		tk_messageBox -parent . \
			-type ok -icon error -default ok \
			-title "Root Node Can Not Be Moved" \
			-message "The root node can not be moved."
return
	}

	set desttype [lindex $destdata 0]

	if {$desttype == "RootNode"} {
		set destgroup ""
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
			-title "Can Not Move Node" \
			-message "Can not move a group to a subgroup\
			of itself."
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

	if {[llength [set sel [$::gorilla::widgets(tree) selection]]] == 0} {
		return
	}

	set node [lindex $sel 0]
	set data [$::gorilla::widgets(tree) item $node -values]
	set type [lindex $data 0]

	if {$type == "Root"} {
		tk_messageBox -parent . \
			-type ok -icon error -default ok \
			-title "Can Not Delete Root" \
			-message "The root node can not be deleted."
		return
	}

	if {$type != "Group"} {
		error "oops"
	}

	set groupName [$::gorilla::widgets(tree) item $node -text]
	set fullGroupName [lindex $data 1]

	if {[llength [$::gorilla::widgets(tree) children $node]] > 0} {
		set answer [tk_messageBox -parent . \
			-type yesno -icon question -default no \
			-title "Delete Group" \
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

	if {[llength [set sel [$::gorilla::widgets(tree) selection]]] == 0} {
		return
	}

	set node [lindex $sel 0]
	set data [$::gorilla::widgets(tree) item $node -values]
	set type [lindex $data 0]

	if {$type == "Root"} {
		tk_messageBox -parent . \
			-type ok -icon error -default ok \
			-title "Can Not Rename Root" \
			-message "The root node can not be renamed."
		return
	}

	if {$type != "Group"} {
		error "oops"
	}

	set fullGroupName [lindex $data 1]
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
		toplevel $top
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

		ttk::labelframe $top.group -text "Name"
		ttk::entry $top.group.e -width 40 -textvariable ::gorilla::renameGroupName
		pack $top.group.e -side top -expand yes -fill x -pady 5 -padx 10
		pack $top.group -side top -expand yes -fill x -pady 5 -padx 10
		bind $top.group.e <Shift-Tab> "after 0 \"focus $top.parent.e\""

		set sep2 [ttk::separator $top.sep2 -orient horizontal]
		pack $sep2 -side top -fill x -pady 10

		ttk::frame $top.buts
		set but1 [ttk::button $top.buts.b1 -width 15 -text "OK" \
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
	grab $top

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
					-title "Invalid Group Name" \
					-message "The group name can not be empty."
				continue
		}

		if {[catch {
				set newParents [pwsafe::db::splitGroup $newParent]
		}]} {
				tk_messageBox -parent $top \
					-type ok -icon error -default ok \
					-title "Invalid Group Name" \
					-message "The name of the group's parent node\
					is invalid."
				continue
		}

		#
		# if we got this far, all is well
		#

		break
	}

	if {$oldGrab != ""} {
		grab $oldGrab
	} else {
		grab release $top
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
			-title "Can Not Move Node" \
			-message "Can not move a group to a subgroup\
			of itself."
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

		if {![info exists ::gorilla::preference(exportIncludePassword)]} {
	set ::gorilla::preference(exportIncludePassword) 0
		}

		if {![info exists ::gorilla::preference(exportIncludeNotes)]} {
	set ::gorilla::preference(exportIncludeNotes) 1
		}

		if {![info exists ::gorilla::preference(exportAsUnicode)]} {
	set ::gorilla::preference(exportAsUnicode) 0
		}

		if {![info exists ::gorilla::preference(exportFieldSeparator)]} {
	set ::gorilla::preference(exportFieldSeparator) ","
		}

		if {![info exists ::gorilla::preference(exportShowWarning)]} {
	set ::gorilla::preference(exportShowWarning) 1
		}

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
	if {$answer != "yes"} {
			return
	}
		}

		if {![info exists ::gorilla::dirName]} {
	set ::gorilla::dirName [pwd]
		}

		set types {
	{{Text Files} {.txt}}
	{{CSV Files} {.csv}}
	{{All Files} *}
		}

		set fileName [tk_getSaveFile -parent . \
			-title [mc "Export password database as text ..."] \
			-defaultextension ".txt" \
			-filetypes $types \
			-initialdir $::gorilla::dirName]

		if {$fileName == ""} {
	return
		}

		set nativeName [file nativename $fileName]

		set myOldCursor [. cget -cursor]
		. configure -cursor watch
		update idletasks

		if {[catch {
	set txtFile [open $fileName "w"]
		} oops]} {
	. configure -cursor $myOldCursor
	tk_messageBox -parent . -type ok -icon error -default ok \
			-title "Error Exporting Database" \
			-message "Failed to export password database to\
		$nativeName: $oops"
	return
		}

		set ::gorilla::status [mc "Exporting ..."]
		update idletasks

		if {$::gorilla::preference(exportAsUnicode)} {
	#
	# Write BOM in binary mode, then switch to Unicode
	#

	fconfigure $txtFile -encoding binary

	if {[info exists ::tcl_platform(byteOrder)]} {
			switch -- $::tcl_platform(byteOrder) {
		littleEndian {
				puts -nonewline $txtFile "\xff\xfe"
		}
		bigEndian {
				puts -nonewline $txtFile "\xfe\xff"
		}
			}
	}

	fconfigure $txtFile -encoding unicode
		}

		set separator [subst -nocommands -novariables $::gorilla::preference(exportFieldSeparator)]

		foreach rn [$::gorilla::db getAllRecordNumbers] {
	# UUID
	if {[$::gorilla::db existsField $rn 1]} {
			puts -nonewline $txtFile [$::gorilla::db getFieldValue $rn 1]
	}
	puts -nonewline $txtFile $separator
	# Group
	if {[$::gorilla::db existsField $rn 2]} {
			puts -nonewline $txtFile [$::gorilla::db getFieldValue $rn 2]
	}
	puts -nonewline $txtFile $separator
	# Title
	if {[$::gorilla::db existsField $rn 3]} {
			puts -nonewline $txtFile [$::gorilla::db getFieldValue $rn 3]
	}
	puts -nonewline $txtFile $separator
	# Username
	if {[$::gorilla::db existsField $rn 4]} {
			puts -nonewline $txtFile [$::gorilla::db getFieldValue $rn 4]
	}
	puts -nonewline $txtFile $separator
	# Password
	if {$::gorilla::preference(exportIncludePassword)} {
			if {[$::gorilla::db existsField $rn 6]} {
		puts -nonewline $txtFile [$::gorilla::db getFieldValue $rn 6]
			}
	} else {
			puts -nonewline $txtFile "********"
	}
	puts -nonewline $txtFile $separator
	if {$::gorilla::preference(exportIncludeNotes)} {
			if {[$::gorilla::db existsField $rn 5]} {
		puts -nonewline $txtFile \
				[string map {\\ \\\\ \" \\\" \t \\t \n \\n} \
			 [$::gorilla::db getFieldValue $rn 5]]
			}
	}
	puts $txtFile ""
		}

		catch {close $txtFile}
		. configure -cursor $myOldCursor
		set ::gorilla::status [mc "Database exported."]
}

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
# Save file
# ----------------------------------------------------------------------
#
# what with name1 name2 op?

proc gorilla::SavePercentTrace {name1 name2 op} {
	if {![info exists ::gorilla::savePercentLastUpdate]} {
		set ::gorilla::savePercentLastUpdate [clock clicks -milliseconds]
		return
	}

	set now [clock clicks -milliseconds]
	set td [expr {$now - $::gorilla::savePercentLastUpdate}]
	if {$td < 100} {
		return
	}

	set ::gorilla::savePercentLastUpdate $now

	if {$::gorilla::savePercent > 0} {
		set ::gorilla::status [format "Saving ... %2.0f %%" $::gorilla::savePercent]
		update idletasks
	}
}

# ----------------------------------------------------------------------
# Merge file
# ----------------------------------------------------------------------
#

variable gorilla::fieldNames [list "" \
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
	"last modification time"]

proc gorilla::Merge {} {
	set openInfo [OpenDatabase [mc "Merge Password Database" "" 0]]
	# set openInfo [OpenDatabase "Merge Password Database" "" 0]
	# enthält [list $fileName $newdb]
	
	set action [lindex $openInfo 0]

	if {$action != "Open"} {
		return
	}

	set ::gorilla::status [mc "Merging "]

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

	foreach nrn [$newdb getAllRecordNumbers] {
		incr totalLogins

		set percent [expr {int(100.*$totalLogins/$totalRecords)}]
		set ::gorilla::status "Merging ($percent% done) ..."
		update idletasks

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

				set title ""
				set user ""

				if {[$::gorilla::db existsField $rn 3]} {
					set title [$::gorilla::db getFieldValue $rn 3]
				}

				if {[$::gorilla::db existsField $rn 4]} {
					set user [$::gorilla::db getFieldValue $rn 4]
				}

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
			set rn [$::gorilla::db createRecord]

			foreach field [$newdb getFieldsForRecord $nrn] {
				$::gorilla::db setFieldValue $rn $field \
				[$newdb getFieldValue $nrn $field]
			}

			set node [AddRecordToTree $rn]

			if {$found && !$identical} {
				#
				# Remember that there was a conflict
				#

				lappend conflictNodes $node

				set report "Conflict for login $ntitle"
				if {$ngroup != ""} {
					append report " (in group $ngroup)"
				}
				append report ": " $reason "."
				lappend conflictReport $report

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
				set report "Added login $ntitle"
				if {$ngroup != ""} {
					append report " (in Group $ngroup)"
				}
				append report "."
				lappend addedReport $report
			}
		} else {
			incr identicalLogins
			set report "Identical login $ntitle"
			if {$ngroup != ""} {
				append report " (in Group $ngroup)"
			}
			append report "."
			lappend identicalReport $report
		}

		pwsafe::int::randomizeVar ngroup ntitle nuser
	}

	itcl::delete object $newdb
	MarkDatabaseAsDirty

	set numAddedLogins [llength $addedNodes]
	set numConflicts [llength $conflictNodes]

	set message "Merged "
	append message $nativeName "; " $totalLogins " "

	if {$totalLogins == 1} {
		append message "login, "
	} else {
		append message "logins, "
	}

	append message $identicalLogins " identical, "
	append message $numAddedLogins " added, "
	append message $numConflicts " "

	if {$numConflicts == 1} {
		append message "conflict."
	} else {
		append message "conflicts."
	}

	set ::gorilla::status $message

	if {$numConflicts > 0} {
		set default "yes"
		set icon "warning"
	} else {
		set default "no"
		set icon "info"
	}

	set answer [tk_messageBox -parent . -type yesno \
		-icon $icon -default $default \
		-title "Merge Results" \
		-message "$message Do you want to view a\
		detailed report?"]

	if {$answer != "yes"} {
		return
	}

	set ttop ".mergeReport"

	if {![winfo exists $ttop]} {
		toplevel $ttop
		wm title $ttop "Merge Report for $nativeName"

		set text [text $ttop.text -relief sunken -width 100 -wrap none \
		-yscrollcommand "$ttop.vsb set"]

		if {[tk windowingsystem] ne "aqua"} {
			ttk::scrollbar $ttop.vsb -orient vertical -command "$ttop.text yview"
		} else {
			scrollbar $ttop.vsb -orient vertical -command "$ttop.text yview"
		}
		## Arrange the tree and its scrollbars in the toplevel
		lower [ttk::frame $ttop.dummy]
		pack $ttop.dummy -fill both -fill both -expand 1
		grid $ttop.text $ttop.vsb -sticky nsew -in $ttop.dummy
		grid columnconfigure $ttop.dummy 0 -weight 1
		grid rowconfigure $ttop.dummy 0 -weight 1
		
		set botframe [ttk::frame $ttop.botframe]
		set botbut [ttk::button $botframe.but -width 10 -text [mc "Close"] \
			-command "destroy $ttop"]
		pack $botbut
		pack $botframe -side top -fill x -pady 10
		
		bind $ttop <Prior> "$text yview scroll -1 pages; break"
		bind $ttop <Next> "$text yview scroll 1 pages; break"
		bind $ttop <Up> "$text yview scroll -1 units"
		bind $ttop <Down> "$text yview scroll 1 units"
		bind $ttop <Home> "$text yview moveto 0"
		bind $ttop <End> "$text yview moveto 1"
		bind $ttop <Return> "destroy $ttop"
		} else {
			wm deiconify $ttop
			set text "$ttop.text"
			set botframe "$ttop.botframe"
		}

		$text configure -state normal
		$text delete 1.0 end

		$text insert end $message
		$text insert end "\n\n"

		$text insert end [string repeat "-" 70]
		$text insert end "\n"
		$text insert end "Conflicts\n"
		$text insert end [string repeat "-" 70]
		$text insert end "\n"
		$text insert end "\n"
		if {[llength $conflictReport] > 0} {
			foreach report $conflictReport {
				$text insert end $report
				$text insert end "\n"
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
				$text insert end $report
				$text insert end "\n"
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
		wm deiconify $ttop
		raise $ttop
		focus $botframe.but
}


proc gorilla::Save {} {
	ArrangeIdleTimeout

	set myOldCursor [. cget -cursor]
	. configure -cursor watch
	update idletasks

	#
	# Create backup file, if desired
	#

	if {[info exists ::gorilla::preference(keepBackupFile)] && \
			$::gorilla::preference(keepBackupFile)} {
		set backupFileName [file rootname $::gorilla::fileName]
		append backupFileName ".bak"
		if {[catch {
			file copy -force -- $::gorilla::fileName $backupFileName
			} oops]} {
			. configure -cursor $myOldCursor
			set backupNativeName [file nativename $backupFileName]
			tk_messageBox -parent . -type ok -icon error -default ok \
				-title "Error Saving Database" \
				-message "Failed to make backup copy of password \
				database as $backupNativeName: $oops"
			return 0
		}
	}

	set nativeName [file nativename $::gorilla::fileName]
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
	set ::gorilla::savePercent 0
	trace add variable ::gorilla::savePercent [list "write"] ::gorilla::SavePercentTrace

	# verhindert einen grauen Fleck bei Speichervorgang
	update

	if {[catch {pwsafe::writeToFile $::gorilla::db $nativeName $majorVersion \
	::gorilla::savePercent} oops]} {
		trace remove variable ::gorilla::savePercent [list "write"] \
				::gorilla::SavePercentTrace
		unset ::gorilla::savePercent

		. configure -cursor $myOldCursor
		tk_messageBox -parent . -type ok -icon error -default ok \
			-title "Error Saving Database" \
			-message "Failed to save password database as\
			$nativeName: $oops"
		return 0
	}

	trace remove variable ::gorilla::savePercent [list "write"] \
		::gorilla::SavePercentTrace
	unset ::gorilla::savePercent

	. configure -cursor $myOldCursor
	# set ::gorilla::status [mc "Password database saved as $nativeName"] 
	set ::gorilla::status [mc "Password database saved."] 
	set ::gorilla::dirty 0
	$::gorilla::widgets(tree) item "RootNode" -tags black

	UpdateMenu
	return 1
}

#
# ----------------------------------------------------------------------
# Save As
# ----------------------------------------------------------------------
#

proc gorilla::SaveAs {} {
		ArrangeIdleTimeout

		if {![info exists ::gorilla::db]} {
			tk_messageBox -parent . -type ok -icon error -default ok \
				-title "Nothing To Save" \
				-message "No password database to save."
	return 1
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

		set types {
	{{Password Database Files} {.psafe3 .dat}}
	{{All Files} *}
		}

		if {![info exists ::gorilla::dirName]} {
	set ::gorilla::dirName [pwd]
		}

		set fileName [tk_getSaveFile -parent . \
			-title "Save password database ..." \
			-defaultextension $defaultExtension \
			-filetypes $types \
			-initialdir $::gorilla::dirName]

		if {$fileName == ""} {
	return 0
		}

		# Dateiname auf Default Extension testen
		# -defaultextension funktioniert nur auf Windowssystemen
		set fileName [gorilla::CheckDefaultExtension $fileName $defaultExtension]
		set nativeName [file nativename $fileName]
	
		
		set myOldCursor [. cget -cursor]
		. configure -cursor watch
		update idletasks

		#
		# Create backup file, if desired
		#

		if {[info exists ::gorilla::preference(keepBackupFile)] && \
			$::gorilla::preference(keepBackupFile) && \
			[file exists $fileName]} {
	set backupFileName [file rootname $fileName]
	append backupFileName ".bak"
	set ::gorilla::status $backupFileName
	if {[catch {
			file copy -force -- $fileName $backupFileName
	} oops]} {
			. configure -cursor $myOldCursor
			set backupNativeName [file nativename $backupFileName]
			tk_messageBox -parent . -type ok -icon error -default ok \
				-title "Error Saving Database" \
				-message "Failed to make backup copy of password \
				database as $backupNativeName: $oops"
			return 0
	}
		}

		set ::gorilla::savePercent 0
		trace add variable ::gorilla::savePercent [list "write"] \
	::gorilla::SavePercentTrace

		if {[catch {
	pwsafe::writeToFile $::gorilla::db $fileName $majorVersion ::gorilla::savePercent
		} oops]} {
	trace remove variable ::gorilla::savePercent [list "write"] \
			::gorilla::SavePercentTrace
	unset ::gorilla::savePercent

	. configure -cursor $myOldCursor
	tk_messageBox -parent . -type ok -icon error -default ok \
		-title "Error Saving Database" \
		-message "Failed to save password database as\
		$nativeName: $oops"
	return 0
		}

		trace remove variable ::gorilla::savePercent [list "write"] \
	::gorilla::SavePercentTrace
		unset ::gorilla::savePercent

		. configure -cursor $myOldCursor
		set ::gorilla::dirty 0
		$::gorilla::widgets(tree) item "RootNode" -tags black
		set ::gorilla::fileName $fileName
		wm title . "Password Gorilla - $nativeName"
		$::gorilla::widgets(tree) item "RootNode" -text $nativeName
		set ::gorilla::status "Password database saved as $nativeName"

		#
		# Add file to LRU preference
		#

		if {[info exists ::gorilla::preference(lru)]} {
			set found [lsearch -exact $::gorilla::preference(lru) $nativeName]
				if {$found == -1} {
					set ::gorilla::preference(lru) [linsert $::gorilla::preference(lru) 0 $nativeName]
				} elseif {$found != 0} {
					set tmp [lreplace $::gorilla::preference(lru) $found $found]
					set ::gorilla::preference(lru) [linsert $tmp 0 $nativeName]
				}
		} else {
			set ::gorilla::preference(lru) [list $nativeName]
		}
	UpdateMenu
	$::gorilla::widgets(tree) item "RootNode" -tags black
	return 1
}


# ----------------------------------------------------------------------
# Edit a Login
# ----------------------------------------------------------------------

proc gorilla::DestroyLoginDialog {} {
	set ::gorilla::guimutex 2
}

proc gorilla::LoginDialog {rn} {
	ArrangeIdleTimeout

	#
	# Set up dialog
	#

	set top .loginDialog

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top
		TryResizeFromPreference $top
		wm title $top [mc "Add/Edit/View Login"]

		frame $top.l
		
		foreach {child childname} {
			group Group title Title url URL user Username pass Password} {
			set kind1 [join "$top.l.$child 1" ""]
			set kind2 [join "$top.l.$child 2" ""]
			set entry_text ::gorilla::$top.l.$child.e
			ttk::label $kind1 -text [mc "$childname:"] -width 12 -anchor w 
			ttk::entry $kind2 -width 40 -textvariable ::gorilla::loginDialog.$child
			grid $kind1 $kind2 -sticky nsew -pady 5
		}

		ttk::label $top.l.label_notes -width 12 -text [mc "Notes:"] -anchor w
		text $top.l.notes -width 40 -height 5 -wrap word
		grid $top.l.label_notes $top.l.notes -sticky nsew -pady 5

		ttk::label $top.l.lpwc -text [mc "Last Password Change:"] -width 20 -anchor w
		ttk::label $top.l.lpwc_info -text "" -width 40 -anchor w
		grid $top.l.lpwc $top.l.lpwc_info -sticky nsew -pady 5

		ttk::label $top.l.mod -text [mc "Last Modified:"] -width 20 -anchor w
		ttk::label $top.l.mod_info -text "" -width 40 -anchor w
		grid $top.l.mod $top.l.mod_info -sticky nsew -pady 5

		frame $top.r				;# frame right
		frame $top.r.top
		ttk::button $top.r.top.ok -width 16 -text "OK" -command "set ::gorilla::guimutex 1"
		ttk::button $top.r.top.c -width 16 -text [mc "Cancel"] \
			-command "set ::gorilla::guimutex 2"
		pack $top.r.top.ok $top.r.top.c -side top -padx 10 -pady 5
		pack $top.r.top -side top -pady 20

		frame $top.r.pws
		ttk::button $top.r.pws.show -width 16 -text [mc "Show Password"] \
			-command "set ::gorilla::guimutex 3"
		ttk::button $top.r.pws.gen -width 16 -text [mc "Generate Password"] \
			-command "set ::gorilla::guimutex 4"
		ttk::checkbutton $top.r.pws.override -text [mc "Override Password Policy"] \
			-variable ::gorilla::overridePasswordPolicy 
			# -justify left
		pack $top.r.pws.show $top.r.pws.gen $top.r.pws.override \
			-side top -padx 10 -pady 5
		pack $top.r.pws -side top -pady 20

		pack $top.l -side left -expand yes -pady 10 -padx 15
		pack $top.r -side right -fill both
	
		#
		# Set up bindings
		#

		bind $top.l.group2 <Shift-Tab> "after 0 \"focus $top.r.top.ok\""
		bind $top.l.title2 <Shift-Tab> "after 0 \"focus $top.l.group2\""
		bind $top.l.user2 <Shift-Tab> "after 0 \"focus $top.l.title2\""
		bind $top.l.pass2 <Shift-Tab> "after 0 \"focus $top.l.user2\""
		bind $top.l.notes <Tab> "after 0 \"focus $top.r.top.ok\""
		bind $top.l.notes <Shift-Tab> "after 0 \"focus $top.l.pass2\""

		bind $top.l.group2 <Return> "set ::gorilla::guimutex 1"
		bind $top.l.title2 <Return> "set ::gorilla::guimutex 1"
		bind $top.l.user2 <Return> "set ::gorilla::guimutex 1"
		bind $top.l.pass2 <Return> "set ::gorilla::guimutex 1"
		bind $top.r.top.ok <Return> "set ::gorilla::guimutex 1"
		bind $top.r.top.c <Return> "set ::gorilla::guimutex 2"

		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW gorilla::DestroyLoginDialog
	} else {
		wm deiconify $top
	}

		#
		# Configure dialog
		#
		# Die textvariable für das entry muss global sein!!!
		set ::gorilla::loginDialog.group ""
		set ::gorilla::loginDialog.title ""
		set ::gorilla::loginDialog.url ""
		set ::gorilla::loginDialog.user ""
		set ::gorilla::loginDialog.pass ""
		$top.l.notes delete 1.0 end
		$top.l.lpwc_info configure -text "<unknown>"
		$top.l.mod_info configure -text "<unknown>"

		if {[$::gorilla::db existsRecord $rn]} {
			if {[$::gorilla::db existsField $rn 2]} {
				set ::gorilla::loginDialog.group	[$::gorilla::db getFieldValue $rn 2]
			}
			if {[$::gorilla::db existsField $rn 3]} {
				set ::gorilla::loginDialog.title [$::gorilla::db getFieldValue $rn 3]
			}
			if {[$::gorilla::db existsField $rn 4]} {
				set ::gorilla::loginDialog.user [$::gorilla::db getFieldValue $rn 4]
			}
			if {[$::gorilla::db existsField $rn 5]} {
				$top.l.notes insert 1.0 [$::gorilla::db getFieldValue $rn 5]
			}
			if {[$::gorilla::db existsField $rn 6]} {
				set ::gorilla::loginDialog.pass [$::gorilla::db getFieldValue $rn 6]
			}
			if {[$::gorilla::db existsField $rn 8]} {
				$top.l.lpwc_info configure -text \
					[clock format [$::gorilla::db getFieldValue $rn 8] \
					-format "%Y-%m-%d %H:%M:%S"]
			}
			if {[$::gorilla::db existsField $rn 12]} {
				$top.l.mod_info configure -text \
					[clock format [$::gorilla::db getFieldValue $rn 12] \
					-format "%Y-%m-%d %H:%M:%S"]
			}
			if {[$::gorilla::db existsField $rn 13]} {
				set ::gorilla::loginDialog.url [$::gorilla::db getFieldValue $rn 13]
			}
		}

		if {[$::gorilla::db existsRecord $rn] && [$::gorilla::db existsField $rn 6]} {
			$top.l.pass2 configure -show "*"
			$top.r.pws.show configure -text [mc "Show Password"]
		} else {
			$top.l.pass2 configure -show ""
			$top.r.pws.show configure -text [mc "Hide Password"]
		}

		if {![info exists ::gorilla::overriddenPasswordPolicy]} {
			set ::gorilla::overriddenPasswordPolicy [GetDefaultPasswordPolicy]
		}

		if {[$::gorilla::db hasHeaderField 0] && [lindex [$::gorilla::db getHeaderField 0] 0] >= 3} {
			$top.l.url2 configure -state normal
		} else {
			# Version 2 does not have a separate URL field
			set ::gorilla::loginDialog.url "(Not available with v2 database format.)"
			$top.l.url2 configure -state disabled
		}

		#
		# Run dialog
		#

		set oldGrab [grab current .]

		update idletasks
		raise $top
		focus $top.l.title2
		grab $top

		while {42} {
			ArrangeIdleTimeout
			set ::gorilla::guimutex 0
			vwait ::gorilla::guimutex

			if {$::gorilla::guimutex == 1} {
				if {[$top.l.title2 get] == ""} {
					tk_messageBox -parent $top \
						-type ok -icon error -default ok \
						-title "Login Needs Title" \
						-message "A login must at least have a title.\
						Please enter a title for this login."
					continue
				}
				if {[ catch {pwsafe::db::splitGroup [$top.l.group2 get]} ]} {
					tk_messageBox -parent $top \
						-type ok -icon error -default ok \
						-title "Invalid Group Name" \
						-message "This login's group name is not valid."
					continue
				}
				break
			} elseif {$::gorilla::guimutex == 2} {
				break
			} elseif {$::gorilla::guimutex == 3} {
				#
				# Show Password
				#
				set show [$top.l.pass2 cget -show]
				if {$show == ""} {
					$top.l.pass2 configure -show "*"
					$top.r.pws.show configure -text [mc "Show Password"]
				} else {
					$top.l.pass2 configure -show ""
					$top.r.pws.show configure -text [mc "Hide Password"]
				}
			} elseif {$::gorilla::guimutex == 4} {
				#
				# Generate Password
				#
				if {$::gorilla::overridePasswordPolicy} {
					set settings [PasswordPolicyDialog \
						[mc "Override Password Policy"] \
						$::gorilla::overriddenPasswordPolicy]
					if {[llength $settings] == 0} {
						continue
					}
					set ::gorilla::overriddenPasswordPolicy $settings
				} else {
					set settings [GetDefaultPasswordPolicy]
				}
				if {[catch {set newPassword [GeneratePassword $settings]} oops]} {
					tk_messageBox -parent $top \
						-type ok -icon error -default ok \
						-title "Invalid Password Settings" \
						-message "The password policy settings are invalid."
					continue
				}
				set ::gorilla::loginDialog.pass $newPassword
				pwsafe::int::randomizeVar newPassword
			}
		}

		if {$oldGrab != ""} {
			grab $oldGrab
		} else {
			grab release $top
		}

		wm withdraw $top

		#
		# Canceled?
		#

		if {$::gorilla::guimutex != 1} {
			set ::gorilla::loginDialog.group ""
			set ::gorilla::loginDialog.url ""
			set ::gorilla::loginDialog.title ""
			set ::gorilla::loginDialog.user ""
			set ::gorilla::loginDialog.pass ""
			$top.l.notes delete 1.0 end
			return 0
		}

		#
		# Store fields in the database
		#

		set modified 0
		set now [clock seconds]

		set group [$top.l.group2 get]
		if {$group != ""} {
			if {![$::gorilla::db existsField $rn 2] || \
				![string equal $group [$::gorilla::db getFieldValue $rn 2]]} {
				set modified 1
			}
			$::gorilla::db setFieldValue $rn 2 $group
		} elseif {[$::gorilla::db existsField $rn 2]} {
			$::gorilla::db unsetFieldValue $rn 2
			set modified 1
		}
		set ::gorilla::loginDialog.group ""
		pwsafe::int::randomizeVar group

		set title [$top.l.title2 get]
		if {$title != ""} {
			if {![$::gorilla::db existsField $rn 3] || \
				![string equal $title [$::gorilla::db getFieldValue $rn 3]]} {
				set modified 1
			}
			$::gorilla::db setFieldValue $rn 3 $title
		} elseif {[$::gorilla::db existsField $rn 3]} {
			$::gorilla::db unsetFieldValue $rn 3
			set modified 1
		}
		set ::gorilla::loginDialog.title ""
		pwsafe::int::randomizeVar title

		set user [$top.l.user2 get]
		if {$user != ""} {
			if {![$::gorilla::db existsField $rn 4] || \
				![string equal $user [$::gorilla::db getFieldValue $rn 4]]} {
				set modified 1
			}
			$::gorilla::db setFieldValue $rn 4 $user
		} elseif {[$::gorilla::db existsField $rn 4]} {
			$::gorilla::db unsetFieldValue $rn 4
			set modified 1
		}
		set ::gorilla::loginDialog.user ""
		pwsafe::int::randomizeVar user

		set pass [$top.l.pass2 get]
		if {$pass != ""} {
			if {![$::gorilla::db existsField $rn 6] || \
				![string equal $pass [$::gorilla::db getFieldValue $rn 6]]} {
				set modified 1
				$::gorilla::db setFieldValue $rn 8 $now ;# PW mod time
			}
			$::gorilla::db setFieldValue $rn 6 $pass
		} elseif {[$::gorilla::db existsField $rn 6]} {
			$::gorilla::db unsetFieldValue $rn 6
			set modified 1
		}
		pwsafe::int::randomizeVar pass
		set ::gorilla::loginDialog.pass ""

		set notes [string trim [$top.l.notes get 1.0 end]]
		if {$notes != ""} {
			if {![$::gorilla::db existsField $rn 5] || \
				![string equal $notes [$::gorilla::db getFieldValue $rn 5]]} {
				set modified 1
			}
			$::gorilla::db setFieldValue $rn 5 $notes
		} elseif {[$::gorilla::db existsField $rn 5]} {
			$::gorilla::db unsetFieldValue $rn 5
			set modified 1
		}
		$top.l.notes delete 1.0 end
		pwsafe::int::randomizeVar notes

		if {[$top.l.url2 cget -state] == "normal"} {
			set url [$top.l.url2 get]

			if {$url != ""} {
				if {![$::gorilla::db existsField $rn 13] || \
					![string equal $url [$::gorilla::db getFieldValue $rn 13]]} {
					set modified 1
					$::gorilla::db setFieldValue $rn 8 $now ;# PW mod time
				}
				$::gorilla::db setFieldValue $rn 13 $url
			} elseif {[$::gorilla::db existsField $rn 13]} {
				$::gorilla::db unsetFieldValue $rn 13
				set modified 1
			}
			pwsafe::int::randomizeVar url
		}
		set ::gorilla::loginDialog.url ""

		if {$modified} {
			$::gorilla::db setFieldValue $rn 12 $now
		}

		return $modified
}

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
		if {[$::gorilla::db existsField $rn 2]} {
	set groupName [$::gorilla::db getFieldValue $rn 2]
		} else {
	set groupName ""
		}

		set parentNode [AddGroupToTree $groupName]

		if {[$::gorilla::db existsField $rn 3]} {
	set title [$::gorilla::db getFieldValue $rn 3]
		} else {
	set title ""
		}

		if {[$::gorilla::db existsField $rn 4]} {
	append title " \[" [$::gorilla::db getFieldValue $rn 4] "\]"
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


#
# Update Menu items
#


proc gorilla::UpdateMenu {} {
	set selection [$::gorilla::widgets(tree) selection]
	
	if {[llength $selection] == 0} {
		setmenustate $::gorilla::widgets(main) group disabled
		setmenustate $::gorilla::widgets(main) login disabled
	} else {
		set node [lindex $selection 0]
		set data [$::gorilla::widgets(tree) item $node -values]
		set type [lindex $data 0]

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
		-message [ mc "The current password database is modified.\
		Do you want to save the database?\n\
		\"Yes\" saves the database, and exits.\n\
		\"No\" discards all changes, and exits.\n\
		\"Cancel\" returns to the main menu."]]
		if {$answer == "yes"} {
			if {[info exists ::gorilla::fileName]} {
				if {![::gorilla::Save]} {
					set ::gorilla::exiting 0
				}
			} else {
				if {![::gorilla::SaveAs]} {
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

proc gorilla::CopyUsername {} {
		ArrangeIdleTimeout
		clipboard clear
		clipboard append -- [::gorilla::GetSelectedUsername]
		set ::gorilla::activeSelection 1
		selection clear
		selection own .
		ArrangeToClearClipboard
		set ::gorilla::status [mc "Copied user name to clipboard."]
}

proc gorilla::CopyURL {} {
	ArrangeIdleTimeout
	clipboard clear
	set URL [gorilla::GetSelectedURL]

	if {$URL == ""} {
		set ::gorilla::status [mc "Can not copy URL to clipboard: no URL defined."]
	} else {
		clipboard append -- $URL
		set ::gorilla::activeSelection 3
		selection clear
		selection own .
		ArrangeToClearClipboard
		set ::gorilla::status [mc "Copied URL to clipboard."]
	}
}


# ----------------------------------------------------------------------
# Clear clipboard
# ----------------------------------------------------------------------
#

proc gorilla::ClearClipboard {} {
	clipboard clear
	clipboard append -- ""

	if {[selection own] == "."} {
		selection clear
	}

	set ::gorilla::activeSelection 0
	set ::gorilla::status [mc "Clipboard cleared."]
	catch {unset ::gorilla::clipboardClearId}
}

# ----------------------------------------------------------------------
# Clear the clipboard after a configurable number of seconds
# ----------------------------------------------------------------------
#

proc gorilla::ArrangeToClearClipboard {} {
	if {[info exists ::gorilla::clipboardClearId]} {
		after cancel $::gorilla::clipboardClearId
	}

	if {![info exists ::gorilla::preference(clearClipboardAfter)] || \
		$::gorilla::preference(clearClipboardAfter) == 0} {
		catch {unset ::gorilla::clipboardClearId}
		return
	}

	set seconds $::gorilla::preference(clearClipboardAfter)
	set mseconds [expr {$seconds * 1000}]
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

	# close all open windows and remember their status
	foreach tl [array names ::gorilla::toplevel] {
		set ws [wm state $tl]
		switch -- $ws {
			normal -
			iconic -
			zoomed {
				set withdrawn($tl) $ws
				wm withdraw $tl
			}
		}
	}
	
	# Ist es wirklich notwendig, die Submenüs zu deaktivieren?
	# $::gorilla::widgets(main) setmenustate all disabled
	
	set top .lockedDialog
	if {![info exists ::gorilla::toplevel($top)]} {
	toplevel $top
	TryResizeFromPreference $top

	ttk::label $top.splash -image $::gorilla::images(splash)
	pack $top.splash -side left -fill both

	ttk::separator $top.vsep -orient vertical
	pack $top.vsep -side left -fill y -padx 3

	set aframe [ttk::frame $top.right]
	ttk::label $aframe.title -anchor center
	pack $aframe.title -side top -fill x -pady 10

	set sep1 [ttk::separator $aframe.sep1 -orient horizontal]
	pack $sep1 -side top -fill x -pady 10

	ttk::frame $aframe.file
	ttk::label $aframe.file.l -text [mc "Database:"] -width 12
	ttk::entry $aframe.file.f -width 50 -state disabled
	pack $aframe.file.l -side left -padx 5
	pack $aframe.file.f -side left -padx 5 -fill x -expand yes
	pack $aframe.file -side top -pady 5 -fill x -expand yes

	ttk::frame $aframe.pw
	ttk::label $aframe.pw.l -text [mc "Password:"] -width 12 
	# ttk::entry $aframe.pw.pw -width 20 -show "*" -font {Courier}
	ttk::entry $aframe.pw.pw -width 20 -show "*"
	pack $aframe.pw.l -side left -padx 5
	pack $aframe.pw.pw -side left -padx 5 -fill x -expand yes
	pack $aframe.pw -side top -pady 5 -fill x -expand yes

	set sep2 [ttk::separator $aframe.sep2 -orient horizontal]
	pack $sep2 -side top -fill x -pady 10

	ttk::frame $aframe.buts
	set but1 [ttk::button $aframe.buts.b1 -width 15 -text "OK" \
		-command "set ::gorilla::lockedMutex 1"]
	set but2 [ttk::button $aframe.buts.b2 -width 15 -text [mc "Exit"] \
		-command "set ::gorilla::lockedMutex 2"]
	pack $but1 $but2 -side left -pady 10 -padx 20
	pack $aframe.buts -side top

	ttk::label $aframe.info -relief sunken -anchor w -padding [list 5 5 5 5]
	pack $aframe.info -side top -fill x -expand yes

	bind $aframe.pw.pw <Return> "set ::gorilla::lockedMutex 1"
	bind $aframe.buts.b1 <Return> "set ::gorilla::lockedMutex 1"
	bind $aframe.buts.b2 <Return> "set ::gorilla::lockedMutex 2"
	pack $aframe -side right -fill both -expand yes

	set ::gorilla::toplevel($top) $top
	wm protocol $top WM_DELETE_WINDOW gorilla::CloseLockedDatabaseDialog
		} else {
	set aframe $top.right
	wm deiconify $top
		}

		wm title $top "Password Gorilla"
		$aframe.title configure -text  [mc "Database Locked"]
		$aframe.pw.pw delete 0 end
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

		focus $aframe.pw.pw
		if {[catch { grab $top } oops]} {
			set ::gorilla::status "error: $oops"
		}
		
		while {42} {
	set ::gorilla::lockedMutex 0
	vwait ::gorilla::lockedMutex

	if {$::gorilla::lockedMutex == 1} {
			if {[$::gorilla::db checkPassword [$aframe.pw.pw get]]} {
		break
			}

			tk_messageBox -parent $top \
		-type ok -icon error -default ok \
		-title "Wrong Password" \
		-message "That password is not correct."
	} elseif {$::gorilla::lockedMutex == 2} {
			#
			# This may return, if the database was modified, and the user
			# answers "Cancel" to the question whether to save the database
			# or not.
			#

			Exit
	}
		}

		foreach tl [array names withdrawn] {
	wm state $tl $withdrawn($tl)
		}

		if {$oldGrab != ""} {
	grab $oldGrab
		} else {
	grab release $top
		}

		# $::gorilla::widgets(main) setmenustate all normal

		wm withdraw $top
		set ::gorilla::status [mc "Welcome back."]

		set ::gorilla::isLocked 0

		wm deiconify .
		raise .

		ArrangeIdleTimeout
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
		toplevel $top

		TryResizeFromPreference $top

		ttk::labelframe $top.password -text $title -padding [list 10 10]
		ttk::entry $top.password.e -show "*" -width 30 -textvariable ::gorilla::passwordDialog.pw

		pack $top.password.e -side left
		pack $top.password -fill x -pady 15 -padx 15
		
		bind $top.password.e <KeyPress> "+::gorilla::CollectTicks"
		bind $top.password.e <KeyRelease> "+::gorilla::CollectTicks"

		if {$confirm} {
			ttk::labelframe $top.confirm -text [mc "Confirm:"] -padding [list 10 10]
			ttk::entry $top.confirm.e -show "*" -width 30 -textvariable ::gorilla::passwordDialog.c
			pack $top.confirm.e -side left
			pack $top.confirm -fill x -pady 5 -padx 15

			bind $top.confirm.e <KeyPress> "+::gorilla::CollectTicks"
			bind $top.confirm.e <KeyRelease> "+::gorilla::CollectTicks"
			bind $top.confirm.e <Shift-Tab> "after 0 \"focus $top.password.e\""
		}

		ttk::frame $top.buts
		set but1 [ttk::button $top.buts.b1 -width 10 -text OK \
			-command "set ::gorilla::guimutex 1"]
		set but2 [ttk::button $top.buts.b2 -width 10 -text [mc "Cancel"] \
			-command "set ::gorilla::guimutex 2"]
		pack $but1 $but2 -side left -pady 15 -padx 30
		pack $top.buts
		
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
		grab $top

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
			grab $oldGrab
		} else {
			grab release $top
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
		-title "No Database" \
		-message "Please create a new database, or open an existing\
		database first."
	return
		}

		set oldSettings [GetDefaultPasswordPolicy]
		set newSettings [PasswordPolicyDialog "Password Policy" $oldSettings]

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

		set oldGrab [grab current .]

		update idletasks
		wm title $top $title
		raise $top
		focus $top.plen.s
		grab $top

		set ::gorilla::guimutex 0
		vwait ::gorilla::guimutex

		if {$oldGrab != ""} {
	grab $oldGrab
		} else {
	grab release $top
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
		toplevel $top
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

		ttk::frame $top.stretch -padding [list 10 5]
		spinbox $top.stretch.spin -from 2048 -to 65535 -increment 256 \
				-justify right -width 8 \
				-textvariable ::gorilla::dpd(keyStretchingIterations)
		ttk::label $top.stretch.label -text [mc "V3 key stretching iterations"]
		pack $top.stretch.spin $top.stretch.label -side left -padx 3
		pack $top.stretch -anchor w -side top

		ttk::separator $top.sep -orient horizontal
		pack $top.sep -side top -fill x -pady 10

		ttk::frame $top.buts
		set but1 [ttk::button $top.buts.b1 -width 15 -text "OK" \
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
	grab $top

	set ::gorilla::guimutex 0
	vwait ::gorilla::guimutex

	if {$oldGrab != ""} {
		grab $oldGrab
	} else {
		grab release $top
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
}

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

	foreach {pref default} {
		clearClipboardAfter 0 \
		defaultVersion 3 \
		doubleClickAction nothing \
		exportAsUnicode 0 \
		exportFieldSeparator "," \
		exportIncludeNotes 0 \
		exportIncludePassword 0 \
		exportShowWarning 1 \
		idleTimeoutDefault 5 \
		keepBackupFile 0 \
		lruSize 10 \
		lockDatabaseAfter 0 \
		rememberGeometries 1 \
		saveImmediatelyDefault 0 \
		unicodeSupport 1} {
		if {[info exists ::gorilla::preference($pref)]} {
			set ::gorilla::prefTemp($pref) $::gorilla::preference($pref)
		} else {
			set ::gorilla::prefTemp($pref) $default
		}
	}

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top
		TryResizeFromPreference $top
		wm title $top [mc "Preferences"]

		ttk::notebook $top.nb

#
# First NoteBook tab: general preferences
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
ttk::radiobutton $gpf.dca.nop -text [mc "Do nothing"] \
	-variable ::gorilla::prefTemp(doubleClickAction) \
	-value "nothing"
pack $gpf.dca.cp $gpf.dca.ed $gpf.dca.nop -side top -anchor w -pady 3
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
pack $gpf.bu $gpf.geo -side top -anchor w -padx 10 -pady 5

#
# Second NoteBook tab: database defaults
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

pack $dpf.si $dpf.ver $dpf.uni -side top -anchor w -pady 3 -padx 10

ttk::label $dpf.note -justify center -anchor w -wraplen 300 \
	-text [mc "Note: these defaults will be applied to\
	new databases. To change a setting for an existing\
	database, go to \"Database Preferences\" in the \"Manage\"\
	menu."]
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
ttk::checkbutton $epf.unicode -text [mc "Save as Unicode text file"] \
		-variable ::gorilla::prefTemp(exportAsUnicode) 
		
ttk::frame $epf.fs
ttk::label $epf.fs.l -text [mc "Field separator"] -width 16 -anchor w
ttk::entry $epf.fs.e	 \
		-textvariable ::gorilla::prefTemp(exportFieldSeparator) \
	 -width 4 
pack $epf.fs.l $epf.fs.e -side left
ttk::checkbutton $epf.warning -text [mc "Show security warning"] \
		-variable ::gorilla::prefTemp(exportShowWarning) 
		
pack $epf.password $epf.notes $epf.unicode $epf.warning $epf.fs \
	-anchor w -side top -pady 3

#
# End of NoteBook tabs
#

# $top.nb compute_size
# $top.nb raise gpf
pack $top.nb -side top -fill both -expand yes -pady 10

#
# Bottom
#

# Separator $top.sep -orient horizontal
# pack $top.sep -side top -fill x -pady 7

frame $top.buts
set but1 [button $top.buts.b1 -width 15 -text "OK" \
	-command "set ::gorilla::guimutex 1"]
set but2 [button $top.buts.b2 -width 15 -text [mc "Cancel"] \
	-command "set ::gorilla::guimutex 2"]
pack $but1 $but2 -side left -pady 10 -padx 20
pack $top.buts -side top -pady 10 -fill both

set ::gorilla::toplevel($top) $top
wm protocol $top WM_DELETE_WINDOW gorilla::DestroyPreferencesDialog
	} else {
wm deiconify $top
	}

	set oldGrab [grab current .]

	update idletasks
	raise $top
	focus $top.buts.b1
	grab $top

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
}
	}

	if {$oldGrab != ""} {
grab $oldGrab
	} else {
grab release $top
	}

	wm withdraw $top

	if {$gorilla::guimutex != 1} {
return
	}

	foreach pref {clearClipboardAfter \
		defaultVersion \
		doubleClickAction \
		exportAsUnicode \
		exportFieldSeparator \
		exportIncludeNotes \
		exportIncludePassword \
		exportShowWarning \
		idleTimeoutDefault \
		keepBackupFile \
		lruSize \
		rememberGeometries \
		saveImmediatelyDefault \
		unicodeSupport} {
set ::gorilla::preference($pref) $::gorilla::prefTemp($pref)
	}
}

proc gorilla::Preferences {} {
	PreferencesDialog
}


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

		if {![regexp {Revision: ([0-9.]+)} $::gorillaVersion dummy revision]} {
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
			exportAsUnicode dword \
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

	if {![regexp {Revision: ([0-9.]+)} $::gorillaVersion dummy revision]} {
		set revision "<unknown>"
	}

	puts $f "revision=$revision"

		#
		# Note: findInText omitted on purpose. It might contain a password.
		#

	foreach pref {caseSensitiveFind \
			clearClipboardAfter \
			defaultVersion \
			doubleClickAction \
			exportAsUnicode \
			exportIncludeNotes \
			exportIncludePassword \
			exportShowWarning \
			findInAny \
			findInNotes \
			findInPassword \
			findInTitle \
			findInURL \
			findInUsername \
			idleTimeoutDefault \
			keepBackupFile \
			lruSize \
			rememberGeometries \
			saveImmediatelyDefault \
			unicodeSupport} {
		if {[info exists ::gorilla::preference($pref)]} {
			puts $f "$pref=$::gorilla::preference($pref)"
		}
	}

	if {[info exists ::gorilla::preference(exportFieldSeparator)]} {
		puts $f "exportFieldSeparator=\"[string map {\t \\t} $::gorilla::preference(exportFieldSeparator)]\""
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

		foreach file $lru {
			puts $f "lru=\"[string map {\\ \\\\ \" \\\"} $file]\""
		}
	}

	if {![info exists ::gorilla::preference(rememberGeometries)] || \
			$::gorilla::preference(rememberGeometries)} {
		foreach top [array names ::gorilla::toplevel] {
			if {[scan [wm geometry $top] "%dx%d" width height] == 2} {
				puts $f "geometry,$top=${width}x${height}"
			}
		}
	}

	if {[catch {close $f}]} {return 0}

	return 1
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

		if {![regexp {Revision: ([0-9.]+)} $::gorillaVersion dummy revision]} {
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
			exportAsUnicode boolean \
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

		if {![regexp {Revision: ([0-9.]+)} $::gorillaVersion dummy revision]} {
	set revision "<unmatchable>"
		}

		set prefsRevision "<unknown>"

		if {[catch {
	set f [open $fileName]
		}]} {
	return 0
		}

		while {![eof $f]} {
	set line [string trim [gets $f]]
	if {[string index $line 0] == "#"} {
			continue
	}

	if {[set index [string first "=" $line]] < 1} {
			continue
	}

	set pref [string trim [string range $line 0 [expr {$index-1}]]]
	set value [string trim [string range $line [expr {$index+1}] end]]

	if {[string index $value 0] == "\""} {
			set i 1
			set prefValue ""

			while {$i < [string length $value]} {
		set c [string index $value $i]
		if {$c == "\\"} {
				set c [string index $value [incr i]]
				switch -exact -- $c {
			t {
					set d "\t"
			}
			default {
					set d $c
			}
				}
				append prefValue $c
		} elseif {$c == "\""} {
				break
		} else {
				append prefValue $c
		}
		incr i
			}

			set value $prefValue
	}

	switch -glob -- $pref {
			clearClipboardAfter -
			defaultVersion {
		if {[string is integer $value]} {
				if {$value >= 0} {
			set ::gorilla::preference($pref) $value
				}
		}
			}
			doubleClickAction {
		set ::gorilla::preference($pref) $value
			}
			caseSensitiveFind -
			exportAsUnicode -
			exportIncludeNotes -
			exportIncludePassword -
			exportShowWarning -
			findInAny -
			findInNotes -
			findInPassword -
			findInTitle -
			findInURL -
			findInUsername {
		if {[string is boolean $value]} {
				set ::gorilla::preference($pref) $value
		}
			}
			exportFieldSeparator {
		if {[string length $value] == 1 && \
			$value != "\"" && $value != "\\"} {
				set ::gorilla::preference($pref) $value
		}
			}
			findThisText {
		set ::gorilla::preference($pref) $value
			}
			idleTimeoutDefault {
		if {[string is integer $value]} {
				if {$value >= 0} {
			set ::gorilla::preference($pref) $value
				}
		}
			}
			keepBackupFile {
		if {[string is boolean $value]} {
				set ::gorilla::preference($pref) $value
		}
			}
			lru {
		lappend ::gorilla::preference($pref) $value
			}
			lruSize {
		if {[string is integer $value]} {
				set ::gorilla::preference($pref) $value
		}
			}
			rememberGeometries {
		if {[string is boolean $value]} {
			set ::gorilla::preference($pref) $value
		}
			}
			revision {
		set prefsRevision $value
			}
			saveImmediatelyDefault {
		if {[string is boolean $value]} {
				set ::gorilla::preference($pref) $value
		}
			}
			unicodeSupport {
		if {[string is integer $value]} {
				set ::gorilla::preference($pref) $value
		}
			}
			geometry,* {
		if {[scan $value "%dx%d" width height] == 2} {
				set ::gorilla::preference($pref) "${width}x${height}"
		}
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

		catch {close $f}
		return 1
}

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
			-title "No Database" \
			-message "Please create a new database, or open an existing\
			database first."
		return
	}

	if {[catch {set currentPassword [GetPassword 0 [mc "Current Master Password:"]]} err]} {
		# canceled
		return
	}
	if {![$::gorilla::db checkPassword $currentPassword]} {
		tk_messageBox -parent . \
			-type ok -icon error -default ok \
			-title "Wrong Password" \
			-message "That password is not correct."
		return
	}

	pwsafe::int::randomizeVar currentPassword

	if {[catch {set newPassword [GetPassword 1 [mc "New Master Password:"]] } err]} {
		tk_messageBox -parent . \
			-type ok -icon info -default ok \
			-title "Password Not Changed" \
			-message "You canceled the setting of a new password.\
			Therefore, the existing password remains in effect."
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
# Copy the URL to the Clipboard
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
		return [$::gorilla::db getFieldValue $rn 13]
	}

		#
		# Password Safe v2 kept the URL in the "Notes" field.
		#

	if {![$::gorilla::db existsField $rn 5]} {
		return
	}

	set notes [$::gorilla::db getFieldValue $rn 5]
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
# Copy the Password to the Clipboard
# ----------------------------------------------------------------------
#

proc gorilla::GetSelectedPassword {} {
	if {[catch {set rn [gorilla::GetSelectedRecord]} err]} {
		return
	}
	if {![$::gorilla::db existsField $rn 6]} {
		return
	}

	return [$::gorilla::db getFieldValue $rn 6]
}

proc gorilla::CopyPassword {} {
	ArrangeIdleTimeout
	clipboard clear
	clipboard append -- [::gorilla::GetSelectedPassword]
	set ::gorilla::activeSelection 2
	selection clear
	selection own .
	ArrangeToClearClipboard
	set ::gorilla::status [mc "Copied password to clipboard."]
}

# ----------------------------------------------------------------------
# Copy the Username to the Clipboard
# ----------------------------------------------------------------------
#

proc gorilla::GetSelectedRecord {} {
	if {[llength [set sel [$::gorilla::widgets(tree) selection]]] == 0} {
		error "oops"
	}
	set node [lindex $sel 0]
	set data [$::gorilla::widgets(tree) item $node -values]
	set type [lindex $data 0]
	if {$type != "Login"} {
		error "oops"
	}

	return [lindex $data 1]
}

proc gorilla::GetSelectedUsername {} {
	if {[catch {set rn [gorilla::GetSelectedRecord]}]} {
		return
	}

	if {![$::gorilla::db existsField $rn 6]} {
		return
	}

	return [$::gorilla::db getFieldValue $rn 4]
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

proc gorilla::About {} {
	ArrangeIdleTimeout
	set top .about

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top -bg "#ffffff"

		wm title $top "Password Gorilla"

		frame $top.top -bg "#ffffff"
		frame $top.top.pg -bg "#ffffff"
		label $top.top.pg.title -bg "#ffffff" -text "Password Gorilla"
		pack $top.top.pg.title -side top -fill x -pady 3

	if {![regexp {Revision: ([0-9.]+)(alpha)} $::gorillaVersion fullname revision]} {
			set revision "<unknown>"
	}

	label $top.top.pg.rev -bg "#ffffff" -text $fullname
	pack $top.top.pg.rev -side top -fill x -padx 3

	label $top.top.pg.url -bg "#ffffff" \
			-text "http://www.fpx.de/fp/Software/Gorilla/"
	pack $top.top.pg.url -side top -fill x -pady 10
	pack $top.top.pg -side left -fill x -expand yes

	label $top.top.splash -bg "#ffffff" \
			-image $::gorilla::images(splash)
	pack $top.top.splash -side right
	pack $top.top -side top -fill both -expand yes

	ttk::separator $top.topsep -orient horizontal
	pack $top.topsep -side top -fill x

	set midsection [frame $top.mid -bg "#ffffff"]

	set imgframe [frame $midsection.imgs -bg "#ffffff"]
	label $imgframe.lab \
			-font {Helvetica 10 bold} -bg "#ffffff" \
			-text "Copyright \u00a9 2005"
	label $imgframe.img -bg "#ffffff" \
			-image $::gorilla::images(splash)
			# -image $::gorilla::images(wfpxsm)
	label $imgframe.bot \
			-font {Helvetica 10 bold} -bg "#ffffff" \
			-text "Frank Pilhofer"
	label $imgframe.botbot \
			-font {Helvetica 10 bold} -bg "#ffffff" \
			-text "fp@fpx.de"
	pack $imgframe.lab $imgframe.img $imgframe.bot $imgframe.botbot -side top
	# pack $imgframe -side left -padx 10 -pady 10

	ttk::separator $midsection.sep -orient vertical
	pack $midsection.sep -side left -fill both

	set txtframe [frame $midsection.txt -bg "#ffffff"]
	label $txtframe.t1 -wraplength 450 -justify left \
			-anchor w -bg "#ffffff" \
			-text "Based on the \"Password Safe\" program, copyright\
			\u00a9 1997-1998 by Counterpane Systems, now maintained\
			as an Open Source project at\
			http://passwordsafe.sourceforge.net/"
	label $txtframe.t2 -wraplength 450 -justify left \
			-anchor w -bg "#ffffff" \
			-text "Released under the GNU General Public License.\
			Please read the file \"LICENSE.txt,\" or choose \"License\"\
			from the \"Help\" menu, for more information."
	label $txtframe.t3 -wraplength 450 -justify left \
			-anchor w -bg "#ffffff" \
			-text "This software would not be possible without the\
			excellent Open Source tools that it is based on. Uses\
			Tcl/Tk, \[incr Tcl\], BWidget, and parts of tcllib. May\
			use Tclkit. All packages are copyrighted by their\
			respective authors and contributors, and released\
			under BSD license."
	label $txtframe.t4 -wraplength 450 -justify left \
			-anchor w -bg "#ffffff" \
			-text "Copyright \u00a9 2005 Frank Pillhofer fp@fpx.de\n\
			\nGorilla artwork contributed by Andrew J. Sniezek.\n\
			\nVersion 1.5 by Zbigniew Diaczyszyn"
	pack $txtframe.t1 $txtframe.t2 $txtframe.t3 $txtframe.t4 \
			-side top -fill both -expand yes \
			-padx 10 -pady 5
	pack $txtframe -side left -fill both

	pack $midsection -side top -fill both -expand yes

	ttk::separator $top.botsep -orient horizontal
	pack $top.botsep -side top -fill x

	set botframe [frame $top.botframe -bg "#ffffff"]
	button $botframe.but -width 10 -text "OK" \
			-command "gorilla::DestroyAboutDialog"
	pack $botframe.but
	pack $botframe -side top -fill x -pady 10

	bind $top <Return> "gorilla::DestroyAboutDialog"

	set ::gorilla::toplevel($top) $top
	wm protocol $top WM_DELETE_WINDOW gorilla::DestroyAboutDialog
		} else {
	set botframe "$top.botframe"
		}

		update idletasks
		wm deiconify $top
		raise $top
		focus $botframe.but
		wm resizable $top 0 0
}

proc gorilla::Help {} {
		ArrangeIdleTimeout
		ShowTextFile .help [mc "Using Password Gorilla"] "help.txt"
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
		toplevel $top

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

		set filename [file join $::gorillaDir $fileName]
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

	foreach {pref default} {
		caseSensitiveFind 0
		findInAny 0
		findInTitle 1
		findInUsername 1
		findInPassword 0
		findInNotes 1
		findInURL 1
		findThisText ""
			} {
		if {![info exists ::gorilla::preference($pref)]} {
			set ::gorilla::preference($pref) $default
		}
	}

	if {![info exists ::gorilla::toplevel($top)]} {
		toplevel $top
		TryResizeFromPreference $top
		wm title $top "Find"

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
		ttk::checkbutton $top.find.url -text "URL" \
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
	}

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
	if {![info exists ::gorilla::findCurrentNode]} {
		set ::gorilla::findCurrentNode [lindex [$::gorilla::widgets(tree) children {}] 0]
	}

	set text $::gorilla::preference(findThisText)
	set node $::gorilla::findCurrentNode
	set found 0
	set recordsSearched 0
	set totalRecords [llength [$::gorilla::db getAllRecordNumbers]]
 	while {!$found} {
		set node [::gorilla::FindNextNode $node]
		set data [$::gorilla::widgets(tree) item $node -values]
		set type [lindex $data 0]

		
		if {$type == "Group" || $type == "Root"} {
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
				if {[FindCompare $text [$::gorilla::db getFieldValue $rn 3] $cs]} {
					set found 3
					break
				}
		}

		if {($fa || $::gorilla::preference(findInUsername)) && \
			[$::gorilla::db existsField $rn 4]} {
				if {[FindCompare $text [$::gorilla::db getFieldValue $rn 4] $cs]} {
			set found 4
			break
				}
		}

		if {($fa || $::gorilla::preference(findInPassword)) && \
			[$::gorilla::db existsField $rn 6]} {
				if {[FindCompare $text [$::gorilla::db getFieldValue $rn 6] $cs]} {
			set found 6
			break
				}
		}

		if {($fa || $::gorilla::preference(findInNotes)) && \
			[$::gorilla::db existsField $rn 5]} {
				if {[FindCompare $text [$::gorilla::db getFieldValue $rn 5] $cs]} {
			set found 5
			break
				}
		}

		if {($fa || $::gorilla::preference(findInURL)) && \
			[$::gorilla::db existsField $rn 13]} {
				if {[FindCompare $text [$::gorilla::db getFieldValue $rn 13] $cs]} {
			set found 13
			break
				}
		}
		
		if {$node == $::gorilla::findCurrentNode} {
			#
			# Wrapped around.
			#
			break
		}

	}

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


# ----------------------------------------------------------------------
# Icons
# ----------------------------------------------------------------------
#

set ::gorilla::images(application) [image create photo -data "
R0lGODlhEAAQAMZxAF4qAl4rAWAtAmEuBmMvAWQwAGIwCmMxCmU0DWk4DGs5DW87AGw7DXA8AW88
BGw8EGw8EnFADnFCHHdFD3dGDn1JA3ZJIX9MBX1ND4VRBIFSGIJSHItZC4RZM49eEoxeH4peKZJh
GYxiNpFkLYxlOZBoP5dqJpRqNZlrIJ1uG6V5LKJ5PaJ7RquAK6OBTrCMSriQILmPLraPVbaUYcKZ
SMCaUsqcLdirIsiqdNWtOcmsdNm3UuC5SuzAMeTBVN/DcuzMUPjQI+7OVfjQJvXQNfDOWO3PV/bP
Q/7TKvbUOO/TZfbUVPvYKvzZKvvaJ/jXUfDYePbYZ/bZY/ncRPzcRPnbZ/zgMvjeWf/iJv7iM/ff
df/jOfjhe//nLvbhhP/oNPvkdf/qNP/mZ/rnh/voh/fsqPrtnf7ukvfuqP3wm/nwqPryqfryq/vy
qv70q//1qP32sv///////////////////////////////////////////////////////////yH+
EUNyZWF0ZWQgd2l0aCBHSU1QACH5BAEKAH8ALAAAAAAQABAAAAeXgH+Cg4ISIicgDISLfyVKU0mR
G4yCHVdfWTAHGkkTjAM/YVZNGH8GNkkEixBGXU5BNxQtRTwOiw9AWExER0tVXD4NiwI7W1RPUlpj
ZjkFjC9CYmBkaXBeFYwuazFRZ29uUByMJG0qQzQpKB4LjBZqK0g1H5SCCGgsPReK9ABlMyYZ6AkK
wAbHCIGDEuiQEQLhIAURHAoKBAA7"]

set ::gorilla::images(browse) [image create photo -data "
R0lGODlhFAASAKEBAC5Ecv///5sJCQAAACH5BAEAAAMALAAAAAAUABIAAAJCnI+pywoPowQIBDvj
rbnXAIaiSB1WIAhiSn5oqr7sZo52WBrnDPK03oMFZ7nB6TYq7mLBVk0Wg8WUSJuyk2lot9wCADs=
"]

set ::gorilla::images(group) [image create photo -data "
R0lGODlhDQANAJEAANnZ2QAAAP//AP///yH5BAEAAAAALAAAAAANAA0AAAIyhI+pe0EJ4VuE
iFBC+EGyg2AHyZcAAKBQvgQAAIXyJQh2kOwg+BEiEhTCt4hAREQIHVIAOw==
"]

set ::gorilla::images(login) [image create photo -data "
R0lGODlhDQANAJEAANnZ2QAAAAD/AP///yH5BAEAAAAALAAAAAANAA0AAAI0hI+pS/EPACBI
vgQAAIXyJQAAKJQvAQBAoXwJAAAK5UsAAFAoXwIAgEL5EgAAFP8IPqZuAQA7
"]

set ::gorilla::images(wfpxsm) [image create photo -data "
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
"]

# Quelle: http://www.clipart-kiste.de/archiv/Tiere/Affen/affe_08.gif

set ::gorilla::images(splash) [image create photo -data "
R0lGODlhvgCWAIcAAP///+fn5+/v7/f39/fv75RaOWM5IYRSMb1rOVIpEPete5RaMbVrOYxSKXNC
IYRjSve1hO+te/etc1IxGEopEM6cc5xzUr2MY96lc/+9hJRrStaca7WEWve1e617UoxjQntSMXNK
KYxaMZxjMbVzOWNSQlI5IbWUc++9jOe1hJRzUrWMY//GjGtSOYxrSq2EWs6ca++1e8aUY+etc2NK
Md6la72MWrWEUoRaMXtSKZRjMUoxGFo5GGtCGK2lnMaca//OlK2MY86lc6WEWpx7Ur2UY96tc9al
a7WMWq2EUoxrQntaMXNSKYxjMWtKIYxzUoRrSntjQs6la3NaOVpCIbWUY62MWq2Ua6WMY4xzSnNa
Mb2le5yEWlpCGKWUc4x7WoRzUlpKKUIxEFI5CKWUa0IxCGtaKWtjSlJKMUI5GIyEY2tjQpSMY+/v
587OxtbWzt7e1sbGvb29rcbGtbW1pa2tnJycjJSUhIyMe4SEc3NzY5ychJSUe3t7Y3NzWmtrUmNj
SlpaQnt7WmtrQlJSMUpKKUJCITk5GCkpEFpaISkpAFJaMSkxCHuEWmNrSkpSMXuEYzlCIWNrUhgp
ACk5GHOEYzlKKTFCIXuEczlCMUJaMVJrQhgxCMbWvWNzWpSljFprUlJjSik5ISE5GFpzUlJrSkpj
QgghAAgpAHOEc2uEa2N7YzlSOTFKMRgpGCE5ISlKKSFCIRgxGAAQAAAhAClaMUJrSggxEAApCEpr
UkJjSgAhCDlaQnOMe2N7axBCIQg5GAAxEDlSQilSOSFKMVJ7YzFaQgA5GLXGvc7e1mOEc0JzWjlr
UpytpXucjAg5ISljShhSOXullGOMe1qEcyFaQgA5IWuUhFJ7a0pzYyFjSgBCKa3GvRhaQqW9tVqM
eylzWghSOQBKMXOMhGOUhEp7awg5KWullEqEcyljUhBKOaXGvYSlnAA5KZy9tZS1rYytpXuclFp7
cxhjUoStpXOclAhaSu/39+///9bn58bW1rXOzkJSUoSlpVJSWgAAACH/C05FVFNDQVBFMi4wAwHo
AwAh+QQJHgAAACwAAAAAvgCWAAcI/AABCBxIsKDBgwgTKlzIsKHDhxAjSpxIsaLFixgzatzIsaPH
jyBDihxJsqTJkyhTqlzJsqXLlzBjypxJs6bNmzhz6tzJs6dPm+/+/Rzqc9YsokhzHmM0TGCAX8aS
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
8IM+yIM72AMfoAM58MH9678hBIkgFIA2yCiN4qiO8ii5ooNmoEQf2AO7yoM8gARI0AMSMzEJXLFQ
3LNny7NSNMVSTINrKAWvCkFfKcOJgBKzWg9G+hME5ClsMSNWuAYvVLFCeAQ00MM16L4/rL9BnIPY
m70g/ERERRQAR+Qoj6KDOqgrTISEPvAD5xKncQqE6CqxEzvFUkQxJPnF6CKEPDTHcpQuJEESQ/iD
bNiEQViPAxm48HMIuPs4SuG9RoqCJmBABEQnGjCxS5AFUFCFPFi5PPPF6AKFQfgDP6Q/+5OD/EM7
/hvCYmoDjdqouJqrusLBPNADpxOnQNhG6XqEkpyuQghHdRTHEhPJNRgEhrzGPoCETKRJTcQrawRJ
bSSEPMAGbKgEUIiFWOi2QijHQIgC2Tg4DdAAD8OBOUMnNDCBQxADUPAEbKAGSPgDUEzJR4iulnQ6
PyRGQYxI/aM9/1PEi8zISKSDT7jEu9JEnHy6KfzIxrkchDVwuhrsQ7DMwTv4hE/YwfuTg8AUzPur
A7pqy7d0LlDQRpH0BBvEBEjIhmqIhmfAhcq0hmDATFoIBmvAhWeohmXABD1YgxLLw21sSZe8y/mS
yTzAwRwMREE0RrJMu2UsJmMKgEZ8xDlQSx/gTcPsy/oDzr4UTt6sAx4MTGTQzYWLPY26zeZsxIzs
KLkqTLY8TJrsg+vsw2vUTu3Ug+67Rj2wxuuUyZnMxNa8g/Pcg/rzy+K8P2NMTv1rOIczpiJExEQs
QmOyzdvEyP3cKIZTzo3iT4y8TVrDT/4rQgE5UPzUT2d8Rt2MxMAcxPYkzGikUAmVUMEMTN16RM7X
gz34FNDbLNB7MNADrU/dQNADRVESVUZDSVAjvAcRtU1GbM6LdM4abbj4dLgBLdD5vIcURdASBVIg
FUKIE8IgNdIjRdIkVdIlZdImddInhdIoldIppdIqtdIrxdIs1dIt5dIu9dIvBdMwFdMxJdMyNdMz
RdMwDQgAIf5rRklMRSBJREVOVElUWQ0KQ3JlYXRlZCBvciBtb2RpZmllZCBieQ0KYW4gdW5pZGVu
dGlmaWVkIHVzZXIgb2YgYW4gdW5yZWdpc3RlcmVkIGNvcHkgb2YgR0lGIENvbnN0cnVjdGlvbiBT
ZXQAIf7qVU5SRUdJU1RFUkVEIFNIQVJFV0FSRQ0KDQpBc3NlbWJsZWQgd2l0aCBHSUYgQ29uc3Ry
dWN0aW9uIFNldDoNCg0KQWxjaGVteSBNaW5kd29ya3MgSW5jLg0KQm94IDUwMA0KQmVldG9uLCBP
Tg0KTDBHIDFBMA0KQ0FOQURBLg0KDQpodHRwOi8vd3d3Lm1pbmR3b3Jrc2hvcC5jb20NCg0KVGhp
cyBjb21tZW50IHdpbGwgbm90IGFwcGVhciBpbiBmaWxlcyBjcmVhdGVkIHdpdGggYSByZWdpc3Rl
cmVkIHZlcnNpb24uACH/C0dJRkNPTm5iMS4wAgQADhcAAgADAAAAAAAAAAAAF0M6XEdlbmVcbW9u
a2V5cnVuMS5naWYADhcAAgAFAAAAAAAAAAAAF0M6XEdlbmVcbW9ua2V5cnVuMi5naWYADhcAAgAH
AAAAAAAAAAAAF0M6XEdlbmVcbW9ua2V5cnVuMy5naWYADhcAAgAJAAAAAAAAAAAAF0M6XEdlbmVc
bW9ua2V5cnVuNC5naWYAADs=
"]

# --------------------------------EXAMPLE FROM ACTIVESTATE -------------
# Procedures building the tree
# ------------------

## Code to populate the roots of the tree (can be more than one on Windows)
proc populateRoots {tree} {
		foreach dir [lsort -dictionary [file volumes]] {
			populateTree $tree [$tree insert {} end -text $dir \
			-values [list $dir directory]]
		}
}

## Code to populate a node of the tree; Baumknoten mit Daten füllen
proc populateTree {tree node} {
	if {[$tree set $node type] ne "directory"} {
		return
	}
		set path [$tree set $node fullpath]
		$tree delete [$tree children $node]
		foreach f [lsort -dictionary [glob -nocomplain -dir $path *]] {
	set type [file type $f]
	set id [$tree insert $node end -text [file tail $f] \
		-values [list $f $type]]

	if {$type eq "directory"} {
			## Make it so that this node is openable
			$tree insert $id 0 -text dummy ;# a dummy
			$tree item $id -text [file tail $f]/

	} elseif {$type eq "file"} {
			set size [file size $f]
			## Format the file size nicely
			if {$size >= 1024*1024*1024} {
		set size [format %.1f\ GB [expr {$size/1024/1024/1024.}]]
			} elseif {$size >= 1024*1024} {
		set size [format %.1f\ MB [expr {$size/1024/1024.}]]
			} elseif {$size >= 1024} {
		set size [format %.1f\ kB [expr {$size/1024.}]]
			} else {
		append size " bytes"
			}
			$tree set $id size $size
	}
		}

		# Stop this code from rerunning on the current node
		$tree set $node type processedDirectory
}

proc gorilla::CheckDefaultExtension {name extension} {
	set res [split $name .]
	if {[llength $res ] == 1} {
		set name [join "$res $extension" .]
	}
	return $name
}

#
# ----------------------------------------------------------------------
# Debugging for the Mac OS
# ----------------------------------------------------------------------
#

proc gorilla::writeToLog {logfile message} {
	# mac Abfrage
	set log "[clock format [clock seconds] -format %b\ %d\ %H:%M:%S] \
		\"Password Gorilla\": $message"
		
	if [file exists $logfile] {
		# puts "$logfile exists"
		set filehandler [open $logfile a+]
		puts $filehandler $log
		close $filehandler
	} else {
		puts "$logfile does not exist or no access permissions"
		puts $log
	}
}

proc psn_Delete {argv argc} {
	# debugging
	gorilla::writeToLog $::gorilla::logfile "argv: $argv"
	
	set index 0
	set new_argv ""
	
	while { $index < $argc } {
		if {[string first "psn" [lindex $argv $index]] == -1} { 
			lappend new_argv [lindex $argv $index]
		}
		incr index
	}
	gorilla::writeToLog $::gorilla::logfile "Gefilteter argv: $new_argv"
	return $new_argv
}

#
# ----------------------------------------------------------------------
# Init
# ----------------------------------------------------------------------
#

# If we want some error logging
# set logfile "/home/dia/Projekte/tcl/console.log"
set ::gorilla::logfile "/private/var/log/console.log"

if {[tk windowingsystem] == "aqua"} {
		set argv [psn_Delete $argv $argc]
	}
	
proc usage {} {
		puts stdout "usage: $::argv0 \[Options\] \[<database>\]"
		puts stdout "	Options:"
		puts stdout "		--rc <name>	 Use <name> as configuration file (not the Registry)."
		puts stdout "		--norc				Do not use a configuration file (or the Registry)."
		puts stdout "		<database>		Open <database> on startup."
}

if {$::gorilla::init == 0} {
	if {[string first "-norc" $argv0] != -1} {
		set ::gorilla::preference(norc) 1
	}

	set haveDatabaseToLoad 0
	set databaseToLoad ""

	# set argc [llength $argv]	;# obsolete

	for {set i 0} {$i < $argc} {incr i} {
		switch -- [lindex $argv $i] {
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
			--help {
				usage
				exit 0
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
	}
}
	gorilla::Init
	gorilla::LoadPreferences
	gorilla::InitGui
	set ::gorilla::init 1

	destroy .start

	if {$haveDatabaseToLoad} {
		set action [gorilla::Open $databaseToLoad]
	} else {
		set action [gorilla::Open]
	}

	if {$action == "Cancel"} {
		destroy .
		exit		
	}

	wm deiconify .
	raise .
	update

	set ::gorilla::status [mc "Welcome to the Password Gorilla."]

