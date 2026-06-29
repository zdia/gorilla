# plot.tcl --
#
# This demonstration script creates a canvas widget showing a 2-D
# plot with data points that can be dragged with the mouse.

if {![info exists widgetDemo]} {
    error "This script should be run from the \"widget\" demo."
}

package require tk

set w .plot
catch {destroy $w}
toplevel $w
wm title $w "Plot Demonstration"
wm iconname $w "Plot"
positionWindow $w
set c $w.c

label $w.msg -font $font -wraplength 4i -justify left -text "This window displays a canvas widget containing a simple 2-dimensional plot.  You can doctor the data by dragging any of the points with mouse button 1."
pack $w.msg -side top

## See Code / Dismiss buttons
set btns [addSeeDismiss $w.buttons $w]
pack $btns -side bottom -fill x

canvas $c -relief raised -width 337.5p -height 225p
pack $w.c -side top -fill x

set plotFont {Helvetica 16}

$c create line 75p 187.5p 300p 187.5p -width 1.5p
$c create line 75p 187.5p 75p 37.5p -width 1.5p
$c create text 168.75p 15p -text "A Simple Plot" -font $plotFont -fill brown

for {set i 0} {$i <= 10} {incr i} {
    set x [expr {75 + ($i*22.5)}]			;# in points
    $c create line ${x}p 187.5p ${x}p 183.75p -width 1.5p
    $c create text ${x}p 190.5p -text [expr {10*$i}] -anchor n -font $plotFont
}
for {set i 0} {$i <= 5} {incr i} {
    set y [expr {187.5 - ($i*30)}]			;# in points
    $c create line 75p ${y}p 78.75p ${y}p -width 1.5p
    $c create text 72p ${y}p -text [expr {$i*50}].0 -anchor e -font $plotFont
}

foreach point {
    {9 42} {15 70.5} {24.75 73.5} {24 90} {45.75 135} {56.25 120} {73.5 167.25}
} {
    set x [expr {75 + (2.25*[lindex $point 0])}]	;# in points
    set y [expr {187.5 - (3*[lindex $point 1])/5}]	;# in points
    set item [$c create oval [expr {$x-4.5}]p [expr {$y-4.5}]p \
	    [expr {$x+4.5}]p [expr {$y+4.5}]p -width 0.75p -outline black \
	    -fill SkyBlue2]
    $c addtag point withtag $item
}

$c bind point <Enter> "$c itemconfig current -fill red"
$c bind point <Leave> "$c itemconfig current -fill SkyBlue2"
$c bind point <Button-1> "plotDown $c %x %y"
$c bind point <ButtonRelease-1> "$c dtag selected"
bind $c <B1-Motion> "plotMove $c %x %y"

set plot(lastX) 0
set plot(lastY) 0

# plotDown --
# This procedure is invoked when the mouse is pressed over one of the
# data points.  It sets up state to allow the point to be dragged.
#
# Arguments:
# w -		The canvas window.
# x, y -	The coordinates of the mouse press.

proc plotDown {w x y} {
    global plot
    $w dtag selected
    $w addtag selected withtag current
    $w raise current
    set plot(lastX) $x
    set plot(lastY) $y
}

# plotMove --
# This procedure is invoked during mouse motion events.  It drags the
# current item.
#
# Arguments:
# w -		The canvas window.
# x, y -	The coordinates of the mouse.

proc plotMove {w x y} {
    global plot
    $w move selected [expr {$x-$plot(lastX)}] [expr {$y-$plot(lastY)}]
    set plot(lastX) $x
    set plot(lastY) $y
}
