# Copyright (c) 2009, Ashok P. Nadkarni
# All rights reserved.
# See the file WOOF_LICENSE in the Woof! root directory for license


# Ruff! formatter for doctools

namespace eval ruff::formatter::doctools {  
    namespace import [namespace parent]::*
    namespace import [namespace parent [namespace parent]]::*
}

proc ruff::formatter::doctools::escape {s} {
    # s - string to be escaped
    # Protects a string against doctools substitution in text
    # (not to be used inside a doctools command argument as that
    # follows Tcl escaping rules and are easiest escaped by enclosing
    # in braces)

    # It appears as though the only characters needing replacing are
    # [ and ]. Other Tcl special chars ($ \ etc.) do not matter
    # return [string map [list \\ \\\\ \[ \[lb\] \] \[rb\] \$ \\\$] $s]
    return [string map [list \[ \[lb\] \] \[rb\]] $s]

}


proc ruff::formatter::doctools::_fmtparas {paras} {
    # Given a list of paragraph elements, returns
    # them appropriately formatted for doctools.
    # paras - a flat list of pairs with the first element
    #  in a pair being the type, and the second the content
    #

    set sep ""
    set doc ""
    # Loop through all the paragraphs
    foreach {type content} $paras {
        append doc $sep
        switch -exact $type {
            paragraph {
                append doc [escape $content]\n
            }
            deflist {
                append doc [list_begin definitions]\n
                foreach {name desc} $content {
                    append doc "[def [const $name]] [escape $desc]\n"
                }
                append doc [list_end]\n
            }
            bulletlist {
                append doc [list_begin itemized]\n
                foreach desc $content {
                    append doc "\[item\] [escape $desc]\n"
                }
                append doc [list_end]\n
            }
            preformatted {
                append doc "\n\[example_begin\]\n"
                append doc [escape $content]
                append doc "\n\[example_end\]\n"
            }
            default {
                error "Unknown paragraph type '$type'."
            }
        }
        set sep [para]
    }
    return $doc
}

proc ruff::formatter::doctools::generate_proc_or_method {procinfo args} {
    # Formats the documentation for a proc in doctools format
    # procinfo - class information in the format returned
    #   by extract_ooclass
    #
    # The following options may be specified:
    #   -includesource BOOLEAN - if true, the source code of the
    #     procedure is also included. Default value is false.
    #   -displayprefix METHODNAME - the string to use as a prefix
    #     for the method or proc name. Usually caller supplies this
    #     as the class name for the method.
    #   -hidenamespace NAMESPACE - if specified as non-empty,
    #    program element names beginning with NAMESPACE are shown
    #    with that namespace component removed.
    #
    # Returns the proc documentation as a doctools formatted string.


    array set opts {-includesource false -displayprefix "" -hidenamespace ""}
    array set opts $args

    array set aproc $procinfo

    set doc ""
    
    # The quoting of strings below follows what I understand of doctools
    # - only [ and ] are special in text outside of doctools commands.
    # Such strings are quoted using the escape command. Arguments to
    # doctools commands are quoted using {}.

    set itemlist {};            # For the parameter descriptions
    set arglist {};             # For the synopsis
    # Construct command synopsis
    foreach param $aproc(parameters) {
        if {[dict get $param type] ne "parameter"} {
            # We do not deal with options here
            continue
        }
        set name [dict get $param name]
        set item [arg_def {} $name]
        if {[dict exists $param description]} {
            append item " [escape [dict get $param description]]"
        }
        if {[dict exists $param default]} {
            lappend arglist [opt [arg $name]]
            append item " (default \[const {[dict get $param default]}\])"
        } else {
            lappend arglist [arg $name]
        }
        lappend itemlist $item
    }
    set proc_name $opts(-displayprefix)[_trim_namespace $aproc(name) $opts(-hidenamespace)]

    if {$aproc(proctype) ne "method"} {
        append doc [eval [list call [cmd $proc_name]] $arglist]\n
    } else {
        switch -exact -- $aproc(name) {
            constructor {append doc [eval [list call [cmd "::oo::class create [_trim_namespace $aproc(class) $opts(-hidenamespace)]"]] $arglist]}
            destructor  {append doc [call "[arg OBJECT] [cmd destroy]"]}
            default  {append doc [eval [list call "[arg OBJECT] [cmd $aproc(name)]"] $arglist]}
        }
    }

    set sep ""
    # Parameter description
    if {[llength $itemlist]} {
        append doc [list_begin arguments]\n
        append doc [join $itemlist \n]\n
        append doc [list_end]\n
        set sep [para]
    }

    # Option description
    set itemlist {}
    foreach param $aproc(parameters) {
        if {[dict get $param type] ne "option"} {
            continue
        }
        set name [dict get $param name]
        if {[llength $name] > 1} {
            set arg  [arg [lrange $name 1 end]]
            set name [option [lindex $name 0]]
        } else {
            set name [option $name]
            set arg {}
        }
        if {[dict exists $param description]} {
            set desc [dict get $param description]
        } else {
            set desc "No description available."
        }
        lappend itemlist [opt_def $name $arg] [escape $desc]
    }
    if {[llength $itemlist]} {
        append doc $sep
        append doc [list_begin options]
        append doc [join $itemlist \n]\n
        append doc [list_end]\n
        set sep [para]
    }

    # Loop through all the paragraphs
    set paras [_fmtparas $aproc(description)]
    if {$paras ne ""} {
        append doc $sep$paras
        set sep [para]
    }

    if {[info exists aproc(return)] && $aproc(return) ne ""} {
        append doc $sep
        append doc [escape $aproc(return)]
    }

    if {$opts(-includesource)} {
        append doc $sep
        append doc "Source:"
        append doc [para]

        # Just [escape...] won't do it. We need the example_begin as well
        append doc "\[example_begin\]\n"
        append doc [escape $aproc(source)]
        append doc "\[example_end\]\n"
    }


    return "${doc}\n"
}

proc ruff::formatter::doctools::generate_ooclass {classinfo args} {

    # Formats the documentation for a class in doctools format
    # classinfo - class information in the format returned
    #   by extract_ooclass
    #
    # The following options may be specified:
    #   -includesource BOOLEAN - if true, the source code of the
    #     procedure is also included. Default value is false.
    #   -hidenamespace NAMESPACE - if specified as non-empty,
    #    program element names beginning with NAMESPACE are shown
    #    with that namespace component removed.
    #
    # Returns the class documentation as a doctools formatted string.

    array set opts {-includesource false -hidenamespace ""}
    array set opts $args

    array set aclass $classinfo
    set doc ""

    # The quoting of strings below follows what I understand of doctools
    # - only [ and ] are special in text outside of doctools commands.
    # Such strings are quoted using the escape command. Arguments to
    # doctools commands are quoted using {}.

    set class_name [_trim_namespace $aclass(name) $opts(-hidenamespace)]
    set displayprefix "$class_name."

    append doc [section "Class $class_name"]

    if {[info exists aclass(constructor)]} {
        append doc [list_begin definitions]
        append doc [generate_proc_or_method $aclass(constructor) \
                        -includesource $opts(-includesource) \
                        -hidenamespace $opts(-hidenamespace) \
                        -displayprefix $displayprefix]
        append doc [list_end]
    }


    if {[llength $aclass(superclasses)]} {
        append doc [subsection "Superclasses"]
        # Don't sort - order matters!
        append doc [escape [join [_trim_namespace_multi $aclass(superclasses) $opts(-hidenamespace)]]]\n
    }
    if {[llength $aclass(subclasses)]} {
        append doc [subsection "Subclasses"]
        # Don't sort - order matters!
        append doc [escape [join [_trim_namespace_multi $aclass(subclasses) $opts(-hidenamespace)]]]\n
    }
    if {[llength $aclass(mixins)]} {
        append doc [subsection "Mixins"]
        # Don't sort - order matters!
        append doc [escape [join [_trim_namespace_multi $aclass(mixins) $opts(-hidenamespace)]]]\n
    }
    if {[llength $aclass(filters)]} {
        append doc [subsection "Filters"]
        # Don't sort - order matters!
        append doc [escape [join $aclass(filters) ", "]]\n
    }
    if {[llength $aclass(external_methods)]} {
        append doc [subsection "External Methods"]
        set external_methods {}
        foreach external_method $aclass(external_methods) {
            # Qualify the name with the name of the implenting class
            foreach {name imp_class} $external_method break
            if {$imp_class ne ""} {
                set name [_trim_namespace $imp_class $opts(-hidenamespace)].$name
            }
            lappend external_methods $name
        }
        append doc [escape [join [lsort $external_methods] ", "]]\n
    }

    append doc [subsection Methods]

    append doc [list_begin definitions]
    if {0} {
        # We are showing constructor as part of class definition
        if {[info exists aclass(constructor)]} {
            append doc [generate_proc_or_method $aclass(constructor) \
                            -includesource $opts(-includesource) \
                            -hidenamespace $opts(-hidenamespace) \
                            -displayprefix $displayprefix]
        }
    }
    if {[info exists aclass(destructor)]} {
        append doc [generate_proc_or_method $aclass(destructor) \
                        -includesource $opts(-includesource) \
                        -hidenamespace $opts(-hidenamespace) \
                        -displayprefix $displayprefix]
    }

    # We want methods and forwarded methods listed together and sorted
    array set methods {}
    foreach methodinfo $aclass(methods) {
        set methods([dict get $methodinfo name]) [list method $methodinfo]
    }
    if {[info exists aclass(forwards)]} {
        foreach forwardinfo $aclass(forwards) {
            set methods([dict get $forwardinfo name]) [list forward $forwardinfo]
        }
    }

    foreach name [lsort [array names methods]] {
        foreach {type info} $methods($name) break
        if {$type eq "method"} {
            append doc [generate_proc_or_method $info \
                            -includesource $opts(-includesource) \
                            -hidenamespace $opts(-hidenamespace) \
                            -displayprefix $displayprefix]
        } else {
            # TBD - check formatting of forwarded methods
            # append doc [call [cmd "${displayprefix}[_trim_namespace [dict get $info name] $opts(-hidenamespace)]"]]
            append doc [call "[arg OBJECT] [cmd $name]"]
            # TBD - link to forwarded method if possible
            append doc "Method forwarded to [cmd [escape [dict get $info forward]]].\n"
        }
    }
    append doc [list_end]

    return $doc
}

proc ::ruff::formatter::doctools::generate_ooclasses {classinfodict args} {
    # Given a list of class information elements returns as string
    # containing class documentation formatted for doctools
    # classinfodict - dictionary keyed by class name and each element
    #   of which is in the format returned by extract_ooclass
    #
    # Additional parameters are passed on to the generate_ooclass procedure.

    set doc ""
    foreach name [lsort [dict keys $classinfodict]] {
        append doc \
            [eval [list generate_ooclass [dict get $classinfodict $name]] $args]
        append doc "\n\n"
    }
    return $doc
}
    
proc ::ruff::formatter::doctools::generate_procs {procinfodict args} {
    # Given a dictionary of proc information elements returns a string
    # containing documentation formatted for doctools
    # procinfodict - dictionary keyed by name of the proc with the associated
    #   value being in the format returned by extract_proc
    #
    # Additional parameters are passed on to the generate_proc procedure.

    #ruff
    # The returned procedure descriptions are sorted in alphabetical order.
    set doc "\[list_begin definitions\]\n"
    foreach name [lsort -dictionary [dict keys $procinfodict]] {
        append doc \
            [eval [list generate_proc_or_method [dict get $procinfodict $name]] $args]\n\n
    }
    append doc "\[list_end\]\n"

    return $doc
}
    

proc ::ruff::formatter::doctools::generate_document {classprocinfodict args} {
    # Produces documentation in doctools format from the passed in
    # class and proc metainformation.
    #   classprocinfodict - dictionary containing meta information about the 
    #     classes and procs
    # 
    # In addition to options described in the ruff::document command, 
    # the following additional ones may be specified:
    #   -preamble DICT - a dictionary indexed by a namespace. Each value is
    #    a flat list of pairs consisting of a heading and
    #    corresponding content. These are inserted into the document
    #    before the actual class and command descriptions for a namespace.
    #    The key "::" corresponds to documentation to be printed at
    #    the very beginning.
    #   -includesource BOOLEAN - if true, the source code of the
    #     procedure is also included. Default value is false.
    #   -hidenamespace NAMESPACE - if specified as non-empty,
    #    program element names beginning with NAMESPACE are shown
    #    with that namespace component removed.

    array set opts \
        [list \
             -includeclasses true \
             -includeprocs true \
             -includeprivate false \
             -includesource false \
             -hidenamespace "" \
             -section "n" \
             -version "0.0" \
             -name "" \
             -titledesc "" \
             -modulename "" \
             -require {} \
             -author "" \
             -keywords {} \
             -year [clock format [clock seconds] -format %Y] \
             -preamble [dict create] \
             ]
                        
    array set opts $args

    # TBD - does anything need to be escape'ed here?
    set doc "\[manpage_begin \"$opts(-name)\" \"$opts(-section)\" \"$opts(-version)\"\]\n"
    if {$opts(-author) ne ""} {
        append doc "\[copyright {$opts(-year) \"$opts(-author)\"}\]\n"
    }
    if {$opts(-titledesc) ne ""} {
        append doc "\[titledesc \"$opts(-titledesc)\"\]\n"
    }
    if {$opts(-modulename) ne ""} {
        append doc "\[moddesc \"$opts(-modulename)\"\]\n"
    }
    if {[llength $opts(-require)]} {
        foreach require $opts(-require) {
            append doc "\[require $require\]\n"
        }
    }
    
    # Begin the description section
    append doc "\[description\]\n"

    if {[dict exists $opts(-preamble) "::"]} {
        # Print the toplevel (global stuff)
        foreach {sec paras} [dict get $opts(-preamble) "::"] {
            append doc [subsection $sec]
            append doc [_fmtparas $paras]
        }
    }

    set info_by_ns [_sift_classprocinfo $classprocinfodict]

    foreach ns [lsort -dictionary [dict keys $info_by_ns]] {
        append doc [section "Module $ns"]
        if {[dict exists $opts(-preamble) $ns]} {
            foreach {sec paras} [dict get $opts(-preamble) $ns] {
                append doc [section $sec]
                append doc [_fmtparas $paras]
            }
        }

        if {[dict exists $info_by_ns $ns classes]} {
            append doc [section Classes]\n
            append doc [generate_ooclasses [dict get $info_by_ns $ns classes] \
                            -includesource $opts(-includesource) \
                            -hidenamespace $opts(-hidenamespace) \
                           ]
        }
        if {[dict exists $info_by_ns $ns procs]} {
            append doc [section Commands]\n
            append doc [generate_procs [dict get $info_by_ns $ns procs] \
                            -includesource $opts(-includesource) \
                            -hidenamespace $opts(-hidenamespace) \
                           ]
        }
    }

    if {[llength $opts(-keywords)] == 0} {
        # dtplite will barf if no keywords in man page. Logged on sf.net
        # as a bug against doctools
        ::ruff::app::log_error "Warning: no keywords specified in this module. If no modules have keywords some versions of the doctools indexer may generate an error in some modes."
    }

    if {[llength $opts(-keywords)]} {
        append doc [eval keywords $opts(-keywords)]
    }


    append doc "\[manpage_end\]\n"

    return $doc
}


proc ruff::formatter::doctools::_fmtcmd {cmd args} {
    # Returns a string that is a doctools command escaped appropriately
    set arglist {}
    foreach arg $args {
        if {[string index $arg 0] eq "\["} {
            # Do not quote if nested command
            lappend arglist $arg
        } elseif {[regexp {^[[:alnum:]_-]$} $arg]} {
            # Simple word, do not quote unnecessarily
            lappend arglist $arg
        } else {
            # Quote in case there are special characters
            # TBD - do we need to escape as well ? Despite what the
            # doctools syntax page says, the actual syntax rules do
            # not seem exactly those of Tcl
            lappend arglist "\"$arg\""
        }
    }
    return "\[$cmd [join $arglist { }]\]"
}

proc ruff::formatter::doctools::_fmtcmdnl {args} {
    return [eval _fmtcmd $args]\n
}

interp alias {} ::ruff::formatter::doctools::cmd {} ::ruff::formatter::doctools::_fmtcmd          cmd
interp alias {} ::ruff::formatter::doctools::section {} ::ruff::formatter::doctools::_fmtcmdnl    section
interp alias {} ::ruff::formatter::doctools::subsection {} ::ruff::formatter::doctools::_fmtcmdnl subsection
interp alias {} ::ruff::formatter::doctools::list_begin {} ::ruff::formatter::doctools::_fmtcmdnl list_begin
interp alias {} ::ruff::formatter::doctools::list_end {} ::ruff::formatter::doctools::_fmtcmdnl   list_end
interp alias {} ::ruff::formatter::doctools::call {} ::ruff::formatter::doctools::_fmtcmdnl  call
interp alias {} ::ruff::formatter::doctools::para {} ::ruff::formatter::doctools::_fmtcmdnl  para
interp alias {} ::ruff::formatter::doctools::def {} ::ruff::formatter::doctools::_fmtcmdnl   def
interp alias {} ::ruff::formatter::doctools::arg {} ::ruff::formatter::doctools::_fmtcmd   arg
interp alias {} ::ruff::formatter::doctools::arg_def {} ::ruff::formatter::doctools::_fmtcmdnl   arg_def
interp alias {} ::ruff::formatter::doctools::opt_def {} ::ruff::formatter::doctools::_fmtcmdnl   opt_def
interp alias {} ::ruff::formatter::doctools::const {} ::ruff::formatter::doctools::_fmtcmd const
interp alias {} ::ruff::formatter::doctools::opt {} ::ruff::formatter::doctools::_fmtcmd opt
interp alias {} ::ruff::formatter::doctools::option {} ::ruff::formatter::doctools::_fmtcmd option
interp alias {} ::ruff::formatter::doctools::keywords {} ::ruff::formatter::doctools::_fmtcmd keywords

