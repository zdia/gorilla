 ############################################################################
 #
 # Hypertext viewhelp.tcl -- A help system based on wiki 1194 and tile
 # by Keith Vetter, May 2007
 #
 # based on Ttk 8.5 and modified for use with Password Gorilla with 
 # permission of Keith Vetter (18.08.2010 zdia)
 # 
 # added msgcat calls in order to get internationalization for the help
 #

 interp alias {} ::button {} ::ttk::button
 
 namespace eval ::Help {
    variable W                                  ;# Various widgets
    variable pages                              ;# All the help pages
    variable alias                              ;# Alias to help pages
    variable state
    variable font TkTextFont
 
    array unset pages
    array unset alias
    array unset state
    array set state {history {} seen {} current {} all {} allTOC {} haveTOC 0}
    array set W {top .helpSystem main "" tree ""}
		
		# The following array has to restore the GUI navigation title which
		# will be lowered by Help::FindPage:
		#
    # array set alias {index Index previous Previous back Back search Search
		#		 history History next Next}
		#
		# It was replaced by "aliasList" in Help::FindPage which takes care
		# of the navigation titles and can be filled with msgcat entries.
		# This list is placed in Help::ReadHelpFiles because at this early
		# stage package msgcat is not loaded.
		#
		# FIXME: Rework all the initialisation stuff
			
 }
 
 ## BEGIN ON HELP
 ##+##########################################################################
 #
 # Help Section
 #
 # Based on http://wiki.tcl.tk/1194
 #
 #  AddPage title aliases text  -- register a hypertext page
 #  Help ?title?                -- bring up a toplevel showing the specified page
 #                                 or a index of titles, if not specified
 #
 # Hypertext pages are in a subset of Wiki format:
 #   indented lines come in fixed font without evaluation;
 #   blank lines break paragraphs
 #   a line starting with "   * " gets a bullet
 #   a line starting with "   - " gets a dash
 #   a line starting with "   1. " will be a numbered list
 #    repeating the initial *,- or "1" will indent the list
 #   a line starting with "   | " will simply be an indented block paragraph (only one level of indent at the moment)
 #
 #   text enclosed by '''<text>''' is embolden
 #   text enclosed by ''<text>'' is italics
 #   all lines without leading blanks are displayed without explicit
 #      linebreak (but possibly word-wrapped)
 #   a link is the title of another page in brackets (see examples at
 #      end). Links are displayed underlined and blue (or purple if they
 #      have been visited before), and change the cursor to a pointing
 #      hand. Clicking on a link of course brings up that page.
 #
 # In addition, you get "Index", "Search" (case-insensitive regexp in
 # titles and full text), "History", and "Back" links at the bottom of
 # pages.
 
 
 ##+##########################################################################
 #
 # ::Help::Help -- initializes and creates the help dialog
 #
proc ::Help::Help {{title ""}} {
	variable W

	if {![winfo exists $W(top)]} {
			::Help::DoDisplay $W(top)
	}

	wm deiconify $W(top)
	::Help::Show $title

}
 ##+##########################################################################
 #
 # ::Help::ReadHelpFiles -- reads "help.txt" in the packages directory
 # and creates all the help pages.
 #
 proc ::Help::ReadHelpFiles {dir locale} {
	# Initiates the Viewhelp module.
	# It sets the language locale for msgcat and loads the appropriate
	# language file into the namespace ::Help. Then it looks in the passed
	# directory for the manual contained in the "help.txt" file.
	# The text is split into section according to the "title:" markers.
	# Then the sections are passed to ::Help::AddPage to populate the
	# ::Help::pages() array with all help pages. Finally ::Help::BuildTOC
	# constructs the TOC.
	#
	# dir - the directory in which the file help.txt is searched for
	# locale - the locale according to the resource file .gorillarc
	#

	# viewhelp.tcl is sourced before the preference() array is populated.
	# Thus we have to get the locale by parameter from namespace ::gorilla.

	variable aliasList

	mclocale $locale
	mcload [file join $::gorilla::Dir msgs help]

	set aliasList [list [mc Back] [mc Search] [mc Previous] [mc Next] [mc History] [mc Index] ]
	set fname [file join $dir help.txt]
	set fin [open $fname r]
	set data [read $fin] ; list
	close $fin
  
	regsub -all -line {^-+$} $data \x01 data
	regsub -all -line {^\#.*$\n} $data {} data
	foreach section [split $data \x01] {
			set n [regexp -line {^title:\s*(.*)$} $section => title]
			set title [mc $title]

			if {! $n} {
					puts "Bad help section\n'[string range $section 0 400]'"
					continue
			}
			set aliases {}
			foreach {. alias} [regexp -all -line -inline {^alias:\s*(.*)$} $section] {
					lappend aliases $alias
			}

			regsub -all -line {^(title:|alias:).*$\n} $section {} section
			::Help::AddPage $title $aliases $section
	}
	::Help::BuildTOC
 }
 ##+##########################################################################
 #
 # ::Help::AddPage -- Adds another page to the help system
 #
 proc ::Help::AddPage {title aliases body} {
    variable pages
    variable state
    variable alias
 
    set title [string trim $title]
    set body [string trim $body "\n"]
    regsub -all {\\\n} $body {} body            ;# Remove escaped lines
    regsub -all {[ \t]+\n} $body "\n" body      ;# Remove trailing spaces
    regsub -all {([^\n])\n([^\s])} $body {\1 \2} body ;# Unwrap paragraphs
 
    set pages($title) $body
 
    lappend aliases [string tolower $title]
    foreach name $aliases { set alias([string tolower $name]) $title }
 
    if {[lsearch $state(all) $title] == -1} {
        set state(all) [lsort [lappend state(all) $title]]
    }
 }

 ##+##########################################################################
 #
 # ::Help::DoDisplay -- Creates our help display. If we have tile 0.7.8 then
 # we will also have a TOC pane.
 #
proc ::Help::DoDisplay { top } {
  variable state
 
  if {[info exists ::gorilla::toplevel($top)]} {
    wm deiconify $top
  } else {
		toplevel $top
		wm title $top [ mc "Help" ]
		wm transient $top .
		set ::gorilla::toplevel($top) $top
		wm protocol $top WM_DELETE_WINDOW "gorilla::CloseDialog $top"
		
		gorilla::TryResizeFromPreference $top
		
		frame $top.bottom -bd 2 -relief ridge
		button $top.b -text [mc "Close"] -command "gorilla::CloseDialog $top"
		pack $top.bottom -side bottom -fill both
		pack $top.b -side bottom -expand 1 -pady 10 -in $top.bottom
	
		set P $top.p
		
		;# Need tags on treeview
		set state(haveTOC) 1
		::ttk::panedwindow $P -orient horizontal
	
		pack $P -side top -fill both -expand 1
		ttk::frame $P.toc -relief ridge
		frame $P.help -bd 2 -relief ridge
	
		$P add $P.toc -weight 1
		$P add $P.help -weight 1
		::Help::CreateTOC $P.toc
		::Help::CreateHelp $P.help
		CenterWindow $top
	}
}
 ##+##########################################################################
 #
 # ::Help::CreateTOC -- Creates a TOC display from the treeview widget
 #
 proc ::Help::CreateTOC {TOC} {
    variable W
 
    set W(tree) $TOC.tree
    scrollbar $TOC.sby -orient vert -command "$W(tree) yview"
    #scrollbar $TOC.sbx -orient hori -command "$W(tree) xview"
 
    ::ttk::treeview $W(tree) -padding {0 0 0 0} -selectmode browse \
        -yscrollcommand "$TOC.sby set" ;#$ -xscrollcommand "$TOC.sbx set"
 
    grid $W(tree) $TOC.sby -sticky news
    #grid $TOC.sbx -sticky ew
    grid rowconfigure $TOC 0 -weight 1
    grid columnconfigure $TOC 0 -weight 1
 
     $W(tree) heading #0 -text [mc "Table of Contents"]
    $W(tree) tag configure link -foreground blue
    $W(tree) tag configure linkSelected -foreground white
    # NB. binding to buttonpress sometimes "misses" clicks
    #$W(tree) tag bind link <ButtonPress> ::Help::ButtonPress
    bind $W(tree) <<TreeviewSelect>> ::Help::TreeviewSelection
    ::Help::BuildTOC
 }
 ##+##########################################################################
 #
 # ::Help::CreateHelp -- Creates our main help widget
 #
 proc ::Help::CreateHelp {w} {
    variable W
    variable font
 
    set W(main) $w.t
    text $w.t -border 5 -relief flat -wrap word -state disabled -width 60 \
        -yscrollcommand "$w.s set" -padx 5 -font $font
    scrollbar $w.s -orient vert -command "$w.t yview"
    pack $w.s -fill y -side right
    pack $w.t -fill both -expand 1 -side left
 
    $w.t tag config link -foreground blue -underline 1
    $w.t tag config seen -foreground purple4 -underline 1
    $w.t tag bind link <Enter> "$w.t config -cursor hand2"
    $w.t tag bind link <Leave> "$w.t config -cursor {}"
    $w.t tag bind link <1> "::Help::Click $w.t %x %y"
    $w.t tag config hdr -font \
        "[font actual [$w.t cget -font]] -size 18"
    $w.t tag config fix -font \
        "[font actual [$w.t cget -font]] -family Courier"
    $w.t tag config bold -font \
        "[font actual [$w.t cget -font]] -weight bold"
    $w.t tag config italic -font \
        "[font actual [$w.t cget -font]] -slant italic"
 
    set l1 [font measure $font "   "]
    set l2 [font measure $font "   \u2022   "]
    set l3 [font measure $font "       \u2013   "]
    set l3 [expr {$l2 + ($l2 - $l1)}]
    $w.t tag config bullet -lmargin1 $l1 -lmargin2 $l2
    $w.t tag config number -lmargin1 $l1 -lmargin2 $l2
    $w.t tag config dash -lmargin1 $l1 -lmargin2 $l2
    $w.t tag config bar -lmargin1 $l2 -lmargin2 $l2
 
    bind $w.t <n> [list ::Help::Next $w.t 1]
    bind $w.t <p> [list ::Help::Next $w.t -1]
    bind $w.t <b> [list ::Help::Back $w.t]
    bind $w.t <Key-space> [bind Text <Key-Next>]
 
    # Create the bitmap for our bullet
    if {0 && [lsearch [image names] ::img::bullet] == -1} {
        image create bitmap ::img::bullet -data {
            #define bullet_width  11
            #define bullet_height 9
            static char bullet_bits[] = {
                0x00,0x00, 0x00,0x00, 0x70,0x00, 0xf8,0x00, 0xf8,0x00,
                0xf8,0x00, 0x70,0x00, 0x00,0x00, 0x00,0x00
            };
        }
    }
 }
 ##+##########################################################################
 #
 # ::Help::Click -- Handles clicking a link on the help page
 #
 proc ::Help::Click {w x y} {
    set range [$w tag prevrange link "[$w index @$x,$y] + 1 char"]
    if {[llength $range]} {::Help::Show [eval $w get $range]}
 }
 ##+##########################################################################
 #
 # ::Help::Back -- Goes back in help history
 #
 proc ::Help::Back {w} {
    variable state
 
    set l [llength $state(history)]
    if {$l <= 1} return
    set last [lindex $state(history) [expr {$l-2}]]
    set history [lrange $state(history) 0 [expr {$l-3}]]
    ::Help::Show $last
 }
 ##+##########################################################################
 #
 # ::Help::Next -- Goes to next help page
 #
 proc ::Help::Next {w dir} {
    variable state
 
    set what $state(all)
    if {$state(allTOC) ne {}} {set what $state(allTOC)} ;# TOC order if we can
    set n [lsearch -exact $what $state(current)]
    set n [expr {($n + $dir) % [llength $what]}]
    set next [lindex $what $n]
    ::Help::Show $next
 }
 ##+##########################################################################
 #
 # ::Help::Listpage -- Puts up a help page with a bunch of links (all or history)
 #
 proc ::Help::Listpage {w llist} {
    foreach i $llist {$w insert end \n; ::Help::Showlink $w $i}
 }
 ##+##########################################################################
 #
 # ::Help::Search -- Creates search help page
 #
 proc ::Help::Search {w} {
    $w insert end "\nSearch phrase:      "
    entry $w.e -textvar ::Help::state(search)
    $w window create end -window $w.e
    focus $w.e
    $w.e select range 0 end
    bind $w.e <Return> "::Help::DoSearch $w"
    button $w.b -text [mc "Search!"] -command "::Help::DoSearch $w"
    $w window create end -window $w.b
 }
 ##+##########################################################################
 #
 # ::Help::DoSearch -- Does actual help search
 #
 proc ::Help::DoSearch {w} {
    variable pages
    variable state
 
    $w config -state normal
    $w insert end "\n\nSearch results for '$state(search)':\n"
    foreach i $state(all) {
        if {[regexp -nocase $state(search) $i]} { ;# Found in title
            $w insert end \n
            ::Help::Showlink $w $i
        } elseif {[regexp -nocase -indices -- $state(search) $pages($i) pos]} {
            set p1 [expr {[lindex $pos 0]-20}]
            set p2 [expr {[lindex $pos 1]+20}]
            regsub -all \n [string range $pages($i) $p1 $p2] " " context
            $w insert end \n
            ::Help::Showlink $w $i
            $w insert end " - ...$context..."
        }
    }
    $w config -state disabled
 }
 ##+##########################################################################
 #
 # ::Help::Showlink -- Displays link specially
 #
 proc ::Help::Showlink {w link {tag {}}} {
    variable state
 
    set tag [concat $tag link]
    set title [::Help::FindPage $link]

    if {[lsearch -exact $state(seen) $title] > -1} {
        lappend tag seen
    }
		
    $w insert end $link $tag
 }
 ##+##########################################################################
 #
 # ::Help::FindPage -- Finds actual pages given a possible alias
 #
 proc ::Help::FindPage {title} {
    variable pages
    variable alias
		variable aliasList

    if {[info exists pages($title)]} { return $title }
    set title2 [string tolower $title]
    if {[info exists alias($title2)]} { return $alias($title2) }
    if {[lsearch $aliasList $title] >= 0} { return $title }
    return "ERROR!"
 }
 ##+##########################################################################
 #
 # ::Help::Show -- Shows help or meta-help page
 #
 proc ::Help::Show {title} {
    variable pages
    variable alias
    variable state
    variable W
 
    set w $W(main)
    set title [ ::Help::FindPage $title ]
    if {[lsearch -exact $state(seen) $title] == -1} {lappend state(seen) $title}
    $w config -state normal
    $w delete 1.0 end
    $w insert end $title hdr "\n"
    set next 0                                  ;# Some pages have no next page
    
    array set navigation [ subst { 
      "[mc Back]" { ::Help::Back $w; return}
      "[mc History]" { ::Help::Listpage $w [list $state(history)]}
      "[mc Next]"    { ::Help::Next $w 1; return}
      "[mc Previous]" { ::Help::Next $w -1; return}
      "[mc Index]"   { ::Help::Listpage $w [list $state(all)] }
      "[mc Search]"  { ::Help::Search $w}
      default  { ::Help::ShowPage $w [list $title] ; set next 1}
    }]

    if { [array get navigation $title] eq "" } {
      eval $navigation(default)
    } else {
      eval $navigation($title)
    }
    
    # Add bottom of the page links
    $w insert end \n------\n {}
    if {! $state(haveTOC) && [info exists alias(toc)]} {
        $w insert end TOC link " - " {}
    }
    $w insert end [mc Index] link " - " {} [mc Search] link
    if {$next} {
        $w insert end " - " {} [mc Previous] link " - " {} [mc Next] link
    }
    if {[llength $state(history)]} {
        $w insert end " - " {} [mc History] link " - " {} [mc Back] link
    }
 
    $w insert end \n
    lappend state(history) $title
    $w config -state disabled
 
    set state(current) $title

 }

 ##+##########################################################################
 #
 # ::Help::ShowPage -- Shows a text help page, doing wiki type transforms
 #
 proc ::Help::ShowPage {w title} {
    variable pages
 
    set endash \u2013
    set emdash \u2014
    set bullet \u2022
 
    $w insert end \n                            ;# Space down from the title
    if {! [info exists pages($title)]} {
        set lines [list "This help page is missing."]
    } else {
        set lines [split $pages($title) \n]
    }

    foreach line $lines {
        set tag {}
        set op1 ""
        if {[regexp {^ +([1*\-|]+)\s*(.*)} $line -> op txt]} {
            set op1 [string index $op 0]
            set lvl [expr {[string length $op] - 1}]
            set indent [string repeat "     " $lvl]
            if {$op1 eq "1"} {                  ;# Number
                if {! [info exists number($lvl)]} { set number($lvl) 0 }
                set tag number
                incr number($lvl)
                $w insert end "$indent $number($lvl)" $tag
            } elseif {$op1 eq "*"} {            ;# Bullet
                set tag bullet
                $w insert end "$indent $bullet " $tag
            } elseif {$op1 eq "-"} {            ;# Dash
                set tag dash
                $w insert end "$indent $endash " $tag
            } elseif { $op1 eq "|" } {          ; # Bar
                set tag bar
            }
            set line $txt
        } elseif {[string match " *" $line]} {  ;# Line beginning w/ a space
            set line [mc "$line"]
            $w insert end $line\n fix
            unset -nocomplain number

            continue
        }

				set line [mc $line]

        if {$op1 ne "1"} {unset -nocomplain number}
				# now look for markups
        while {1} {
            set link0 [set bold0 [set ital0 $line]]
            set n1 [regexp {^(.*?)[[](.*?)[]](.*$)} $line -> link0 link link1]
            set n2 [regexp {^(.*?)'''(.*?)'''(\s*.*$)} $line -> bold0 bold bold1]
            set n3 [regexp {^(.*?)''(.*?)''(\s*.*$)} $line -> ital0 ital ital1]
            if {$n1 == 0 && $n2 == 0 && $n3 == 0} break
 
            set len1 [expr {$n1 ? [string length $link0] : 9999}]
            set len2 [expr {$n2 ? [string length $bold0] : 9999}]
            set len3 [expr {$n3 ? [string length $ital0] : 9999}]
 
            if {$len1 < $len3} {
                $w insert end $link0 $tag
                ::Help::Showlink $w $link $tag
                set line $link1
            } elseif {$len2 <= $len3} {
                $w insert end $bold0 $tag $bold [concat $tag bold]
                set line $bold1
            } else {
                $w insert end $ital0 $tag $ital [concat $tag italic]
                set line $ital1
            }
        }
        $w insert end "$line\n" $tag
    }
 }
 ##+##########################################################################
 #
 # ::Help::BuildTOC -- Fills in our TOC widget based on a TOC page
 #
 proc ::Help::BuildTOC {} {
    variable W
    variable pages
    variable state
 
    set state(allTOC) {}                        ;# All pages in TOC ordering
    if {! [winfo exists $W(tree)]} return
    set tocData $pages([::Help::FindPage toc])
    $W(tree) delete [$W(tree) child {}]
    unset -nocomplain parent
    set parent() {}
 
    regsub -all {'{2,}} $tocData {} tocData
    foreach line [split $tocData \n] {
        set n [regexp {^\s*(-+)\s*(.*)} $line => dashes txt]
        if {! $n} continue
 
        set isLink [regexp {^\[(.*)\]$} $txt => txt]
				set txt [mc $txt]
        set pDashes [string range $dashes 1 end]
        set parent($dashes) [$W(tree) insert $parent($pDashes) end -text $txt]

        if {$isLink} {
            $W(tree) item $parent($dashes) -tag link -open true
 
            set ptitle [::Help::FindPage $txt]
            if {[lsearch $state(allTOC) $ptitle] == -1} {
                lappend state(allTOC) $ptitle
            }
        }
    }
 }
 ##+##########################################################################
 #
 # ::Help::ButtonPress -- Handles clicking on a TOC link
 # !!! Sometimes misses clicks, so we're using TreeviewSelection instead
 #
 proc ::Help::ButtonPress {} {
    variable W
 
    set id [$W(tree) selection]
    set title [$W(tree) item $id -text]
    ::Help::Show $title
 }
 ##+##########################################################################
 #
 # ::Help::TreeviewSelection -- Handles clicking on any item in the TOC
 #
 proc ::Help::TreeviewSelection {} {
    variable W

		if { ![info exists ::Help::oldLink] } {
			set ::Help::oldLink ""
		}

		# Closing the Help window does not unset ::Help::oldLink so we do it
		# here
		# Todo: write ::Help::CloseDialog with unsetting of ::Help::oldLink
		if { ![$W(tree) exists $::Help::oldLink]} {
			set ::Help::oldLink ""
		}

    set id [$W(tree) selection]
    set title [$W(tree) item $id -text]
    set tag [$W(tree) item $id -tag]

		if { $tag eq "linkSelected" } {
			return
		}
		
    if {$tag eq "link"} {
			$W(tree) item $id -tag linkSelected
			$W(tree) item $::Help::oldLink -tag link
			set ::Help::oldLink $id
			::Help::Show $title
    } else {                                    ;# Make all children visible
        set last [lindex [$W(tree) children $id] end]
        if {$last ne {} && [$W(tree) item $id -open]} {
            $W(tree) see $last
        }
				if { $::Help::oldLink ne "" } {
					$W(tree) item $::Help::oldLink -tag link
					set ::Help::oldLink ""
				}
    }
 }
 proc CenterWindow {w} {
    wm withdraw $w
    update idletasks
    set x [expr [winfo screenwidth $w]/2 - [winfo reqwidth $w]/2 \
               - [winfo vrootx [winfo parent $w]]]
    set y [expr [winfo screenheight $w]/2 - [winfo reqheight $w]/2 \
               - [winfo vrooty [winfo parent $w]]]
    wm geom $w +$x+$y
    wm deiconify $w
 }
 
 ################################################################
 #
 # Debugging routines
 #
 
 ##+##########################################################################
 #
 # ::Help::Reset -- (for testing), resets all help info
 #
 proc ::Help::Reset {} {
    variable W
    variable state
    variable pages
    variable alias
 
    array unset pages
    array unset state
    array set state {history {} seen {} current {} all {} allTOC {}}
    array unset alias
 
    foreach title {Back History Next Previous Index Search} {
        set alias([string tolower $title]) $title
    }
 
    destroy $W(top)
 }
 ##+##########################################################################
 #
 # ::Help::Sanity -- Checks for missing help links
 #
 proc ::Help::Sanity {} {
    variable state
 
    set missing {}
    foreach page $state(all) {
        set m [::Help::CheckLinks $page]
        if {$m ne {}} {
            puts "$page: $m"
            set missing [concat $missing $m]
        }
    }
    return $missing
 }
 ##+##########################################################################
 #
 # ::Help::CheckLinks -- Checks one page for missing help links
 #
 proc ::Help::CheckLinks {title} {
    variable pages
    variable alias
 
    set missing {}
    set title [::Help::FindPage $title]
    foreach {. link} [regexp -all -inline {\[(.*?)\]} $pages($title)] {
        if {! [info exists alias([string tolower $link])]} {
            lappend missing $link
        }
    }
    return $missing
 }

 proc WIKIFIX {txt} {
    regsub -all {\n } $txt "\n" txt
    return $txt

 }
 ## END ON HELP
 
return

 ################################################################
 
 ################################################################
 
 ::Help::AddPage "Table of Contents" TOC [WIKIFIX {
    - [Welcome to the Help System]
    - [What's New]
    - Formatting
      -- [Basic Formatting]
      -- [Aliases]
      -- [Lists]
    - [Creating the TOC]
    - [To Do]
 }]
 ::Help::AddPage "Welcome to the Help System" overview [WIKIFIX {
 This is a simple hypertext help system.
 
 It's based on ''A Little Hypertext System'' so it includes:
  * Hyperlinks to other help pages
  * Simple searching ability
  * History
  * Simple wiki formatting
 
 This new version also includes (see [What's New])
  * [Table of Contents]
  * Hypertext [aliases]
  * [Multi-level Lists]
  11. numeric lists
  ** bullet lists
  -- dash list
  * '''Bold text'''
  * ''Italic text''
  }]
 ::Help::AddPage "What's New" "" [WIKIFIX {
 Here are some features of this help system not found in the previous version:
    * Table of Content
    * Bullets
    * Multiple levels of indentation
      -- like this
      -- ''and this''
      --- '''and even this'''
    * Aliases
    -- So this link [Welcome to the Help System]
    -- is the same as this link [Overview]
 
 }]
 ::Help::AddPage "Basic Formatting" "Formatting" [WIKIFIX {
 The formatting code for the help pages follows much like the
 tcler's wiki.
 '''Links, lists, bold, italics, unformatted''' are
 all done the same way.
 
 [Aliases] and [multi-level lists] are only slightly more complicated.
 
 }]
 ::Help::AddPage "Aliases" {alias} [WIKIFIX {
 ''Aliases'' allow the same page to be referenced by different names.
 So this link [Welcome to the Help System]
 is the same as this link [Overview].
 }]
 ::Help::AddPage "Multi-level Lists" "lists" [WIKIFIX {
   1. numbered list
   1. numbered list
   11. numbered list
   11. numbered list
   1. numbered list
   1. numbered list
 
   * bullet list
   ** nested bullet list
   ** nested bullet list
   * bullet list
 
    - dash lists
    -- nested dashed list
    -- nested dashed list
    - dash lists
 
 }]
 ::Help::AddPage "Creating the TOC" "" [WIKIFIX {
 The '''Table of Content''' is a just a help page with the
 name (or [alias]) '''TOC''' which gets displayed in a
 tile treeview widget. You can also view the [TOC] as a
 normal help page.
 
 Each line of the TOC help page that begins with a dash becomes
 a node in the treeview. The level of indentation dictates the
 tree structure.
 }]
 
 ::Help::AddPage "To Do" {} [WIKIFIX {
  1. Visual clues in TOC about what is a link (don't know treeview well enough to do this)
  1. Mouse buttons 4 & 5 do history back and forward like Firefox and IE
  1. Image support--not hard, I just haven't needed it
  1. msgcat support
  1. read help data from separate file (actually this is done, but for simplicity I omitted here)
 }]
 
 ################################################################
 
# return

# Testing comments

# new line: after an empty line (see WIKIFIX)
