# cscroll.tcl --
#
# This demonstration script creates a simple canvas that can be
# scrolled in two dimensions.

if {![info exists widgetDemo]} {
    error "This script should be run from the \"widget\" demo."
}

package require tk

set w .cscroll
catch {destroy $w}
toplevel $w
wm title $w "Scrollable Canvas Demonstration"
wm iconname $w "cscroll"
positionWindow $w
set c $w.c

label $w.msg -font $font -wraplength 4i -justify left -text "This window displays a canvas widget that can be scrolled by using the scrollbars, by dragging with button 2 in the canvas, by using a mouse wheel, or with the two-finger gesture on a touchpad.  If you click button 1 on one of the rectangles, its indices will be printed on stdout."
pack $w.msg -side top

## See Code / Dismiss buttons
set btns [addSeeDismiss $w.buttons $w]
pack $btns -side bottom -fill x

frame $w.grid
scrollbar $w.hscroll -orient horizontal -command "$c xview"
scrollbar $w.vscroll -command "$c yview"
canvas $c -relief sunken -borderwidth 2 -scrollregion {-11c -11c 50c 20c} \
	-xscrollcommand "$w.hscroll set" \
	-yscrollcommand "$w.vscroll set"
pack $w.grid -expand yes -fill both -padx 1 -pady 1
grid rowconfig    $w.grid 0 -weight 1 -minsize 0
grid columnconfig $w.grid 0 -weight 1 -minsize 0

grid $c -padx 1 -in $w.grid -pady 1 \
    -row 0 -column 0 -rowspan 1 -columnspan 1 -sticky news
grid $w.vscroll -in $w.grid -padx 1 -pady 1 \
    -row 0 -column 1 -rowspan 1 -columnspan 1 -sticky news
grid $w.hscroll -in $w.grid -padx 1 -pady 1 \
    -row 1 -column 0 -rowspan 1 -columnspan 1 -sticky news


set bg [lindex [$c config -bg] 4]
for {set i 0} {$i < 20} {incr i} {
    set x [expr {-10 + 3*$i}]
    for {set j 0; set y -10} {$j < 10} {incr j; incr y 3} {
	$c create rect ${x}c ${y}c [expr {$x+2}]c [expr {$y+2}]c \
		-fill $bg -tags rect
	$c create text [expr {$x+1}]c [expr {$y+1}]c -text "$i,$j" \
	    -anchor center -tags text
    }
}

$c bind all <Enter> "scrollEnter $c"
$c bind all <Leave> "scrollLeave $c"
$c bind all <Button-1> "scrollButton $c"
bind $c <Button-2> "$c scan mark %x %y"
bind $c <B2-Motion> "$c scan dragto %x %y"

# We must make sure that positive and negative movements are rounded
# equally to integers, avoiding the problem that
#     (int)1/-40 = -1,
# but
#     (int)-1/-40 = 0
# The following code ensures equal +/- behaviour.
bind $c <MouseWheel> {
    if {%D >= 0} {
	%W yview scroll [expr {%D/-40}] units
    } else {
	%W yview scroll [expr {(%D-39)/-40}] units
    }
}
bind $c <Option-MouseWheel> {
    if {%D >= 0} {
	%W yview scroll [expr {%D/-12}] units
    } else {
	%W yview scroll [expr {(%D-11)/-12}] units
    }
}
bind $c <Shift-MouseWheel> {
    if {%D >= 0} {
	%W xview scroll [expr {%D/-40}] units
    } else {
	%W xview scroll [expr {(%D-39)/-40}] units
    }
}
bind $c <Shift-Option-MouseWheel> {
    if {%D >= 0} {
	%W xview scroll [expr {%D/-12}] units
    } else {
	%W xview scroll [expr {(%D-11)/-12}] units
    }
}
bind $c <TouchpadScroll> {
    lassign [tk::PreciseScrollDeltas %D] deltaX deltaY
    if {$deltaX != 0 || $deltaY != 0} {
	tk::ScrollByPixels %W $deltaX $deltaY
    }
}

proc scrollEnter canvas {
    global oldFill
    set id [$canvas find withtag current]
    if {[lsearch [$canvas gettags current] text] >= 0} {
	set id [expr {$id-1}]
    }
    set oldFill [lindex [$canvas itemconfig $id -fill] 4]
    if {[winfo depth $canvas] > 1} {
	if {[tk windowingsystem] eq "aqua"} {
	    $canvas itemconfigure $id -fill systemSelectedTextBackgroundColor
	} else {
	    $canvas itemconfigure $id -fill LightSeaGreen
	}
    }
}

proc scrollLeave canvas {
    global oldFill
    set id [$canvas find withtag current]
    if {[lsearch [$canvas gettags current] text] >= 0} {
	set id [expr {$id-1}]
    }
    $canvas itemconfigure $id -fill $oldFill
}

proc scrollButton canvas {
    set id [$canvas find withtag current]
    if {[lsearch [$canvas gettags current] text] < 0} {
	set id [expr {$id+1}]
    }
    puts stdout "You buttoned at [lindex [$canvas itemconf $id -text] 4]"
}
