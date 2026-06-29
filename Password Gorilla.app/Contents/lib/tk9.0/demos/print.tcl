# print.tcl --
#
# This demonstration script showcases the tk print commands.
#

if {![info exists widgetDemo]} {
    error "This script should be run from the \"widget\" demo."
}

set w .print
destroy $w
toplevel $w
wm title $w "Printing Demonstration"
positionWindow $w

pack [label $w.l -text "This demonstration showcases
the tk print command. Clicking the buttons below
prints the data from the canvas and text widgets
using platform-native dialogs."] -side top

## See Code / Dismiss buttons
pack [addSeeDismiss $w.buttons $w] -side bottom -fill x

frame $w.m

image create photo logo -data {
R0lGODlhMABLAPUAAP//////zP//mf//AP/MzP/Mmf/MAP+Zmf+ZZv+ZAMz//8zM/8zMzMyZzMyZ
mcyZZsyZAMxmZsxmM8xmAMwzM8wzAJnMzJmZzJmZmZlmmZlmZplmM5kzZpkzM5kzAGaZzGZmzGZm
mWYzZmYzMzNmzDNmmTMzmTMzZgAzmQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH+BSAtZGwtACH5BAEKAAIALAAAAAAw
AEsAAAb+QIFwSCwahY9HRMI8Op/JJVNSqVqv2OvjyRU8slbIJGwYg60S5ZR6jRi/4ITBOhkYIOd8
dltEnAdmFQMJeoVXCEd/VnKGjRVOZ3NVgHlsjpBxVRCEYBIEAAARl4lgZmVgEQAKFx8Mo0ZnpqgA
Fyi2JqKGmGebWRIAILbCIo27cYFWASTCtievRXqSVwQfzLYeeYESxlnSVRIW1igjWHJmjBXbpKXe
FQTizlh1eJNVHbYf0LGc39XW2PIoVZE0whasWPSqFBBHrkKEA3QG0DFTEMXBUsjCWesg4oMFAGwg
tKsiwqA+jGiCiRPGAM6pLCVLGKHQ6EGJlc0IuDxzAgX+CCOW9DjAaUsEyAoT+GHpeSRoHgxEUWgA
UEUpFhMWgTbKEPUBAU15TBZxekYD0RMEqCDLIpYIWTAcmGEd9rWQBxQyjeQqdK/ZTWEO3mK5l+9N
o75SrcHhm9WwnlzNoA5zdM+JHz0HCPQdUauZowoFnSw+c2CBvw6dUXT4LMKE6EIHUqMexgCiIREk
nOwl7Q+FhNQoLuzOc6Kw3kIIVOLqjYKBYCwinmgo9CBEswfMAziK7mRDoQhcUZxwoBKFibq3n3jX
I0GyCPLC0DrS8GR1oaEoRBRYVhT99/qG4DcCA/yNU4Ajbjhhnx4P2DJggR3YZog6RyyYxwM9PSgM
BaP+sQdgIRL0JAKBwnTooRMAFWLdiPyJ8JwvTnyQoh5midCASh149ZkTIFAmHnzOZOBfIU6U4Mhd
4zF34DNEoDAhARGY50BvJkioyxFOGkKAShGkFsJwejiR5Xf8aZAaBp89coQJjuDXAQOApekEm45A
NaAtIbyYxREf0OlICCK841uaahZBQjyfjXCACYjuaASjhFagRKSFNtloHg+hYWIxRohnBQWCSSAh
BVZ+hkgRnlbxwJIVgIqGlaU6wkeTxHxjm6gVLImrFbHWVEQ1taZjWxJX7KqqnqgUEUxDwtqajrOa
RkqhEDcxWwECbEjxTYe9gojqOJQ6JO231ob72bSqAjh4RgfsjiDCCfDCK8K8I9TL7r33nvGtCO7C
O1dUAONk3LcBFxzwwEMwZ/DC4iAsRIE+CWNCbzeV8FfEtoDwVwnlacxMkcKQYIE/F5TQ2QcedUZC
agyc3NsFGrXVZMipWVBCzKv4Q0JvCviDsjAwf4ylxBeX0KcwGs81ccgqGS3MBxc3RjDDVAvdBRcf
eFy1MFd3bcQHJEQdlddkP5E1Cf9yXfbaV2d9RBAAOw==
}

# Create a copy of the image just created, magnified according to the
# display's DPI scaling level.  Since the zooom factor must be an integer,
# the copy will only be effectively magnified if $tk::scalingPct >= 200.
image create photo logo2
logo2 copy logo -zoom [expr {$tk::scalingPct / 100}]

set c [canvas $w.m.c -bg white]
pack $c -fill both -expand yes -fill both -side left

# For scaling-awareness specify the coordinates of the canvas items in points
# rather than pixels.  Create the items with a left and top padding of 15 pt.
$c create rectangle 15p 15p 165p 60p -fill blue -outline black	;# 150p x 45p
$c create oval 15p 75p 165p 120p -fill green			;# 150p x 45p
set imgId [$c create image 90p 135p -image logo2 -anchor n]

# Compute the scaled y coordinate of the next canvas item's top edge in pixels
lassign [$c bbox $imgId] x1 y1 x2 y2		;# x1, y1, x2, y2 are in pixels
incr y2 [expr {round(15 * [tk scaling])}]	;# convert 15 pt to pixels

$c create text 15p $y2 -anchor nw -font {Helvetica 12} \
	-fill black \
	-text "A short demo of simple canvas elements."

set txt {
Tcl, or Tool Command Language, is an open-source multi-purpose C library which includes a powerful dynamic scripting language. Together they provide ideal cross-platform development environment for any programming project. It has served for decades as an essential system component in organizations ranging from NASA to Cisco Systems, is a must-know language in the fields of EDA, and powers companies such as FlightAware and F5 Networks.

Tcl is fit for both the smallest and largest programming tasks, obviating the need to decide whether it is overkill for a given job or whether a system written in Tcl will scale up as needed. Wherever a shell script might be used Tcl is a better choice, and entire web ecosystems and mission-critical control and testing systems have also been written in Tcl. Tcl excels in all these roles due to the minimal syntax of the language, the unique programming paradigm exposed at the script level, and the careful engineering that has gone into the design of the Tcl internals.
}

set t [text $w.m.t -wrap word]
pack $t -side right -expand yes -fill both
$t insert end $txt

frame $w.f

pack [button $w.f.c -text "Print Canvas" -command [list tk print $w.m.c]] \
	-side left -anchor w -padx 3p
pack [button $w.f.t -text "Print Text" -command [list tk print $w.m.t]] \
	-side right -anchor e -padx 3p

pack $w.f -side bottom -fill x
pack $w.m -expand yes -fill both -side top
