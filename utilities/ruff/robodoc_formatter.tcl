# Copyright (c) 2009, Ashok P. Nadkarni
# All rights reserved.
# See the file WOOF_LICENSE in the Woof! root directory for license


# Ruff! formatter for robodoc

namespace eval ruff::formatter::robodoc {
    namespace import [namespace parent]::*
    namespace import [namespace parent [namespace parent]]::*

    # Markers used by robodoc
    variable markers
    array set markers {
        function "#****f*"
        class    "#****c*"
        method   "#****m*"
        module   "#****h*"
        end      "#******"
    }
    # Leaders for various content
    variable leaders
    array set leaders {
        item    "# "
        text    "#   "
    }

}

proc ruff::formatter::robodoc::_fmtlist {listitems} {
    variable leaders
    set text ""
    foreach desc $listitems {
        # TBD - robodoc is very poor in terms of list
        # recognition. This will only be formatted as a list if
        # the previous line was an heading or ended in ":". This
        # is really limiting; for now we ignore this problem.

        # Start of the first line identifies it as a list item
        # to robodoc.
        append text [_wrap_text $desc -prefix "$leaders(text)  " -prefix1 "$leaders(text)* "]\n
    }
    return $text
}

proc ruff::formatter::robodoc::_fmtitem {item args} {
    # Return a robodoc formatted string for a item (CLASS etc.)
    # Optionally, one or more text lines may be specified
    # as the content
    variable leaders
    set doc "#\n$leaders(item)[string toupper $item]\n"
    foreach arg $args {
        append doc [_fmtpara $arg]
    }
    return $doc
}

proc ruff::formatter::robodoc::_fmtpara {text} {
    # Returns a formatted paragraph with apprpriate comment leaders
    variable leaders
    return "#\n[_wrap_text $text -prefix $leaders(text)]\n"

}

proc ruff::formatter::robodoc::_fmtparas {paras {last_char :}} {
    variable leaders

    set doc ""
    foreach {type content} $paras {
        if {$type eq "preformatted"} {
            append doc [::textutil::adjust::indent $content $leaders(text)]\n
            set last_char ""
        } elseif {$type eq "paragraph"} {
            append doc [_fmtpara $content]
            set last_char [string index $content end]
        } else {
            # deflist or bulletlist
            # TBD - robodoc is very poor in terms of list
            # recognition. This will only be formatted as a list if
            # the previous line was an heading or ended in ":". This
            # is really limiting; for now we ignore this problem except
            # for the warning.
            if {$last_char ne ":"} {
                ::ruff::app::log_error "The text '$content' seems to be a named list that will not be recognized by Robodoc as a list. It must either be the first line following an item header or the previous line must end in a semi-colon."
            }
            set desclist {}
            if {$type eq "deflist"} {
                foreach {name desc} $content {
                    lappend desclist "$name -- $desc"
                }
            } else {
                foreach desc $content {
                    lappend desclist $desc
                }
            }
            append doc [_fmtlist $desclist]
        }
    }
    return $doc
}

proc ruff::formatter::robodoc::generate_proc_or_method {procinfo args} {
    # Formats the documentation for a proc in robodoc format
    # procinfo - proc or method information in the format returned
    #   by extract_ooclass
    #
    # The following options may be specified:
    #   -includesource BOOLEAN - if true, the source code of the
    #     procedure is also included. Default value is false.
    #   -hidenamespace NAMESPACE - if specified as non-empty,
    #    program element names beginning with NAMESPACE are shown
    #    with that namespace component removed.
    #   -skipsections SECTIONLIST - a list of sections to be left
    #    out from the generated document. This is generally useful
    #    if the return value is to be included as part of a larger
    #    section (e.g. constructor within a class)
    # Returns the proc documentation as a robodoc formatted string.

    variable markers
    variable leaders

    array set opts {-includesource false -hidenamespace "" -skipsections {}}
    array set opts $args

    array set aproc $procinfo

    set doc "";                 # Document string

    #ruff
    # In order for the Robodoc cross-links to work, the header markers
    # generated use the namespace as the section followed by the command
    # name or class name and method combined with a period.
    if {$aproc(proctype) eq "method"} {
        set header_title "[namespace qualifiers $aproc(class)]/[namespace tail $aproc(class)].$aproc(name)"
        set proc_name [_trim_namespace $aproc(class) $opts(-hidenamespace)].$aproc(name)
    } else {
        set header_title [namespace qualifiers $aproc(name)]/[namespace tail $aproc(name)]
        set proc_name [_trim_namespace $aproc(name) $opts(-hidenamespace)]
    }

    # TBD - mark header as internal depending on whether private method
    if {[lsearch -exact -nocase $opts(-skipsections) header] < 0} {
        if {$aproc(proctype) eq "method"} {
            append doc "$markers(method) $header_title\n"
        } else {
            append doc "$markers(function) $header_title\n"
        }
    }

    if {[lsearch -exact -nocase $opts(-skipsections) name] < 0} {
        append doc [_fmtitem NAME $proc_name]
    }
    

    # Construct the synopsis and simultaneously the parameter descriptions
    set desclist {};            # For the parameter descriptions
    set arglist {};             # For the synopsis
    # Construct command synopsis and parameter block
    # Unfortunately Robodoc does not seem to have any special way of
    # formatting these. Just output as text strings
    foreach param $aproc(parameters) {
        set name [dict get $param name]
        if {[dict get $param type] eq "parameter"} {
            lappend arglist $name
        }
        set desc "$name --"
        if {[dict exists $param default]} {
            # No visual way in robodoc to show as optional so explicitly state
            append desc " (optional, default [dict get $param default])"
        }
        if {[dict exists $param description]} {
            append desc " [dict get $param description]"
        }
        
        lappend desclist $desc
    }

    # Synopsis
    if {$aproc(proctype) ne "method"} {
        append doc [_fmtitem SYNOPSIS "$proc_name $arglist"]
    } else {
        switch -exact -- $aproc(name) {
            constructor {append doc [_fmtitem SYNOPSIS "::oo::class create [_trim_namespace $aproc(class) $opts(-hidenamespace)] $arglist"]}
            destructor  {append doc [_fmtitem SYNOPSIS "OBJECT destroy"]}
            default  {append doc [_fmtitem SYNOPSIS "OBJECT $aproc(name) $arglist"]}
        }
    }

    # Parameter descriptions
    if {[llength $desclist]} {
        append doc [_fmtitem PARAMETERS]
        # Parameters are output as a list.
        append doc [_fmtlist $desclist]
    }
        
    append doc [_fmtitem DESCRIPTION]


    # Loop through all the paragraphs
    # We need to remember the last character to detect possible errors
    # in Robodoc's list recognition. Either the list must follow a item
    # header or a line ending in colon (:). We pass : as the second
    # parameter below because we just put out a item header which
    # is equivalent.
    append doc [_fmtparas $aproc(description) :]

    if {[info exists aproc(return)] && $aproc(return) ne ""} {
        append doc [_fmtpara $aproc(return)]
    }

    if {$opts(-includesource)} {
        append doc [_fmtitem SOURCE]
        append doc [::textutil::adjust::indent $aproc(source) $leaders(text)]\n
    }

    if {[lsearch -exact -nocase $opts(-skipsections) header] < 0} {
        append doc $markers(end)
    }

    return "${doc}\n"
}

proc ruff::formatter::robodoc::generate_ooclass {classinfo args} {

    # Formats the documentation for a class in robodoc format
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
    # Returns the class documentation as a robodoc formatted string.

    variable markers
    variable leaders

    array set opts {-includesource false -hidenamespace "" -mergeconstructor true}
    array set opts $args

    array set aclass $classinfo
    set class_name [_trim_namespace $aclass(name) $opts(-hidenamespace)]

    set doc ""
    set header_title "[namespace qualifiers $aclass(name)]/[namespace tail $aclass(name)]"
    append doc "$markers(class) $header_title\n"

    append doc [_fmtitem NAME $class_name]

    # Include constructor in main class definition
    if {$opts(-mergeconstructor) && [info exists aclass(constructor)]} {
        append doc [generate_proc_or_method $aclass(constructor) \
                        -includesource $opts(-includesource) \
                        -hidenamespace $opts(-hidenamespace) \
                        -skipsections [list header name] \
                       ]
    }

    #ruff
    # Because robodoc does not have a heading for mix-ins, they are include
    # within the DERIVED FROM section.
    if {[llength $aclass(superclasses)] || [llength $aclass(mixins)]} {
        append doc [_fmtitem "DERIVED FROM"]

        # Don't sort - order matters! Also, there is no heading for mixins
        # so we add them here.
        if {[llength $aclass(mixins)]} {
            # Don't sort - order matters!
            append doc [_fmtpara "Mixins: [join [_trim_namespace_multi $aclass(mixins) $opts(-hidenamespace)] {, }]"]
        }
        if {[llength $aclass(superclasses)]} {
            append doc [_fmtpara "Superclasses: [join [_trim_namespace_multi $aclass(superclasses) $opts(-hidenamespace)] {, }]"]
        }
    }


    if {[llength $aclass(subclasses)]} {
        # Don't sort - order matters!
        append doc [_fmtitem "DERIVED BY" [join [_trim_namespace_multi $aclass(subclasses) $opts(-hidenamespace)] ", "]]
    }

    #ruff
    # Documentation for a class only lists the method names. The
    # methods themselves are documented separately.
    set class_methods {}
    foreach methodinfo $aclass(methods) {
        lappend class_methods ${class_name}.[dict get $methodinfo name]
    }
    if {[info exists aclass(constructor)] && !$opts(-mergeconstructor)} {
        set class_methods [linsert $class_methods 0 constructor]
    }
    if {[info exists aclass(destructor)]} {
        set class_methods [linsert $class_methods 0 destructor]
    }
    append doc [_fmtitem METHODS]
    append doc [_fmtpara [join $class_methods ", "]]

    #ruff
    # Inherited and derived methods are listed as such.
    if {[llength $aclass(external_methods)]} {
        set external_methods {}
        foreach external_method $aclass(external_methods) {
            # Qualify the name with the name of the implenting class
            foreach {name imp_class} $external_method break
            if {$imp_class ne ""} {
                set name [_trim_namespace_multi $imp_class $opts(-hidenamespace)].$name
            }
            lappend external_methods $name
        }
        append doc [_fmtpara "External methods: [join [lsort $external_methods] {, }]"]
    }
    if {[llength $aclass(filters)]} {
        append doc [_fmtpara "Filters: [join [lsort $aclass(filters)] {, }]"]
    }
    
    # Finish up the class description
    append doc $markers(end)

    # Next we will generate the documentation for the methods themselves

    append doc "\n\n"

    if {[info exists aclass(constructor)] && !$opts(-mergeconstructor)} {
        append doc [generate_proc_or_method $aclass(constructor) \
                        -includesource $opts(-includesource) \
                        -hidenamespace $opts(-hidenamespace)]
    }
    if {[info exists aclass(destructor)]} {
        append doc [generate_proc_or_method $aclass(destructor) \
                        -includesource $opts(-includesource) \
                        -hidenamespace $opts(-hidenamespace)]
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
                            -hidenamespace $opts(-hidenamespace)]
        } else {
            # Forwarded method
            set header_title "[namespace qualifiers $aclass(name)]/[namespace tail $aclass(name)].$name"
            append doc "\n$markers(method) $header_title\n"
            append doc [_fmtitem NAME "[_trim_namespace $aclass(name) $opts(-hidenamespace)].$name"]
            # TBD - link to forwarded method if possible
            append doc [_fmtpara "Method forwarded to [dict get $info forward]."]
            append doc "\n$markers(end)\n"
        }
    }

    return $doc
}

proc ::ruff::formatter::robodoc::generate_ooclasses {classinfodict args} {
    # Given a list of class information elements returns as string
    # containing class documentation formatted for robodoc
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
    
proc ::ruff::formatter::robodoc::generate_procs {procinfodict args} {
    # Given a dictionary of proc information elements returns a string
    # containing documentation formatted for robodoc
    # procinfodict - dictionary keyed by name of the proc with the associated
    #   value being in the format returned by extract_proc
    #
    # Additional parameters are passed on to the generate_proc procedure.

    set doc ""

    foreach name [lsort -dictionary [dict keys $procinfodict]] {
        append doc \
            [eval [list generate_proc_or_method [dict get $procinfodict $name]] $args]\n\n
    }

    return $doc
}
    

proc ::ruff::formatter::robodoc::generate_document {classprocinfodict args} {
    # Produces documentation in robodoc format from the passed in
    # class and proc metainformation.
    #  classprocinfodict - dictionary containing meta information about the 
    #    classes and procs
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

    variable markers

    array set opts \
        [list \
             -includesource false \
             -hidenamespace "" \
             -modulename MODULE \
             -preamble [dict create] \
             ]
                        
    array set opts $args
    set doc ""

    if {[dict exists $opts(-preamble) "::"]} {
        # Print the toplevel (global stuff)
        foreach {sec paras} [dict get $opts(-preamble) "::"] {
            append doc "$markers(module) $opts(-modulename)/$sec\n"
            append doc [_fmtitem DESCRIPTION]
            append doc [_fmtparas $paras]
            append doc "$markers(end)\n"
        }
    }

    set info_by_ns [_sift_classprocinfo $classprocinfodict]
    foreach ns [lsort -dictionary [dict keys $info_by_ns]] {
        # TBD - does the following line cause dup headings?
        # append doc [_fmtheading Section $ns]
        if {[dict exists $opts(-preamble) $ns]} {
            foreach {sec paras} [dict get $opts(-preamble) $ns] {
                append doc "$markers(module) $ns/$sec\n"
                append doc [_fmtitem DESCRIPTION]
                append doc [_fmtparas $paras]
                append doc "$markers(end)\n"
            }
        }

        if {[dict exists $info_by_ns $ns classes]} {
            append doc [generate_ooclasses [dict get $info_by_ns $ns classes] \
                            -includesource $opts(-includesource) \
                            -hidenamespace $opts(-hidenamespace) \
                           ]
        }
        if {[dict exists $info_by_ns $ns procs]} {
            append doc [generate_procs [dict get $info_by_ns $ns procs] \
                    -includesource $opts(-includesource) \
                    -hidenamespace $opts(-hidenamespace) \
                   ]
        }
    }

    return $doc
}
