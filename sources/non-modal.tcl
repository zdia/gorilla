
# setup code - wire the new edit dialog into the menus

if { [ catch { .mbar.login index "New Edit*" } ] } {
	.mbar.login add command -command ::gorilla::LoginDialog::EditLogin -label "New Edit"
}

if { [ catch { .popupForLogin index "New Edit*" } ] } {
	catch { .popupForLogin add command -command ::gorilla::LoginDialog::EditLogin -label "New Edit" }
}

if { [ catch { .mbar.login index "New Add*" } ] } {
	.mbar.login add command -command ::gorilla::LoginDialog::AddLogin -label "New Add"
}

if { [ catch { .popupForLogin index "New Add*" } ] } {
	catch { .popupForLogin add command -command ::gorilla::LoginDialog::AddLogin -label "New Add" }
}

# for testing - rl -> reload
proc rl { script } {
	# A temporary testing proc for the non-modal edit dialog changes.
	# Erases all state/windows created by the non-modal code, then sources the code file again.
	# script - The pathname to the code file to reload
	foreach win [ winfo children . ] { 
		if { [ string match .nmLoginDialog* $win ] } {
			destroy $win
		}
	}
	catch { namespace delete ::gorilla::LoginDialog }
	source $script

}

if { ! [ winfo exists .push ] } {
	toplevel .push
	button .push.b1 -text "Source [ info script ]" -command [ list rl [ info script ] ]
	pack .push.b1 
} 

# main code begins below, everything above is for development purposes

#
# Non-modal password edit dialog boxes
#
# Put everything into a namespace so that there is no interference with the
# rest of PWGorilla
#

namespace eval ::gorilla::LoginDialog { 

	namespace path ::gorilla

	variable seq 0
	
	# The idle-windows list and the push/pop procs are used to impliment
	# window reuse like in the rest of PWGorilla.  However the normal
	# PWGorilla method of window reuse does not work when there are
	# multiple windows to be remembered.  Idle-windows is a stack of
	# toplevel names that are not in use and push/pop manipulate that
	# stack in the obvious manner
	 
	variable idle-windows [ list ]

	namespace import ::tcl::mathop::+ ::tcl::mathop::* ::tcl::mathop::/ 

	# arbiter is a dict used to prevent more than one open edit dialog for an
	# individual db record number

	variable arbiter [ dict create ]
  
# -----------------------------------------------------------------------------

	proc push { win } {

		# add an window name to the end of the namespace variable idle-windows
		# win - the window name to "push" onto the idle-windows stack variable
		# Side-effect: Modifes namespace variable idle-windows.
		#
		# This is used to maintain a list of "inactive" withdrawn dialogs for
		# reuse in future edit requests.  Such avoids having to rebuild both the
		# dialog as well as the dialog state space and GUI handling procs.

		variable idle-windows
		lappend idle-windows $win
	} ; # end proc push

# -----------------------------------------------------------------------------

	# see http://wiki.tcl.tk/1923
	proc K { x y } { set x }

# -----------------------------------------------------------------------------

	proc pop { } {

		# Remove a window name from the stack in the idle-windows namespace variable.
		# Side-effect: Modifes namespace variable idle-windows.
		#
		# This is used to maintain a list of "inactive" withdrawn dialogs for
		# reuse in future edit requests.  Such avoids having to rebuild both the
		# dialog as well as the dialog state space and GUI handling procs.

		variable idle-windows
		return [ K [ lindex ${idle-windows} end ] [ set idle-windows [ lrange ${idle-windows} 0 end-1 ] ] ]
		# returns the name of the window that was popped from the stack.
	}

# -----------------------------------------------------------------------------

	proc info { } {
		# A testing proc for debugging purposes
		variable idle-windows
		return "idle-windows -> '${idle-windows}'"
		# returns the contents of the idle-windows namespace variable stack
	}

# -----------------------------------------------------------------------------

	# parameters ================================================================
	# -rn       - record number to edit, default of -999 means create new record
	# -group    - initial group name to use for creation of a new record
	# -treenode - the ttk::treeview node ID for editing an existing record
	#           + This is simply passed through to the final Ok proc for use
	#           + in updating an existing record in the treeview.
	# ===========================================================================

	proc LoginDialog { args } {

		# Open a dialog to edit/create an entry in the login DB.
		#
		# -rn - Record number from Itcl login DB to edit.  Magic record number
		#  -999 is defined to mean edit a new (blank) record.  Defaults to -999
		#  if not provided.
		#
		# -group - Set initial "group" name to apply to a new record.  This
		#  initializes the "group" field of the edit dialog.
		#
		# -treenode - The ttk::treeview node ID of an existing record when a
		#  user requests editing of an existing record.  This is used to update
		#  the tree display when a user clicks "Ok" to their changes.
		#
		# Requirements: If -rn is not -999 then the record number must exist in
		# the Itcl DB when called.  In addition, to edit an existing record, the
		# -treenode value must also be passed in.
		#
		# Additionally, a simple check is made such that there is a one to one
		# mapping of existing record numbers to open edit dialogs.  It is
		# disallowed to edit the exact same record in two independent dialogs
		# simultaneously.

		variable arbiter

		if { 0 != [ expr { [ llength $args ] % 2 } ] } {
			error "[ namespace current ]::LoginDialog: Must have an even number of arguments."
		}

		ArrangeIdleTimeout

		# very simple command line handling, first set default values, then
		# overwrite those valies with args (if any)

		array set {} [ list -rn -999 -group "" -treenode "" ]
		array set {} $args

		# a bit of sanity checking of the inputs
		if { $(-rn) != -999 } {
			# != -999 means an attempt to edit an existing record
			if { $(-treenode) eq "" } {
				error "[ namespace current ]::LoginDialog: Editing an existing record requires that -treenode option be non-null."
			}
			if { ! [ $::gorilla::db existsRecord $(-rn) ] } {
				error "[ namespace current ]::LoginDialog: Can not edit a record number ('$(-rn)') which does not exist in the database."
			}

			# should only have one dialog open per unique record entry in the db

			if { [ dict exists $arbiter $(-rn) ] } {
				wm deiconify [ dict get $arbiter $(-rn) ]
				raise [ dict get $arbiter $(-rn) ]
				return
			}

		} ; # end if -rn != -999


		set top [ pop ] 
		if { $top ne "" } {

			set pvns [ get-pvns-from-toplevel $top ]

			wm deiconify $top

		} else {

			variable seq
			set top [ toplevel .nmLoginDialog$seq ]
			set pvns [ namespace eval [ namespace current ]::$seq { namespace current } ] ; # pvns -> private variable name space
			incr seq

			wm title $top [ mc "Add/Edit/View Login" ]
			wm protocol $top WM_DELETE_WINDOW [ namespace code [ list DestroyLoginDialog $top ] ]

			# add a binding to clean out the namespace if the window is ever explicity destroyed

# fixme - the catch is here for testing, should not be needed for production
			bind $top <Destroy> [ list catch "namespace delete $pvns" ]

			BuildLoginDialog $top $pvns
			
		} ; # end if top ne ""

		# store away -treenode value in the pvns for use later during processing
		# by the ${pvns}::Ok proc
		set ${pvns}::treenode $(-treenode)

		if { $(-rn) != -999 } {
			# remember that we are editing this -rn in this $top window
			dict set arbiter $(-rn) $top
		}

		set ::gorilla::toplevel($top) $top
		TryResizeFromPreference $top
		
		${pvns}::PopulateLoginDialog $(-rn) $(-group)

	} ; # end proc LoginDialog
	
# -----------------------------------------------------------------------------

	proc DestroyLoginDialog { win } {
	
		# Used to withdraw, reset, and store for later an edit dialog from the
		# screen.
		#
		# win - the toplevel name of the edit dialog to withdraw, reset, and
		#  store.
	
		variable arbiter
		unset -nocomplain ::gorilla::toplevel($win)
		push $win

		# unmap the ppf pane, if it is mapped - otherwise the width added by the
		# ppf pane will end up getting added as a base minwidth value - i.e.,
		# the window will be permanently wider than it should be.
		set [ get-pvns-from-toplevel $win ]::overridePasswordPolicy 0
		
		wm withdraw $win

		# remove the entry for this window from the arbiter dict
		dict unset arbiter [ set [ get-pvns-from-toplevel $win ]::rn ]

	} ; # end proc DestroyLoginDialog

# -----------------------------------------------------------------------------

	# the name of the private variable namespace is the numeric suffix of
	# the toplevel name, so extract the numeric suffix from the toplevel
	# name

	proc get-pvns-from-toplevel { top } {

		# Extracts the private namespace name for an edit dialog
		#
		# top - the toplevel name of an edit dialog from which to extract the
		#  private variable namespace
	  
		return [ namespace current ]::[ lindex [ regexp -inline {([0-9]+)$} $top ] 1 ] 
		
		# returns The name of the private variable namespace associated with the
		# passed toplevel name.
		
	} ; # end proc get-pvns-from-toplevel

# -----------------------------------------------------------------------------

	proc BuildLoginDialog { top pvns } {

		set widget(top) $top

		ttk::style configure Wrapping.TLabel -wraplength {}

		set std_lbl_opts [ list -anchor e -justify right -padding {10 0 5 0} -style Wrapping.TLabel ]
		
		foreach {child label} { group Group     title Title   url URL 
		                        user Username   password Password } {
			grid [ ttk::label $top.l-$child -text [ wrap-measure [ mc "$label:" ] ] {*}$std_lbl_opts ] \
			     [ set widget($child) [ ttk::entry $top.e-$child -width 40 -textvariable ${pvns}::$child ] ] \
					-sticky news -pady 5
		} ; # end foreach {child label}

		# password should show "*" by default
		$widget(password) configure -show "*"

		grid [ ttk::label $top.l-notes -text [ wrap-measure [ mc "Notes:" ] ] {*}$std_lbl_opts ] \
		     [ set widget(notes) [ set ${pvns}::notes [ text $top.e-notes -width 40 -height 5 -wrap word ] ] ] \
		     -sticky news -pady 5

		grid rowconfigure    $top $widget(notes) -weight 1
		grid columnconfigure $top $widget(notes) -weight 1

		foreach {child label} { last-pass-change "Last Password Change:"    last-modified "Last Modified:" } {	
			grid [ ttk::label $top.l-$child -text [ wrap-measure [ mc $label ] ] {*}$std_lbl_opts ] \
			     [ ttk::label $top.e-$child -textvariable ${pvns}::$child -width 40 -anchor w ] \
			     -sticky news -pady 5
		}

		# bias the lengths of the labels to a slightly larger size than the average
		ttk::style configure Wrapping.TLabel -wraplength [ + 40 [ wrap-measure ] ]

		set bf  [ ttk::frame $top.bf  ]	; # button frame
		set frt [ ttk::frame $bf.top ]	; # frame right - top

		ttk::button $frt.ok -width 16 -text "OK" -command [ list namespace inscope $pvns Ok ]
		ttk::button $frt.c -width 16 -text [ mc "Cancel" ] -command [ namespace code [ list DestroyLoginDialog $top ] ]

		pack $frt.ok $frt.c -side top -padx 10 -pady 5
		pack $frt -side top -pady 20

		set frb [ ttk::frame $bf.pws ] ; # frame right - bottom
		set widget(showhide) [ ttk::button $frb.show -width 16 -text [ mc "Show Password" ] -command [ list namespace inscope $pvns ShowPassword ] ]

		ttk::button $frb.gen -width 16 -text [ mc "Generate Password" ] -command [ list namespace inscope $pvns MakeNewPassword ]
		ttk::checkbutton $frb.override -text [ mc "Override Password Policy" ] -variable ${pvns}::overridePasswordPolicy 
			# -justify left

		set ${pvns}::overridePasswordPolicy 0

		pack $frb.show $frb.gen $frb.override -side top -padx 10 -pady 5

		pack $frb -side top -pady 20

		grid $bf -row 0 -column 2 -rowspan 8 -sticky news

		# this adds a feedback line along the bottom edge of the window
		grid [ set widget(feedback) [ ttk::label $top.feedback -borderwidth 3 ] ] -columnspan 3 -sticky news

		set ${pvns}::feedbacktimer -1	; # to keep track of "after" id value
		

		# create, but do not make visible yet, a pane for overriding password
		# policy settings

		set ppf [ set widget(ppf) [ ttk::frame $top.ppf -borderwidth 2 -relief solid ] ] ; # ppf -> Pass Policy Frame
		
		set plf [ ttk::frame $ppf.plen -padding [ list 0 10 0 0 ] ] ; # ppf -> Pass Length Frame
		ttk::label $plf.l -text [ mc "Password Length" ]
		spinbox $plf.s -from 1 -to 999 -increment 1 \
			-width 4 -justify right \
			-textvariable ${pvns}::PassPolicy(length)
		pack $plf.l -side left
		pack $plf.s -side left -padx 10

		pack $plf -side top -anchor w -padx 10 -pady 3

		foreach {item label} [ list                                            \
			uselowercase {Use lowercase letters}                                 \
			useuppercase {Use UPPERCASE letters}                                 \
			usedigits    {Use digits}                                            \
			usehexdigits {Use hexadecimal digits}                                \
			usesymbols   {Use symbols (%, $, @, #, etc.)}                        \
			easytoread   {Use easy to read characters only (e.g. no "0" or "O")} ] {

			ttk::checkbutton $ppf.$item -text [ wrap-measure [ mc $label ] ] \
			        -variable ${pvns}::PassPolicy($item) \
				-style Wrapping.TCheckbutton

			pack $ppf.$item -anchor w -side top -padx 10 -pady 3

		} ; # end foreach item,label 

		ttk::style configure Wrapping.TCheckbutton -wraplength [ wrap-measure ]


		# force geometry calculations to happen - the ppf frame map/unmap code
		# depends on this having been run now

		update idletasks
		
		# do not allow resize smaller than the native requested size of the
		# internal widgets

		wm minsize $top [ winfo reqwidth $top ] [ winfo reqheight $top ]

		# Now build the callback procs that will handle this window's gui
		# interactions with the user

		build-gui-callbacks $pvns [ array get widget ]

	} ; # end proc buildLoginDialog
	
# -----------------------------------------------------------------------------

	# a proc to make computing the average pixel width of a set of lines of
	# text easier
	# if called with a parameter, adds the length of that parameter to an internal list
	# if called without a parameter, returns the average accumulated length and resets itself to empty

	proc wrap-measure { {text ""} } {
		variable ___accumulated_lengths___
		if { ( $text eq "" ) && ( [ llength $___accumulated_lengths___ ] > 0 ) } {
			return [ K [ calculateWraplength $___accumulated_lengths___ ] [ set ___accumulated_lengths___ [ list ] ] ]
		} else {
			lappend ___accumulated_lengths___ [ font measure [ ttk::style configure . -font ] $text ]
			return $text
		}
	} ; # end proc wraplength

# -----------------------------------------------------------------------------

	# calculates a "wraplength" value from the list of integer lengths passed
	# to the proc.  The resulting length will be an integer representing the
	# mean of the passed in list, rounded up to the next even unit of 10.
  
	proc calculateWraplength { lengths } {
		return [ * [ / [ + [ / [ + {*}$lengths ] [ llength $lengths ] ] 9 ] 10 ] 10 ]
	} ; # end proc computeWraplength 

# -----------------------------------------------------------------------------

	# smacro -> simple macro processor.  The idea is inspired by Lisp macros,
	# but this simple implimentation has more in common with cpp style macros,
	# in that it is a simple string substiution.

	proc smacro { map body } {
		return [ string map [ convert_map $map ] $body ]
	} ; # end proc smacro

# -----------------------------------------------------------------------------

	# preprocess the macro substitution map.  Each key in the map is prefixed
	# by m: and then the result is surrounded by hyphens, i.e. "-m:key-". 
	# This format was chosen because this is highly unlikely to be utilized as
	# valid Tcl code otherwise.

	proc convert_map { map } {

		foreach {key value} $map {
			lappend result "-m:$key-" $value
		} ; # end foreach key,value in map

		return $result

	} ; # end proc smacro_map

# -----------------------------------------------------------------------------

	proc build-gui-callbacks { pvns widgets } {

		# This builds the callback procs that will handle this dialogs
		# interaction with the user - generation of these procs borrows a bit of
		# ideas from Lisp macros to avoid having to pass a bunch of constants
		# around in proc parameters (i.e., the pvns name or the widget path/proc
		# names) or having the procs reference a bunch of quasi-global variables
		#
		# pvns - the name of the private variable namespace for the dialog.  The
		#  GUI interaction procs will be built within this namespace.
		#
		# widgets - A key/value list (i.e. a dict or a list from array get) of
		#  descriptive widget names and the actual widget window pathname to
		#  apply as the "macro" transformations for each proc built.  Each key
		#  will be substituted for the value of that key in the body of each
		#  proc, with the result being that the resulting procs are "customized"
		#  at build time to know which GUI widgets to access for performing
		#  their relevant functions.

		namespace eval $pvns [ smacro $widgets {
		
		  namespace import ::tcl::mathop::+ ::tcl::mathop::-
		
			namespace path ::gorilla

			# since TogglePassPolicyFrame is a trace callback, it will need "args"
			# to accept the extra args that trace adds - the args are ignored

			proc TogglePassPolicyFrame { args } {

				variable overridePasswordPolicy

				# Getting the resizing below to work right was quite a test.  The
				# resize code does two things, expands (or contracts) the width and
				# increases (or decreases) the minwidth of the toplevel window by
				# the width of the ppf pane.
				
				# This resizing code turned out to be necessary because when gorilla
				# withdrew and then deiconified edit windows upon a lock/unlock
				# event, it also set an explicit geometry.  By setting a geometry
				# the window would no longer auto-resize when the ppf pane was
				# mapped/unmapped.
				
				# Clearing the set geometry was my first attempt, but doing that
				# also caused the window to resize to the widget native sizes, even
				# if the user had enlarged it before hand manually.  Therefore, to
				# work around that issue this code that adds an increment upon
				# mapping the ppf pane, and subtracts the same amount upon unmapping
				# the ppf frame, came about.
				
				# The extra 10 in the increment/decrement calculations is because of
				# the -padx 5 given to grid.  Five pixels per side of padding is 10
				# extra pixels above the width of the ppf frame itself.

				# Note - this code also depends upon the BuildDialog proc having run
				# "update idletasks" to assure that the initial window geometry
				# calculations have all occurred.

				if { $overridePasswordPolicy } {
					# true - map the ppf frame
				  
					if { ! [ winfo ismapped -m:ppf- ] } {
						# only expand window size if the ppf is not currently mapped

						set parent [ winfo parent -m:ppf- ]
						set inc [ + 10 [ winfo reqwidth -m:ppf- ] ]

						wm geometry $parent "=[ + $inc [ winfo width $parent ] ]x[ winfo height $parent ]"

						foreach {minw minh} [ wm minsize $parent ] { break }
						wm minsize $parent [ + $inc $minw ] $minh
					}

					grid -m:ppf- -row 0 -column 3 -sticky news -rowspan 9 -padx 5 -pady 5

				} else {

					if { [ winfo ismapped -m:ppf- ] } {
						# only shrink window size if the ppf was mapped to start with

						set parent [ winfo parent -m:ppf- ]
						set dec [ + 10 [ winfo reqwidth -m:ppf- ] ]

						wm geometry $parent "=[ - [ winfo width $parent ] $dec ]x[ winfo height $parent ]"

						foreach {minw minh} [ wm minsize $parent ] { break }
						wm minsize $parent [ - $minw $dec ] $minh 
					}

					grid forget -m:ppf- 

				} ; # end if overridePasswordPolicy

			} ; # end proc TogglePassPolicyFrame

			# install a variable trace on the password policy checkbutton variable
			# to trigger opening/closing of the adjust pass policy pane.

			trace add variable overridePasswordPolicy write [ namespace code TogglePassPolicyFrame ]

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc ShowPassword { } {
				-m:password- configure -show {}
				-m:showhide- configure -command [ namespace code HidePassword ] -text [ mc "Hide Password" ]
			} ; # end proc ShowPassword

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -
		
			proc HidePassword { } {
				-m:password- configure -show "*"
				-m:showhide- configure -command [ namespace code ShowPassword ] -text [ mc "Show Password" ]
			} ; # end proc HidePassword

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc MakeNewPassword { } {

				variable overridePasswordPolicy
				variable PassPolicy
				variable password
				
				if { $overridePasswordPolicy } {
					set policy [ array get PassPolicy ] 
				} else {
					set policy [ GetDefaultPasswordPolicy ] 
				} ; # end if override

				if { [ catch { set newPassword [ GeneratePassword $policy ] } oops ] } {
					feedback [ mc "Password policy settings invalid." ]
				} else {
					set password $newPassword
					::pwsafe::int::randomizeVar newPassword
				} ; # end if catch

			} ; # end proc MakeNewPassword

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc feedback { text } {
				-m:feedback- configure -relief sunken -text $text -background yellow
				set-feedback-timer 300 clearHighlight
			} ; # end proc feedback

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc clearHighlight { } {
				-m:feedback- configure -background {}
				set-feedback-timer 9700 clearFeedback
			} ; # end proc clearHighlight

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc clearFeedback { } {
				variable feedbacktimer
				-m:feedback- configure -relief flat -text "" -background {}
				set feedbacktimer -1
			} ; # end proc clearFeedback

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc set-feedback-timer { length next } {
				variable feedbacktimer
				if { $feedbacktimer != -1 } {
					after cancel $feedbacktimer
				}
				set feedbacktimer [ after $length [ namespace code $next ] ]
			} ; # end proc set-feedback-timer

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			# extracts fields from the gorilla db record and inserts them into the
			# proper linked variables or widgets in the dialog

			proc PopulateLoginDialog { in_rn in_group } {

				variable rn
				variable overridePasswordPolicy 0
				variable PassPolicy 
				array set PassPolicy [ GetDefaultPasswordPolicy ]

				foreach item { group title url user password } {
					variable $item
					set $item [ dbget $item $in_rn ]
				}

				if { $in_group ne "" } {
					set group $in_group
				}

				-m:notes- delete 0.0 end
				-m:notes- insert end [ dbget notes $in_rn ]
				
				foreach item { last-pass-change last-modified } {
					variable $item
					set $item [ dbget $item $in_rn [ mc "<unknown>" ] ]
				}

				clearFeedback

				set rn $in_rn
				
				HidePassword

			} ; # end proc PopulateLoginDialog

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc PopulateRecord { rn } {

				set varlist { group title user password url }
				
				foreach var $varlist {
					variable $var
				}

				set modified 0
				set now [clock seconds]

				if { [ dbget uuid $rn ] eq "" } {
					if { ! [ catch { package present uuid } ] } {
						dbset uuid $rn [uuid::uuid generate]
					}                              
				}

				foreach element $varlist {

					set value [ set $element ]

					if { $value != "" } {
						if { ! [ string equal $value [ dbget $element $rn ] ] } {
							set modified 1
							if { $element eq "password" } {
								dbset last-pass-change $rn $now
							}
						}
						dbset $element $rn $value
					} else {
						dbunset $element $rn
						set modified 1
					}

					::pwsafe::int::randomizeVar $element 

				} ; # end foreach element
				
				# handle notes separately
				set value [ -m:notes- get 0.0 end ]
				if { $value != "" } {
					if { ! [ string equal $value [ dbget notes $rn ] ] } {
						set modified 1
					}
					dbset notes $rn $value
				} else {
					dbunset notes $rn
					set modified 1
				}

				::pwsafe::int::randomizeVar value

				if { $modified } {
					dbset last-modified $rn $now
				}

				return $modified

			} ; # end proc PopulateRecord

		# = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = -

			proc Ok { } {

				variable title
				variable group
				variable rn
				variable treenode
        
				if { 0 == [ string length [ string trim $title ] ] } {
					feedback [ mc "This login must have a title." ]
					return
				}

				if { [ catch { ::pwsafe::db::splitGroup $group } ] } {
					feedback [ mc "This login's group name is not valid." ] $pvns
					return
				}

				if { $rn == -999 } {
					set modified [ PopulateRecord [ set newrn [ $::gorilla::db createRecord ] ] ]
				} else {
					set modified [ PopulateRecord $rn ]
				}

				if { $modified } {

					if { $rn == -999 } {
						set ::gorilla::status [ mc "New login added." ]
						AddRecordToTree $newrn
					} else {
#						UpdateRecordInTree $rn $treenode
						# this takes a shortcut, for an existing record, simply delete from
						# tree then reinsert into tree
						$::gorilla::widgets(tree) delete $treenode
						AddRecordToTree $rn                   
						set ::gorilla::status [mc "Login modified."]
					}

					MarkDatabaseAsDirty

				} ; # end if modified

				[ namespace parent ]::DestroyLoginDialog -m:top-
        
			} ; # end proc Ok

		} ] ; # end smacro namespace eval

	} ; # end proc build-gui-callbacks

# -----------------------------------------------------------------------------

	proc EditLogin {} {
		ArrangeIdleTimeout

		if { [ llength [ set sel [ $::gorilla::widgets(tree) selection ] ] ] == 0 } {
			return                                                       
		}

		set node [ lindex $sel 0 ]
		set data [ $::gorilla::widgets(tree) item $node -values ]
		set type [ lindex $data 0 ]

		if {$type == "Group" || $type == "Root"} {
			return
		}

		set rn [lindex $data 1]

		LoginDialog -rn $rn -treenode $node

	} ; # end proc EditLogin

# -----------------------------------------------------------------------------

	proc AddLogin {} {

		set tree $::gorilla::widgets(tree)

		if { [ llength [ set sel [ $tree selection ] ] ] == 0 } {
			return                                                       
		}

		set node [ lindex $sel 0 ]
		set data [ $tree item $node -values ]
		set type [ lindex $data 0 ]

		switch -exact -- $type {
			Group	{ LoginDialog -group [ lindex $data 1 ] }
			Root	{ LoginDialog -group "" }
			Login	{ LoginDialog -group [ lindex [ $tree item [ $tree parent $node ] -values ] 1 ] }
		} 

	} ; # end proc AddLogin

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------

#	#
#	# Set up bindings
#	#
#
#	bind $top.l.group2 <Shift-Tab> "after 0 \"focus $top.r.top.ok\""
#	bind $top.l.title2 <Shift-Tab> "after 0 \"focus $top.l.group2\""
#	bind $top.l.user2 <Shift-Tab> "after 0 \"focus $top.l.title2\""
#	bind $top.l.pass2 <Shift-Tab> "after 0 \"focus $top.l.user2\""
#	bind $top.l.notes <Tab> "after 0 \"focus $top.r.top.ok\""
#	bind $top.l.notes <Shift-Tab> "after 0 \"focus $top.l.pass2\""
#
#	bind $top.l.group2 <Return> "set ::gorilla::guimutex 1"
#	bind $top.l.title2 <Return> "set ::gorilla::guimutex 1"
#	bind $top.l.user2 <Return> "set ::gorilla::guimutex 1"
#	bind $top.l.pass2 <Return> "set ::gorilla::guimutex 1"
#	bind $top.r.top.ok <Return> "set ::gorilla::guimutex 1"
#	bind $top.r.top.c <Return> "set ::gorilla::guimutex 2"
#

} ; # end namespace eval ::gorilla::LoginDialog
