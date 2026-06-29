# mac_window_styles.tcl --
#
# This demonstration script creates a toplevel window containing a notebook
# whose pages provide examples of the various mac-specific widgets that are
# provided via special values for the -style option.

if {![info exists widgetDemo]} {
    error "This script should be run from the \"widget\" demo."
}

package require tk

set w .mac_wm
catch {destroy $w}
toplevel $w
wm title $w "Tk Aqua Window Styles"
wm iconname $w "mac_wm"
positionWindow $w
set suffix 0
set winlist {}
##

## See Code / Dismiss
pack [addSeeDismiss $w.buttons $w] -side bottom -fill x

proc launch {name windowInfo class} {
    if {[winfo exists $name]} {
	wm deiconify $name
	focus -force $name
	return
    }
    wm attributes $name -class $class; toplevel $name
    wm title $name $class
    set f $name.f
    ttk::frame $f
    set t $f.t
    text $t -background systemWindowBackgroundColor \
	-highlightcolor systemWindowBackgroundColor \
	-font systemDefaultFont\
	-wrap word -width 50 -height 6
    $t insert insert $windowInfo
    $t configure -state disabled
    grid columnconfigure $f 0 -weight 1
    grid $t -row 0 -column 0 -columnspan 2 -sticky NSEW
    ttk::labelframe $f.stylemask -text "styleMask bits"
    # titled
    if {$class == "nswindow"} {
       ttk::checkbutton $f.stylemask.titled -text titled -variable $name.titled \
	  -command [list setbit $name $f.stylemask.titled titled]
       $f.stylemask.titled state selected
       grid $f.stylemask.titled -row 0 -column 0 -sticky w
    }
    # closable
    ttk::checkbutton $f.stylemask.closable -text closable -variable $name.closable \
	-command [list setbit $name $f.stylemask.closable closable]
    $f.stylemask.closable state selected
    grid $f.stylemask.closable -row 1 -column 0 -sticky w
    # miniaturizableable
    ttk::checkbutton $f.stylemask.miniaturizable -text miniaturizable \
	-variable $name.miniaturizable \
	-command [list setbit $name $f.stylemask.miniaturizable miniaturizable]
    if {$class == "nswindow"} {
	$f.stylemask.miniaturizable state selected
    } else {
	$f.stylemask.miniaturizable state !alternate
    }
    grid $f.stylemask.miniaturizable -row 2 -column 0 -sticky w
    # resizable
    ttk::checkbutton $f.stylemask.resizable -text resizable -variable $name.resizable \
	-command [list setbit $name $f.stylemask.resizable resizable]
    $f.stylemask.resizable state selected
    grid $f.stylemask.resizable -row 3 -column 0 -sticky w
    # docmodal
    ttk::checkbutton $f.stylemask.docmodal -text docmodal -variable $name.docmodal \
	-command [list setbit $name $f.stylemask.docmodal docmodal]
    $f.stylemask.docmodal state !alternate
    grid $f.stylemask.docmodal -row 4 -column 0 -sticky w

    grid $f.stylemask -row 1 -column 0
    pack $name.f -side bottom -fill both -expand 1 -padx 16 -pady 16
}

set info "The command wm attributes window -stylemask ?bitnames? can \
be used to modify bits in the stylemask property of the NSWindow or \
NSPanel underlying a Tk Window.  Changing these bits causes the \
style of the window to change.  This demo allows you to see the \
effects of changing the bits.  (Note that buttons in the title bar \
can also be enabled or disabled with the ::tk::unsupported::MacWindowStyle \
command.)"

set panelInfo "A toplevel based on an NSPanel has a narrower title bar\
than one based on an NSWindow.  In addition the panel remains above all\
windows on the screen, regardless of which app is active. These are\
intended to be used as modal windows."

set windowInfo "This is a standard Apple document window, based on an\
NSWindow.  It has a larger title bar and behaves normally with respect\
to other windows from the same or another app."

## background frame
set f $w.f
ttk::frame $f
set t $f.t
text $t -background systemWindowBackgroundColor \
    -highlightcolor systemWindowBackgroundColor \
    -font systemDefaultFont\
    -wrap word -width 50 -height 8
$t insert insert $info
$t configure -state disabled
grid columnconfigure $f 0 -weight 1
grid $t -row 0 -column 0 -columnspan 2 -sticky NSEW
ttk::labelframe $f.stylemask -text "styleMask"
grid $f.stylemask -row 1 -column 0
grid [ttk::button $f.wbw -text "Open an NSWindow" -width 20 \
	  -command [list launch .nswindow $windowInfo nswindow]] -row 2 -column 0
grid [ttk::button $f.wbp -text "Open an NSPanel" -width 20 \
	  -command [list launch .nspanel $panelInfo nspanel]] -row 3 -column 0
grid [ttk::button $f.wbm -text "Open a modern window" -width 20 \
	  -command launchModernWindow] -row 4 -column 0
pack $w.f -side bottom -fill both -expand 1 -padx 16 -pady 16

proc setbit {win cb bitname} {
    set state [$cb instate selected]
    set bits [wm attributes $win -stylemask]
    set index [lsearch $bits $bitname]
    if {$index >= 0 && !$state} {
	set bits [lreplace $bits $index $index]
    }
    if {$index < 0 && $state} {
	lappend bits $bitname
    }
    wm attributes $win -stylemask $bits
}

set aboutText \
"Most of the apps which ship with a contemporary version of macOS \
feature a window similar to this one, with a left sidebar that \
allows selecting the content to be shown on the right hand side of \
the window.  These windows do not have a (visible) titlebar.\
\n\nApps that use such windows include the Finder and the App Store as \
well as Notes, Messages, Books, Maps and many others.\
\n\nTo create a window like this one in Tk simply set the fullsizecontent bit \
in the stylemask. For example:\n\n"

set aboutCode \
"wm attributes .t -stylemask {titled \\\
\nfullsizecontent closable miniaturizable \\\
\nresizable}\n\n"

set detailsText \
"(1) In the Apple API, setting the fullsizecontent bit in the stylemask \
only allows content to be drawn in the part of the window covered by \
the titlebar.  In order for that content to be visible the title bar \
must be transparent.  Since it would be pointless to draw content under \
an opaque title bar, Tk makes the title bar transparent whenever the \
fullsizecontent bit is set.\

\n\n\(2) Each radio button in the sidebar is a standard ttk::radiobutton \
but created with a special value for its -style option.  The value of the \
-style option used to create these buttons is SidebarButton.\n"

set whichPage 1
trace add variable whichPage write "flipPage whichPage"
proc flipPage {varname args} {
    global whichPage
    set newpage [set $varname]
    grid remove [grid content .mod.right -row 0 -column 0]
    switch $newpage\
	1 {grid .mod.right.about -padx 30 -pady 30 -row 0 -column 0 -sticky nsew}\
	2 {grid .mod.right.details -padx 30 -pady 30 -row 0 -column 0 -sticky nsew}
    update idletasks
}

proc launchModernWindow {} {
    global whichPage
    global aboutText
    global aboutCode
    global detailsText
    if {[winfo exists .mod]} {
	wm deiconify .mod
	focus -force .mod
	return
    }
    toplevel .mod
    wm title .mod {}
    wm attributes .mod -stylemask {titled fullsizecontent closable \
				       miniaturizable resizable}
    .mod configure -background white
    grid columnconfigure .mod 0 -weight 0
    grid columnconfigure .mod 1 -weight 1
    grid rowconfigure .mod 0 -weight 1
    frame .mod.left -width 220 -height 400 -background systemWindowBackgroundColor
    catch {
	font create leftFont -family .AppleSystemUIFont -size 11
	font create rightFont -family .AppleSystemUIFont -size 16
	font create codeFont -family Courier -size 16
    }
    grid [ttk::label .mod.left.spacer -padding {220 30 0 0}] -row 0 -column 0
    grid [ttk::radiobutton .mod.left.about -text About -style SidebarButton \
	      -variable whichPage -value 1] \
	-row 1 -column 0 -sticky nsew -padx 14
    grid [ttk::radiobutton .mod.left.details -text Details -style SidebarButton \
	-variable whichPage -value 2] \
	-row 2 -column 0 -sticky nsew -padx 14
    grid .mod.left -row 0 -column 0 -sticky nsew
    frame .mod.right -width 500 -background systemTextBackgroundColor
    grid rowconfigure .mod.right 0 -weight 0
    text .mod.right.about -highlightcolor systemTextBackgroundColor \
	-background systemTextBackgroundColor -font rightFont \
	-highlightthickness 0 -wrap word -width 40
    .mod.right.about tag configure code -font codeFont
    .mod.right.about insert end $aboutText
    .mod.right.about insert end $aboutCode code
    .mod.right.about configure -state disabled

    text .mod.right.details -highlightcolor systemTextBackgroundColor \
	-background systemTextBackgroundColor -font rightFont\
	-highlightthickness 0 -wrap word -width 40
    .mod.right.details insert end $detailsText
    .mod.right.details configure -state disabled

    grid .mod.right.about -padx 30 -pady 30 -row 0 -column 0 -sticky nsew
    grid .mod.right -row 0 -column 1 -sticky nsew
    wm geometry .mod 800x500
    update idletasks
}

