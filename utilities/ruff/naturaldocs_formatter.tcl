# Copyright (c) 2009, Ashok P. Nadkarni
# All rights reserved.
# See the file WOOF_LICENSE in the Woof! root directory for license


# Ruff! formatter for NaturalDocs

namespace eval ruff::formatter::naturaldocs {
    namespace import [namespace parent]::*
    namespace import [namespace parent [namespace parent]]::*

    # Leaders for various content
    # TBD - get rid of leaders
    variable leaders
    array set leaders {
        heading    "# "
        text    "#   "
    }

}

proc ::ruff::formatter::naturaldocs::_linkify {text link_regexp} {
    # Convert matching substrings to links
    # text - string to be substituted
    #
    # Returns $text with any substrings matching $link_regexp being
    # replaced with NaturalDocs link syntax.
    set start_delim {^|[^[:alnum:]_\:]}
    set end_delim {$|[^[:alnum:]_\:]}
    if {$link_regexp ne ""} {
        regsub -all -- "($start_delim)($link_regexp)($end_delim)" $text {\1<\2>\3} text
    }
    return $text
}

proc ruff::formatter::naturaldocs::_fmtdeflist {listitems {linkregexp {}}} {
    variable leaders

    # NaturalDocs formatting of named lists is simple
    # 
    set doc "#\n"
    foreach {name item} $listitems {
        # NaturalDocs does not like empty description in named lists
        if {$item eq ""} {
            set item "No description available."
            ::ruff::app::log_error "Named list item '$name' does not have an associated description. Default text '$item' used as NaturalDocs will not format the list properly with an empty description."
        } else {
            set item [_linkify $item $linkregexp]
        }
        append doc "$leaders(text)$name - $item\n"
    }
    return $doc
}

proc ruff::formatter::naturaldocs::_fmtbulletlist {listitems {linkregexp {}}} {
    variable leaders

    # NaturalDocs formatting of named lists is simple
    # 
    set doc "#\n"
    foreach item $listitems {
        append doc "$leaders(text) - [_linkify $item $linkregexp]\n"
    }
    return $doc
}

proc ruff::formatter::naturaldocs::_fmtheading {head {text ""}} {
    # Return a NaturalDocs formatted string for a heading (CLASS etc.)

    set doc "#\n# [string totitle [string trimright $head :]:]"
    if {$text ne ""} {
        append doc " $text"
    }
    append doc \n
    return $doc
}

proc ruff::formatter::naturaldocs::_fmtpara {text {linkregexp {}}} {
    # Returns a formatted paragraph with apprpriate comment leaders
    variable leaders

    set text [_linkify [string trim $text] $linkregexp]

    # NaturalDocs will do wrapping itself. But two caveats -
    # If it is a single line of text, and ends in a ':', it will
    # treat it as a heading! So in such a case, we have to force
    # two lines. Ditto if there is a hyphen in which case
    # it will treat it as a definition list item. So for these
    # two cases, we wrap all but the first word on a separate line.
    if {([string index $text end] eq ":") ||
        ([string first " - " $text] > 0)} {
        # Find the first word and put it on a separate line
        if {[regexp {^(\w+)\s*(.*)$} $text dontcare firstword rest]} {
            return "#\n$leaders(text)$firstword\n$leaders(text)$rest\n"
        }        
        # Could not do it, leave as is
    }
    return "#\n$leaders(text)$text\n"
}

proc ruff::formatter::naturaldocs::_fmtparas {paras {linkregexp {}}} {
    variable leaders
    set doc ""
    foreach {type content} $paras {
        switch -exact -- $type {
            paragraph {
                append doc [_fmtpara $content $linkregexp]
            }
            deflist {
                append doc [_fmtdeflist $content $linkregexp]
            }
            bulletlist {
                append doc [_fmtbulletlist $content $linkregexp]
            }
            preformatted {
                append doc "$leaders(text)(code)\n"
                append doc [::textutil::adjust::indent $content $leaders(text)]
                append doc "\n$leaders(text)(end)\n"
            }
            default {
                error "Unknown paragraph element type '$type'."
            }
        }
    }
    return $doc
}

proc ruff::formatter::naturaldocs::generate_proc_or_method {procinfo args} {
    # Formats the documentation for a proc in NaturalDocs format
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
    #   -linkregexp REGEXP - if specified, any word matching the
    #    regular expression REGEXP is marked as a link.
    #
    # Returns the proc documentation as a NaturalDocs formatted string.

    variable markers
    variable leaders

    array set opts {-includesource false
        -hidenamespace ""
        -skipsections {}
        -linkregexp ""
    }
    array set opts $args

    array set aproc $procinfo

    set doc "";                 # Document string

    # In NaturalDocs, method names are never qualifed by a class prefix
    # since they
    # automatically get scoped by previous Class or namespace headings.
    set header_title [_trim_namespace $aproc(name) $opts(-hidenamespace)]
    set proc_name [_trim_namespace $aproc(name) $opts(-hidenamespace)]

    if {[lsearch -exact $opts(-skipsections) header] < 0} {
        if {$aproc(proctype) eq "method"} {
            append doc [_fmtheading method $header_title]
        } else {
            append doc [_fmtheading proc $header_title]
        }
    }

    # Loop through all the paragraphs
    append doc [_fmtparas $aproc(description) $opts(-linkregexp)]

    if {[info exists aproc(return)] && $aproc(return) ne ""} {
        append doc [_fmtheading return]
        append doc [_fmtpara $aproc(return) $opts(-linkregexp)]
    }

    # Now spit out the parameter list. Note we do this AFTER
    # the paragraphs so NaturalDocs correctly picks up
    # a summary line (it wants it right after the topic.
    # Construct the synopsis and simultaneously the parameter descriptions
    set desclist {};            # For the parameter descriptions
    set arglist {};             # Used later for synopsis
    foreach param $aproc(parameters) {
        set name [dict get $param name]
        set desc {}
        if {[dict get $param type] eq "parameter"} {
            lappend arglist $name
            if {[dict exists $param default]} {
                # No visual way in NaturalDocs to show as optional so 
                # explicitly state (although the synopsis will show the
                # default)
                lappend desc "(optional, default [dict get $param default])"
            }
        }
        if {[dict exists $param description]} {
            lappend desc "[dict get $param description]"
        }
        
        lappend desclist $name [join $desc " "]
    }

    if {[llength $desclist]} {
        append doc [_fmtheading parameters]
        # Parameters are output as a list.
        append doc [_fmtdeflist $desclist $opts(-linkregexp)]
    }

    # Do we include the source code in the documentation?
    if {$opts(-includesource)} {
        append doc [_fmtheading source]
        append doc "$leaders(text)(start code)"
        append doc [::textutil::adjust::indent $aproc(source) $leaders(text)]\n
        append doc "$leaders(text)(end code)"
    }

    # Synopsis - write a dummy proc WITHOUT any comment headers and
    # NaturalDocs will pick out the appropriate elements
    if {$aproc(proctype) ne "method"} {
        append doc "\nproc $proc_name \{$arglist\} {}\n"
    } else {
        switch -exact -- $aproc(name) {
            constructor {append doc "\nconstructor $arglist {}\n"}
            destructor  {append doc "\ndestructor {} {}\n"}
            default  {append doc "\nmethod $aproc(name) \{$arglist\} {}\n"}
        }
    }

    return "${doc}\n"
}

proc ruff::formatter::naturaldocs::generate_ooclass {classinfo args} {

    # Formats the documentation for a class in NaturalDocs format
    # classinfo - class information in the format returned
    #   by extract_ooclass
    #
    # The following options may be specified:
    #   -includesource BOOLEAN - if true, the source code of the
    #     procedure is also included. Default value is false.
    #   -hidenamespace NAMESPACE - if specified as non-empty,
    #    program element names beginning with NAMESPACE are shown
    #    with that namespace component removed.
    #   -linkregexp REGEXP - if specified, any word matching the
    #    regular expression REGEXP is marked as a link.
    #
    # Returns the class documentation as a NaturalDocs formatted string.

    variable markers
    variable leaders

    array set opts {
        -includesource false
        -hidenamespace ""
        -mergeconstructor false
        -linkregexp ""
    }
    array set opts $args

    array set aclass $classinfo
    set class_name [_trim_namespace $aclass(name) $opts(-hidenamespace)]

    set doc ""
    append doc [_fmtheading class $class_name]

    # Include constructor in main class definition
    if {$opts(-mergeconstructor) && [info exists aclass(constructor)]} {
        error "-mergeconstructor not implemented"
        append doc [generate_proc_or_method $aclass(constructor) \
                        -includesource $opts(-includesource) \
                        -hidenamespace $opts(-hidenamespace) \
                        -skipsections [list header name] \
                        -linkregexp $opts(-linkregexp) \
                       ]
    }

    # TBD - in the various sections below we include some leading text
    # that is not really necessary. This is because NaturalDocs assumes
    # anything starting with a ":" is a code line and does not format
    # or link any words in it. This is a problem since class names etc.
    # may start with a ":" if namespace qualified

    if {[llength $aclass(superclasses)]} {
        append doc [_fmtheading Superclasses]
        # Don't sort - order matters! 
        append doc [_fmtpara "The class inherits from the following classes: [join [_trim_namespace_multi $aclass(superclasses) $opts(-hidenamespace)] {, }]" $opts(-linkregexp)]
    }
    if {[llength $aclass(mixins)]} {
        append doc [_fmtheading "Mixins"]

        # Don't sort - order matters!
        append doc [_fmtpara "The class has the following classes mixed-in: [join [_trim_namespace_multi $aclass(mixins) $opts(-hidenamespace)] {, }]" $opts(-linkregexp)]
    }

    if {[llength $aclass(subclasses)]} {
        # Don't sort - order matters!
        append doc [_fmtheading "Subclasses"]
        append doc [_fmtpara "The following classes inherit from this class: [join [_trim_namespace_multi $aclass(subclasses) $opts(-hidenamespace)] {, }]" $opts(-linkregexp)]
    }

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
        append doc [_fmtheading "External methods"]
        append doc [_fmtpara "The following methods are either mixed-in or inherited: [join [lsort $external_methods] {, }]" $opts(-linkregexp)]
    }
    if {[llength $aclass(filters)]} {
        append doc [_fmtheading "Filters"]
        append doc [_fmtpara "The following methods are attached as filters for this class : [join [lsort $aclass(filters)] {, }]" $opts(-linkregexp)]
    }

    # In NaturalDocs, the Class heading establishes the "scope"
    # and we can straightaway list the methods directly after it and
    # have them tagged as belonging to the class.

    if {[info exists aclass(constructor)] && !$opts(-mergeconstructor)} {
        append doc [generate_proc_or_method $aclass(constructor) \
                        -includesource $opts(-includesource) \
                        -hidenamespace $opts(-hidenamespace) \
                        -linkregexp $opts(-linkregexp) \
                       ]
    }
    if {[info exists aclass(destructor)]} {
        append doc [generate_proc_or_method $aclass(destructor) \
                        -includesource $opts(-includesource) \
                        -hidenamespace $opts(-hidenamespace) \
                        -linkregexp $opts(-linkregexp) \
                        ]
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
                            -linkregexp $opts(-linkregexp) \
                           ]
        } else {
            # TBD - check formatting of forwarded methods
            append doc [_fmtheading "Method" $name]
            # TBD - link to forwarded method if possible
            append doc [_fmtpara "Method forwarded to [dict get $info forward]" $opts(-linkregexp)]
        }
    }

    return $doc
}

proc ::ruff::formatter::naturaldocs::generate_ooclasses {classinfodict args} {
    # Given a list of class information elements returns as string
    # containing class documentation formatted for NaturalDocs
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
    
proc ::ruff::formatter::naturaldocs::generate_procs {procinfodict args} {
    # Given a dictionary of proc information elements returns a string
    # containing documentation formatted for NaturalDocs
    # procinfodict - dictionary keyed by name of the proc with the associated
    #   value being in the format returned by extract_proc
    #
    # Additional parameters are passed on to the generate_proc procedure.
    #
    # Returns documentation string in NaturalDocs format with 
    # procedure descriptions sorted in alphabetical order.

    set doc ""
    foreach name [lsort -dictionary [dict keys $procinfodict]] {
        append doc \
            [eval [list generate_proc_or_method [dict get $procinfodict $name]] $args]\n\n
    }

    return $doc
}
    

proc ::ruff::formatter::naturaldocs::generate_document {classprocinfodict args} {
    # Produces documentation in NaturalDocs format from the passed in
    # class and proc metainformation.
    #   classprocinfodict - dictionary containing meta information about the 
    #    classes and procs
    # 
    # The following options may be specified:
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
    #   -modulename NAME - the name of the module. Used as the title for the document.
    #    If undefined, the string "Reference" is used.

    array set opts \
        [list \
             -includesource false \
             -hidenamespace "" \
             -modulename "Reference" \
             -preamble [dict create] \
             ]
                        
    array set opts $args
    set doc [_fmtheading Title $opts(-modulename)]

    # Build a regexp that can be used to convert references to classes, methods
    # and procedures to links. 
    set methods {}
    foreach {class_name class_info} [dict get $classprocinfodict classes] {
        foreach method_info [dict get $class_info methods] {
            lappend methods ${class_name}.[dict get $method_info name]
        }
        foreach method_info [dict get $class_info forwards] {
            lappend methods ${class_name}.[dict get $method_info name]
        }
    }
    set ref_regexp [_build_symbol_regexp \
                        [concat \
                             [dict keys [dict get $classprocinfodict procs]] \
                             [dict keys [dict get $classprocinfodict classes]] \
                             $methods
                            ]
                   ]

    if {[dict exists $opts(-preamble) "::"]} {
        # Print the toplevel (global stuff)
        foreach {sec paras} [dict get $opts(-preamble) "::"] {
            append doc [_fmtheading $sec]
            append doc [_fmtparas $paras $ref_regexp]
        }
    }

    set info_by_ns [_sift_classprocinfo $classprocinfodict]

    foreach ns [lsort -dictionary [dict keys $info_by_ns]] {
        # append doc [_fmtheading Section $ns] <- this causes dup headings?
        if {[dict exists $opts(-preamble) $ns]} {
            foreach {sec paras} [dict get $opts(-preamble) $ns] {
                append doc [_fmtheading $sec]
                append doc [_fmtparas $paras $ref_regexp]
            }
        }

        # Output commands BEFORE classes else they show up as
        # part of a class definition unless they are grouped into a
        # separate section in which case summaries are duplicated.
        if {[dict exists $info_by_ns $ns procs]} {
            append doc [_fmtheading Section Commands]
            append doc [generate_procs [dict get $info_by_ns $ns procs] \
                            -includesource $opts(-includesource) \
                            -hidenamespace $opts(-hidenamespace) \
                            -linkregexp $ref_regexp \
                           ]
        }

        if {[dict exists $info_by_ns $ns classes]} {
            append doc [generate_ooclasses [dict get $info_by_ns $ns classes] \
                            -includesource $opts(-includesource) \
                            -hidenamespace $opts(-hidenamespace) \
                            -linkregexp $ref_regexp \
                           ]
        }
    }

    return $doc
}
