# filebox.tcl --
#
# This demonstration script prompts the user to select a file.

if {![info exists widgetDemo]} {
    error "This script should be run from the \"widget\" demo."
}

package require tk

set w .filebox
catch {destroy $w}
toplevel $w
wm title $w "File Selection Dialogs"
wm iconname $w "filebox"
positionWindow $w

ttk::frame $w._bg
place $w._bg -x 0 -y 0 -relwidth 1 -relheight 1

ttk::label $w.msg -font $font -wraplength 4i -justify left -text "Enter a file name in the entry box or click on the \"Browse\" buttons to select a file name using the file selection dialog."
pack $w.msg -side top

## See Code / Dismiss buttons
set btns [addSeeDismiss $w.buttons $w]
pack $btns -side bottom -fill x

set f [ttk::frame $w.f]
foreach i {open save} {
    ttk::label $f.lab_$i -text "Select a file to $i:"
    ttk::entry $f.ent_$i -width 20
    ttk::button $f.but_$i -text "Browse ..." -command \
	    "fileDialog $w $f.ent_$i $i"
    grid $f.lab_$i $f.ent_$i $f.but_$i -pady 3p -sticky w
    grid configure $f.ent_$i -padx 3p -sticky ew
}
grid columnconfigure $f 1 -weight 1
pack $f -fill x -padx 1c

if {[tk windowingsystem] eq "x11"} {
    ttk::checkbutton $w.strict -text "Use Motif Style Dialog" \
	-variable tk_strictMotif -onvalue 1 -offvalue 0
    pack $w.strict -anchor c

    # This binding ensures that we don't run the rest of the demos
    # with motif style interactions
    bind $w.strict <Destroy> {set tk_strictMotif 0}
}

proc fileDialog {w ent operation} {
    #   Type names		Extension(s)	Mac File Type(s)
    #
    #---------------------------------------------------------
    set types {
	{"Text files"		{.txt .doc}	}
	{"Text files"		{}		TEXT}
	{"Tcl Scripts"		{.tcl}		TEXT}
	{"C Source Files"	{.c .h}		}
	{"All Source Files"	{.tcl .c .h}	}
	{"Image Files"		{.gif}		}
	{"Image Files"		{.jpeg .jpg}	}
	{"Image Files"		""		{GIFF JPEG}}
	{"All files"		*}
    }
    if {$operation == "open"} {
	global selected_type
	if {![info exists selected_type]} {
	    set selected_type "Tcl Scripts"
	}
	set file [tk_getOpenFile -filetypes $types -parent $w \
		-typevariable selected_type]
	puts "You selected filetype \"$selected_type\""
    } else {
	set file [tk_getSaveFile -filetypes $types -parent $w \
		-initialfile Untitled -defaultextension .txt]
    }
    if {[string compare $file ""]} {
	$ent delete 0 end
	$ent insert 0 $file
	$ent xview end
    }
}
