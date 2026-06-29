# systray.tcl --
#
# This demonstration script showcases the tk systray and tk sysnotify commands.
#

if {![info exists widgetDemo]} {
    error "This script should be run from the \"widget\" demo."
}

set w .systray
destroy $w
toplevel $w
wm title $w "System Tray Demonstration"
positionWindow $w

## See Code / Dismiss buttons
pack [addSeeDismiss $w.buttons $w] -side bottom -fill x

catch {tk systray destroy}
set trayIconExists false

set iconmenu .menubar
destroy $iconmenu
menu $iconmenu
$iconmenu add command -label "Status" -command { puts "status icon clicked" }
$iconmenu add command -label "Exit" -command exit

pack [label $w.l -text "This demonstration showcases
	the tk systray and tk sysnotify commands.
	Running this demo creates the systray icon.
	Clicking the buttons below modifies and destroys the icon
	and displays the notification."]

image create photo book -data R0lGODlhDwAPAKIAAP//////AP8AAMDAwICAgAAAAAAAAAAAACwAAAAADwAPAAADSQhA2u5ksPeKABKSCaya29d4WKgERFF0l1IMQCAKatvBJ0OTdzzXI1xMB3TBZAvATtB6NSLKleXi3OBoLqrVgc0yv+DVSEUuFxIAOw==

labelframe $w.f -text "Tray Icon"
button $w.f.b0 -text "Create" -command create
button $w.f.b1 -text "Modify" -command modify
button $w.f.b2 -text "Destroy" -command remove
pack $w.f.b0 $w.f.b1 $w.f.b2 -padx 3p -pady 3p -side left -expand true -fill x

button $w.b3 -text "Display Notification" -command notify
pack $w.f $w.b3 -fill x -padx 3p -pady 3p

proc create {} {
    global trayIconExists
    if {$trayIconExists} {
	tk_messageBox -message "Systray icon already exists"
	return
    }
    tk systray create -image book -text "Systray sample" \
	    -button1 {puts "foo"} \
	    -button3 {tk_popup $iconmenu [winfo pointerx .] [winfo pointery .]}
    set trayIconExists true
}

proc modify {} {
    global trayIconExists
    if {!$trayIconExists} {
	tk_messageBox -message "Please create systray icon first"
	return
    }
    image create photo page -data R0lGODlhCwAPAKIAAP//////AMDAwICAgAAA/wAAAAAAAAAAACwAAAAACwAPAAADMzi6CzAugiAgDGE68aB0RXgRJBFVX0SNpQlUWfahQOvSsgrX7eZJMlQMWBEYj8iQchlKAAA7
    tk systray configure -image page
    tk systray configure -text "Modified text"
    tk systray configure -button1 {puts "this is a different output"}
    tk systray configure -button3 {puts "hello yall"}
}

proc notify {} {
    global trayIconExists
    if {!$trayIconExists} {
	tk_messageBox -message "Please create systray icon first"
	return
    }
    tk sysnotify  "Alert" "This is an alert"
}

proc remove {} {
    global trayIconExists
    if {!$trayIconExists} {
	tk_messageBox -message "Systray icon was already destroyed"
	return
    }
    tk systray destroy
    set trayIconExists false
}

create
