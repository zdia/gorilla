# unicodeout.tcl --
#
# This demonstration script shows how you can produce output (in label
# widgets) using many different alphabets.

if {![info exists widgetDemo]} {
    error "This script should be run from the \"widget\" demo."
}

package require tk

set w .unicodeout
catch {destroy $w}
toplevel $w
wm title $w "Unicode Label Demonstration"
wm iconname $w "unicodeout"
positionWindow $w

label $w.msg -font $font -wraplength 4i -anchor w -justify left \
	-text "This is a sample of Tk's support for languages that use\
	non-Western character sets.  However, what you will actually see\
	below depends largely on what character sets you have installed,\
	and what you see for characters that are not present varies greatly\
	between platforms as well."
pack $w.msg -side top

## See Code / Dismiss buttons
set btns [addSeeDismiss $w.buttons $w]
pack $btns -side bottom -fill x

## The frame that will contain the sample texts.
pack [frame $w.f] -side bottom -expand 1 -fill both -padx 2m -pady 1m
grid columnconfigure $w.f 1 -weight 1
set i 0
proc addSample {w language args} {
    global font i
    set sample [join $args ""]
    set j [incr i]
    label $w.f.l$j -font $font -text "${language}:" -anchor nw -pady 0
    label $w.f.s$j -font $font -text $sample -anchor nw -width 30 -pady 0
    grid $w.f.l$j $w.f.s$j -sticky ew -pady 0
    grid configure $w.f.l$j -padx 1m
}

## A helper procedure that determines what form to use to express languages
## that have complex rendering rules...
proc usePresentationFormsFor {language} {
    switch [tk windowingsystem] {
	aqua {
	    # OSX wants natural character order; the renderer knows how to
	    # compose things for display for all languages.
	    return false
	}
	x11 {
	    # The X11 font renderers that Tk supports all know nothing about
	    # composing characters, so we need to use presentation forms.
	    return true
	}
	win32 {
	    # On Windows, we need to determine whether the font system will
	    # render right-to-left text. This varies by language!
	    try {
		package require registry
		set rkey [join {
		    HKEY_LOCAL_MACHINE
		    SOFTWARE
		    Microsoft
		    {Windows NT}
		    CurrentVersion
		    LanguagePack
		} \\]
		return [expr {
		    [string toupper $language] ni [registry values $rkey]
		}]
	    } trap error {} {
		# Cannot work it out, so use presentation forms.
		return true
	    }
	}
	default {
	    # Default to using presentation forms.
	    return true
	}
    }
}

## Processing when some characters are not currently cached by the display
## engine might take a while, so make sure we're displaying something in the
## meantime...
pack [label $w.wait -text "Please wait while loading fonts..." \
	-font {Helvetica 12 italic}]
set oldCursor [$w cget -cursor]
$w conf -cursor watch
update

## Add the samples...
if {[usePresentationFormsFor Arabic]} {
    # Using presentation forms (pre-layouted)
    addSample $w Arabic "ﺔﻴﺑﺮﻌﻟﺍ ﺔﻤﻠﻜﻟﺍ"
} else {
    # Using standard text characters
    addSample $w Arabic "الكلمة العربية"
}
addSample $w "Trad. Chinese"  "中國的漢字"
addSample $w "Simpl. Chinese" "汉语"
addSample $w French "Langue française"
addSample $w Greek "Ελληνική γλώσσα"
if {[usePresentationFormsFor Hebrew]} {
    # Visual order (pre-layouted)
    addSample $w Hebrew "תירבע בתכ"
} else {
    # Standard logical order
    addSample $w Hebrew "כתב עברית"
}
addSample $w Hindi "हिन्दी भाषा"
addSample $w Icelandic "Íslenska"
addSample $w Japanese "日本語のひらがな, 漢字とカタカナ"
addSample $w Korean "대한민국의 한글"
addSample $w Russian "Русский язык"
if {([tk windowingsystem] ne "x11") || (![catch {tk::pkgconfig get fontsystem} fs] && ($fs eq "xft"))} {
    addSample $w Emoji "😀💩👍🇳🇱"
}

## We're done processing, so change things back to normal running...
destroy $w.wait
$w conf -cursor $oldCursor
