# mac_tabs.tcl --
#
# This demonstration script creates three tabbable windows and allows the
# wm attributes tabbingid and tabbingmode to be manipulated for the third
# window, to demonstrate the effects of those attributes.

if {![info exists widgetDemo]} {
    error "This script should be run from the \"widget\" demo."
}

package require tk
catch {font create giant -family {Times New Roman} -size 64}
set w .mac_tabs
catch {destroy $w}
toplevel $w
wm title $w "Tabbed Windows in Aqua"
wm iconname $w "mac_tabs"
positionWindow $w
set suffix 0
set winlist {}
##

## See Code / Dismiss
pack [addSeeDismiss $w.buttons $w] -side bottom -fill x
##
set info "\
This demo shows 3 toplevels, A, B, and C.  \
Each of these has tabbingmode set to preferred. \
The tabbingid of Window A is groupA, the \
tabbingid of Window B is groupB and the tabbingid \
of Window C is groupC.  Use the menubuttons below \
to see the effect of changing the tabbingid and \
tabbingmode attributes for Window C. \
"
pack [message $w.info -text $info -width 300]
wm geometry $w +450+350

ttk::frame $w.f
menu $w.idmenu -tearoff 0
foreach id {groupA groupB groupC} {
    $w.idmenu add command -label $id \
	-command [list wm attributes $w.c -tabbingid $id]
}
menu $w.modemenu -tearoff 0
foreach mode {auto preferred disallowed} {
    $w.modemenu add command -label $mode \
	-command [list wm attributes $w.c -tabbingmode $mode]
}
ttk::menubutton $w.f.idbutton -menu $w.idmenu -text "tabbingid"\
    -direction below
grid $w.f.idbutton -row 0 -column 0
ttk::menubutton $w.f.modebutton -menu $w.modemenu -text "tabbingmode"\
    -direction below
grid $w.f.modebutton -row 1 -column 0
pack $w.f

wm attributes $w.a -tabbingid groupA
wm attributes $w.a -tabbingmode preferred
toplevel $w.a
wm geometry $w.a +50+100
wm title $w.a "Window A"
pack [ttk::label $w.a.l -text A -font giant] -padx 100 -pady 30

wm attributes $w.b -tabbingid groupB
wm attributes $w.b -tabbingmode preferred
toplevel $w.b
wm geometry $w.b +400+100
wm title $w.b "Window B"
pack [ttk::label $w.b.l -text B -font giant] -padx 100 -pady 30

wm attributes $w.c -tabbingid groupC
wm attributes $w.c -tabbingmode preferred
toplevel $w.c
wm geometry $w.c +750+100
wm title $w.c "Window C"
pack [ttk::label $w.c.l -text C -font giant] -padx 100 -pady 30
