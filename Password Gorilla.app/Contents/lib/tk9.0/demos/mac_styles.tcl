# mac_styles.tcl --
#
# This demonstration script creates a toplevel window containing a notebook
# whose pages provide examples of the various mac-specific widgets that are
# provided via special values for the -style option.

if {![info exists widgetDemo]} {
    error "This script should be run from the \"widget\" demo."
}

set w .mac_styles
catch {destroy $w}
toplevel $w
package require tk
wm title $w "Tk Aqua Widgets"
wm iconname $w "mac_styles"
positionWindow $w
##
# System images we use in our buttons

set featherImg [file join $tk_demoDirectory images Tk_feather.png]
set starryImg [file join $tk_demoDirectory images starry_night.png]
set fieldImg [file join $tk_demoDirectory images plowed_field.png]
image create nsimage action -source NSAction -width 48 -height 48
image create nsimage bonjour -source NSBonjour -width 48 -height 48
image create nsimage bonjour1 -source NSBonjour -width 48 -height 48 -pressed 1
image create nsimage tkfeather -source $featherImg -as file -width 48 -height 48
image create nsimage tkfeather1 -source $featherImg -as file -width 48 -height 48 -pressed 1
image create nsimage starry -source $starryImg -as file -width 96 -radius 10
image create nsimage starry1 -source $starryImg -as file -width 96 -radius 10 -pressed 1
image create nsimage starry2 -source $starryImg -as file -width 96 -radius 10 -ring 3
image create nsimage field -source $fieldImg -as file -width 96 -radius 10
image create nsimage field1 -source $fieldImg -as file -width 96 -radius 10 -pressed 1
image create nsimage field2 -source $fieldImg -as file -width 96 -radius 10 -ring 3
image create nsimage add -source NSAddTemplate -width 20 -height 20
image create nsimage remove -source NSRemoveTemplate -width 18 -height 4

# Off state and variables for checkbuttons and radio buttons
set off {!selected !alternate}
variable $w.checkVar
variable $w.radioVar
variable $w.triangleVar
variable $w.popupVar
variable $w.stepVar
variable $w.comboVar

# Make a disclosure triangle change state when clicked.
proc toggleTriangle {tri} {
    $tri instate {user1} {
	$tri state {!user1}
	return
    }
    $tri instate {!user1} {
	$tri state {user1}
    }
}

proc popupButton {win varName firstValue args} {
    upvar #0 $varName var
    if {![info exists var]} {
	set var $firstValue
    }
    ttk::menubutton $win -textvariable $varName -menu $win.menu -direction flush
    menu $win.menu -tearoff 0
    $win.menu add radiobutton -label $firstValue -variable $varName
    foreach i $args {
	$win.menu add radiobutton -label $i -variable $varName
    }
    return $win.menu
}

set mag [encoding convertfrom utf-8 "\xf0\x9f\x94\x8d"]

proc searchFocusOut {e} {
    global mag
    if {[$e get] eq ""} {
	$e configure -foreground gray60
	$e insert 0 "Search"
    }
}

proc searchFocusIn {e} {
    if {[$e cget -foreground] == {gray60}} {
	$e delete 0 end
	$e configure -foreground black
    }
}

## Make the notebook and set up Ctrl+Tab traversal
ttk::notebook $w.notebook
ttk::notebook::enableTraversal $w.notebook

# Frames pane
set framesFrame [ttk::frame $w.notebook.frames -padding {40 35 40 50}]
$w.notebook add $framesFrame -text "Frames"
pack [ttk::labelframe $framesFrame.darker -text Darker -padding {50 30 50 50}] \
    -fill both -expand 1
pack [ttk::label $framesFrame.darker.label -padding {0 0 0 6} \
	  -text "This Group Box is nested to depth 2"] \
    -fill x
pack [ttk::labelframe $framesFrame.darker.darker -text "Darker Still" -padding 24] \
    -fill both -expand 1
pack [ttk::label $framesFrame.darker.darker.label \
	  -text "This Group Box is nested to depth 3"] -fill x
pack [button $framesFrame.darker.darker.tkbutton -text "Tk Button" -width 7 \
	  -highlightbackground systemWindowBackgroundColor3] -pady 10
pack [ttk::button $framesFrame.darker.darker.ttkbutton -text "Ttk Button" \
	  -width 7 -padding {-4 0 -4 0}] \
	  -pady 3
# Button pane
set buttonFrame [ttk::frame $w.notebook.buttons -padding {100 20 0 20}]
$w.notebook add $buttonFrame -text "Buttons"
grid columnconfigure $buttonFrame 0 -minsize 100
grid columnconfigure $buttonFrame 1 -minsize 100

set plain [ttk::button $buttonFrame.plain -text Button -padding {-12 0}]
popupButton $buttonFrame.options .popupVar "Item 1" "Item 2" "Item 3"
set options $buttonFrame.options
set check [ttk::checkbutton $buttonFrame.check -text Check -variable .checkVar]
set radio [ttk::frame $buttonFrame.radio]
pack [ttk::radiobutton $radio.r1 -text "Radio 1" -variable .radioVar -value 1] -pady 4
pack [ttk::radiobutton $radio.r2 -text "Radio 2" -variable .radioVar -value 2] -pady 4
set triangle [ttk::checkbutton $buttonFrame.triangle -style Item -variable TriangleVar]
bind $triangle <Button-1> {toggleTriangle %W}
set bonjour [ttk::button $buttonFrame.bonjour -style ImageButton -text Bonjour \
		     -image {bonjour pressed bonjour1}]
set feather [ttk::button $buttonFrame.feather -style ImageButton -text Tk \
		      -image {tkfeather pressed tkfeather1}]
set gradient [ttk::frame $buttonFrame.gradient]
pack [ttk::button $buttonFrame.gradient.add -style GradientButton \
	  -image add -padding {2 0}] -side left
pack [ttk::button $buttonFrame.gradient.remove -style GradientButton \
	  -image remove -padding {2 8}] -side left
set disclosure [ttk::checkbutton $buttonFrame.disclosure -style DisclosureButton]
set help [ttk::button $buttonFrame.help -style HelpButton];

$check state $off
$radio.r1 state $off
$radio.r2 state $off

grid [ttk::label $buttonFrame.plainLabel -text "Push Button:"]\
    -row 0 -column 0 -padx 4 -sticky e
grid $plain -pady 4 -row 0 -column 1 -sticky w
grid [ttk::label $buttonFrame.optionsLabel -text "Pop-up Button:"]\
    -row 1 -column 0 -padx 4 -sticky e
grid $options  -pady 4 -row 1 -column 1 -sticky w
grid [ttk::label $buttonFrame.checkLabel -text "Check Button:"]\
    -row 2 -column 0 -padx 4 -sticky e
grid $check    -pady 4 -row 2 -column 1 -sticky w
grid [ttk::label $buttonFrame.radioLabel -text "Radio Buttons:"]\
    -row 3 -column 0 -padx 4 -sticky e
grid $radio    -pady 4 -row 3 -column 1 -sticky w
grid [ttk::label $buttonFrame.triangleLabel -text "Disclosure Triangle:"]\
    -row 4 -column 0 -padx 4 -sticky e
grid $triangle -pady 4 -row 4 -column 1 -sticky w
grid [ttk::label $buttonFrame.disclosureLabel -text "Disclosure Button:"]\
    -row 5 -column 0 -padx 4 -sticky e
grid $disclosure -row 5 -column 1 -sticky w
grid [ttk::label $buttonFrame.imageLabel -text "Image Buttons:"]\
    -row 7 -column 0 -padx 4 -sticky e
grid $bonjour -pady 4 -row 6 -rowspan 4 -column 1 -sticky w
grid $feather -padx 10 -pady 4 -row 6 -rowspan 4 -column 2
grid [ttk::label $buttonFrame.gradentLabel -text "Gradient Buttons:"]\
-row 10 -column 0 -padx 4 -sticky e
grid $gradient -pady 4 -row 10 -column 1 -sticky w
grid [ttk::label $buttonFrame.helpLabel -text "Help Button:"]\
-row 11 -column 0 -padx 4 -sticky e
grid $help -row 11 -column 1 -sticky w

#ttk::button .f.b1 -style Toolbutton -image action
#pack $buttonFrame

# Entries Frame
set entryFrame [ttk::frame $w.notebook.entries -padding {0 30 80 0}]
grid columnconfigure $entryFrame 0 -minsize 200
$w.notebook add $entryFrame -text "Entries"

set textfield [ttk::entry $entryFrame.text -width 17]
set searchfield [ttk::entry $entryFrame.search -width 1]
set combo [ttk::combobox $entryFrame.combo -width 1 -textvariable comboVar \
	   -values {"Item 1" "Item 2" "Item 3"}]
set stepper [ttk::spinbox $entryFrame.stepper -width 1 -textvariable stepVar \
		 -from 99000 -to 101000 -increment 1]
set stepVar 100000
searchFocusOut $searchfield
bind $searchfield <FocusIn> {searchFocusIn %W}
bind $searchfield <FocusOut> {searchFocusOut %W}

grid [ttk::label $entryFrame.l0 -text "Text Field"] -row 0 -column 0 -padx 20 -sticky e
grid $textfield -sticky ew -row 0 -column 1 -pady 13
grid [ttk::label $entryFrame.l1 -text "Search Field"] -row 1 -column 0 -padx 20 -sticky e
grid $searchfield -sticky ew -row 1 -column 1 -pady 13
grid [ttk::label $entryFrame.l2 -text "Combo Box"] -row 2 -column 0 -padx 20 -sticky e
grid $combo -sticky ew -row 2 -column 1 -pady 13
grid [ttk::label $entryFrame.l3 -text "Stepper"] -row 3 -column 0 -padx 20 -sticky e
grid $stepper -sticky ew -row 3 -column 1 -pady 13

#Scales Frame
set scaleFrame [ttk::frame $w.notebook.scales -padding {0 40 0 80}]
$w.notebook add $scaleFrame -text "Scales"

variable topVar 50
set topSlider [ttk::scale $scaleFrame.topSlider -from 0 -to 100 \
		   -length 280 -variable topVar]
set topProgress [ttk::progressbar $scaleFrame.topProgress \
		     -maximum 100 -variable topVar]

variable bottomVar 50
set bottomSlider [ttk::scale $scaleFrame.bottomSlider -from 0 -to 100 \
		      -length 280 -variable bottomVar]
$bottomSlider state alternate
set bottomProgress [ttk::progressbar $scaleFrame.bottomProgress \
		    -maximum 100 -variable bottomVar]


grid $topSlider -padx 80 -pady 12 -sticky ew -row 0 -column 0 -columnspan 2
grid $topProgress -padx 120 -pady 15 -sticky ew -row 1 -column 0 -columnspan 2
grid [ttk::frame $scaleFrame.spacer] -row 2 -column 0 -columnspan 2 -pady 32

grid $bottomSlider -padx 80 -sticky new -row 3 -column 0 -columnspan 2
grid [ttk::label $scaleFrame.low -text Low -padding {70 0 0 0}] \
    -row 4 -column 0 -sticky sw
grid [ttk::label $scaleFrame.high -text High -padding {0 0 70 0}] \
    -row 4 -column 1 -sticky se
grid $bottomProgress -padx 120 -pady 15 -sticky ew -row 5 -column 0 -columnspan 2

#Appearance Frame
set appearanceFrame [ttk::frame $w.notebook.appearance -padding {0 40 0 80}]
grid [ttk::label $w.notebook.appearance.info -justify left -padding {0 20 0 40}\
	  -text "Use the image buttons below to view this demo in light or dark mode."] \
    -row 0 -column 0 -columnspan 3
set light [ttk::button $appearanceFrame.light -style ImageButton -text Light \
	       -image {field pressed field1 selected field2} \
	       -command "beLight $appearanceFrame $w"]
grid columnconfigure $appearanceFrame 1 -minsize 10
grid $light -row 1 -column 0 -sticky e
set dark [ttk::button $appearanceFrame.dark -style ImageButton -text Dark \
	      -image {starry pressed starry1 selected starry2} \
	      -command "beDark $appearanceFrame $w"]
grid $dark -row 1 -column 2 -sticky w
if { [wm attributes $w -isdark] } {
    $dark state selected
} else {
    $light state selected
}
proc beLight {f w} {
    wm attributes $w -appearance aqua
    # A small delay is needed for the appearance change to complete.
    after 20 [list $f.dark state !selected]
    after 20 [list $f.light state selected]
}

proc beDark {f w} {
    wm attributes $w -appearance darkaqua
    # A small delay is needed for the appearance change to complete.
    after 20 [list $f.light state !selected]
    after 20 [list $f.dark state selected]
}
$w.notebook add $appearanceFrame -text "Appearance"

## See Code / Dismiss
pack [addSeeDismiss $w.buttons $w] -side bottom -fill x

## Notebook
pack $w.notebook -side bottom -fill both -expand 1 -padx 16 -pady 16

