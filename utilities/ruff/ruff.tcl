# Copyright (c) 2009, Ashok P. Nadkarni
# All rights reserved.
# See the file WOOF_LICENSE in the Woof! root directory for license

# Ruff! - RUntime Formatting Function
# ...a document generator using introspection
#
# See http://woof.magicsplat.com/ruff_guide for the user guide
# and http://woof.magicsplat.com/manuals/ruff/index.html
# for the man pages. The package generates its own documentation
# (see document_self).

package require textutil::adjust


# TBD
# - Wiki formatting (uppercase as [arg ...] etc.

# Stuff to emulate 8.6 core on older versions.
if {[info commands dict] == ""} {
    package require dict
}

namespace eval ruff {
    variable version 0.4

    variable names
    set names(display) "Ruff!"
    set names(longdisplay) "Runtime Function Formatter"

    variable ruff_dir
    set ruff_dir [file dirname [info script]]

    variable _ruffdoc
    set _ruffdoc {}
    lappend _ruffdoc Introduction {
        Ruff! generates reference documentation for Tcl programs using
        runtime introspection.

        Unlike most source code based documentation generators, Ruff!
        generates documentation using Tcl's runtime system to extract
        proc, class and method definitions. The code for procedures
        and methods is parsed to extract documentation from free-form
        comments. Tcl introspection is used to retrieve information
        about namespaces, inheritance graphs, default parameter values and
        so on.

        This document contains reference material for Ruff!. For
        more introductory and tutorial documentation, a user
        guide is available at http://woof.magicsplat.com/ruff_guide.
        The SourceForge site http://sourceforge.net/projects/woof hosts the
        Ruff! source tree as part of the Woof! project.
    }
    lappend _ruffdoc Usage {
        Ruff! is not intended to be a standalone script. Rather the package
        provides commands that should be driven from a script that controls
        which particular namespaces, classes etc. are to be included.
        Include the following command to load the package into your script.

            package require ruff
        
        Once loaded, you can use the ::ruff::document_namespaces command to
        document classes and commands within a namespace. For more
        flexibility in controlling what is to be documented, use
        the ::ruff::extract command and pass its results to the 
        ::ruff::document command.
        
        In the simple case, where only the namespace '::NS' and its
        children are to be documented, the following commands will
        create the file 'NS.html' using the built-in HTML formatter.

          package require ruff
          ::ruff::document_namespaces html [list ::NS] -output NS.html -recurse true

        Other commands in the package are intended to be used if
        you want to roll your own custom formatting package.

        Refer to the source code of the command ::ruff::document_self, which
        generates documentation for Ruff!, for an example of how
        the package might be used.
    }
    lappend _ruffdoc "Input format" {
        Ruff! extracts documentation from proc and class definitions and
        comments within the proc and method bodies. The comments are
        expected to have some simple structure but no extraneous markup
        is required.

        The lines within the body of a proc or method are first filtered
        as described in documentation for the ::ruff::distill_body command.
        These lines are then parsed as described in the ::ruff::parse command
        to extract different documentation components. 

        Refer to those commands for the syntax and comment structure expected
        by Ruff!.
    }
    lappend _ruffdoc "Output formats" {
        Ruff! supports multiple output formats. HTML can be directly
        generated using the internal formatter which does not require
        any other external tool. 

        Alternatively, the output can
        also be generated in a format that is suitable to be fed to
        an external formatting program such as robodoc or doctools.
        The command ::ruff::formatters returns a list of supported
        formatters. These formatters in turn can produce documents in
        several different formats such as html, latex and docbook.

        It is recommended that for HTML output, the built-in
        html formatter be used as it has the best support
        for cross-referencing, automatic link generation and navigation.
    }

    namespace export _build_symbol_regexp _sift_names _sift_classprocinfo \
        _trim_namespace _trim_namespace_multi _wrap_text _identity
}

proc ruff::_identity {s} {
    # Returns the passed string unaltered.
    # Used as a stub to "no-op" some transformations
    return $s
}

proc ruff::_regexp_escape {s} {
    return [string map {\\ \\\\ $ \\$ ^ \\^ . \\. ? \\? + \\+ * \\* | \\| ( \\( ) \\) [ \\[ ] \\] \{ \\\{ \} \\\} } $s]
}

proc ruff::_build_symbol_regexp {symlist} {
    # Builds a regular expression that matches any of the specified
    # symbols or names
    # symlist - list of symbols or names
    #
    # Returns a regular expression that 
    # will match any of the name or the namespace tail component of
    # any of the names in symlist.

    # First collect all names and tail components and then join
    # them as alternatives. Note do NOT enclose them using regexp ()
    # groups since the formatting code then loses track of the
    # position of its own () groups.
    set alternatives {}
    foreach sym $symlist {
        lappend alternatives "[_regexp_escape $sym]"
        # Add the tail component
        set tail [namespace tail $sym]
        if {$tail ne "$sym"} {
            lappend alternatives "[_regexp_escape $tail]"
        }
    }

    return [join $alternatives "|"]
}

proc ruff::_namespace_tree {nslist} {
    # Return list of namespaces under the specified namespaces
    array set done {}
    while {[llength $nslist]} {
        set ns [lindex $nslist 0]
        set nslist [lrange $nslist 1 end]
        if {[info exists done($ns)]} {
            # Already recursed this namespace
            continue
        }
        set done($ns) true
        eval [list lappend nslist] [namespace children $ns]
    }

    return [array names done]
}

proc ruff::_trim_namespace {name ns} {
    # Removes a namespace (::) or class qualifier (.) from the specified name.
    # name - name from which the namespace is to be removed
    # ns - the namespace to be removed. If empty, $name
    #  is returned as is. To trim the root namespace
    #  pass :: as the value
    #
    # Returns the remaining string after removing $ns
    # from $name. If $name does not begin with $ns, returns
    # it as is.

    if {$ns eq ""} {
        # Note this check must come BEFORE the trim below
        return $name
    }

    # The "namespace" may be either a Tcl namespace or a class
    # in which case the separator is a "." and not ::
    set ns [string trimright $ns :.]
    set nslen [string length $ns]
    if {[string equal ${ns} [string range $name 0 [expr {$nslen-1}]]]} {
        # Prefix matches.
        set tail [string range $name $nslen end]
        # See if next chars are :: or .
        if {[string range $tail 0 1] eq "::"} {
            # Namespace
            return [string range $tail 2 end]
        }
        if {[string index $tail 0] eq "."} {
            # Class
            return [string range $tail 1 end]
        }
    }

    return $name
}

proc ruff::_trim_namespace_multi {namelist ns} {
    # See _trim_namespace for a description. Only difference
    # is that this command takes a list of names instead
    # of a single name.
    set result {}
    foreach name $namelist {
        lappend result [_trim_namespace $name $ns]
    }
    return $result
}

proc ruff::_sift_names {names} {
    # Given a list of names, separates and sorts them based on their namespace
    # names - a list of names
    #
    # Returns a dictionary indexed by namespace names with corresponding
    # values being a sorted list of names belong to that namespace.

    set namespaces [dict create]
    foreach name [lsort -dictionary $names] {
        set ns [namespace qualifiers $name]
        dict lappend namespaces $ns $name
    }

    return $namespaces
}

proc ruff::_sift_classprocinfo {classprocinfodict} {
    # Sifts through class and proc meta information based
    # on namespace
    #
    # Returns a dictionary with keys namespaces and values
    # being dictionaries with keys "classes" and "procs"
    # containing metainformation.
    
    set result [dict create]
    dict for {name procinfo} [dict get $classprocinfodict procs] {
        set ns [namespace qualifiers $name]
        if {$ns eq ""} {
            set ns "::"
        }
        dict set result $ns procs $name $procinfo
    }

    dict for {name classinfo} [dict get $classprocinfodict classes] {
        set ns [namespace qualifiers $name]
        if {$ns eq ""} {
            set ns "::"
        }
        dict set result $ns classes $name $classinfo
    }

    return $result
}

proc ruff::parse {lines} {
    # Creates a parse structure given a list of lines that are assumed
    # to be documentation for a programming structure
    #
    # lines - a list of lines comprising the documentation
    #
    set result(name) ""
    set result(listcollector) {}
    set result(fragment) {}
    set result(state) init
    set result(output) {}
    foreach line $lines {
        switch -regexp -- $line {
            {^\s*$} {
                #ruff
                # Empty lines or lines with only whitespace
                # terminate the preceding
                # text block (such as a paragraph or a list).
                switch -exact -- $result(state) {
                    init -
                    postsummary {
                        # No change
                    }
                    summary {
                        _change_state postsummary result
                    }
                    default {
                        _change_state blank result
                    }
                }
            }
            {^\s*[-\*]\s+(.*)$} {
                #ruff
                # A bulleted list item starts with a '-' or '*' character.
                # A list item may be continued across multiple lines by
                # indending succeeding lines belonging to the same list item.
                # Note an indented line will terminate the previous list
                # item if it itself looks like a new list item.
                # A bulleted
                # list is returned as a list containing the list items, each
                # of which is a list of lines.
                _change_state bulletlist result
                if {![regexp {^\s*[-\*]\s+(.*)$} $line dontcare fragment]} {
                    error "Internal error: regexp did not match after switch statement matched."
                }
                lappend result(fragment) $fragment
            }
            {^\s*(\w+)\s+-(\s+.*)$} {
                #ruff
                # A definition list or parameter list begins with a word
                # followed by whitespace, a '-' character, whitespace
                # and descriptive 
                # text. Whether it is treated as a parameter list or a
                # definition list depends on whether it occurs in the comment
                # block. If it occurs at the beginning or just after the
                # summary line, it is treated as a parameter list.
                # In all other cases, it is treated as a definition list.
                # Like a bulleted list, each list item may be continued
                # on succeeding lines by indenting them.
                # Definition and parameter lists
                # are returned as flat list 
                # of alternating list item name and list item value
                # pairs. The list item value is itself a list of lines.
                if {[lsearch -exact {init summary postsummary parameter} $result(state)] >= 0} {
                    _change_state parameter result
                } else {
                    _change_state deflist result
                }
                if {![regexp {^\s*(\w+)\s+-(\s+.*)$} $line dontcare result(name) fragment]} {
                    error "Internal error: regexp did not match after switch statement matched."
                }
                lappend result(fragment) $fragment
            }
            {^\s*(-\w+.*)\s+-(\s+.*)$} {
                #ruff
                # An option list is similar to a parameter list except that
                # the first word on the line begins with a '-' character and
                # is possibly followed by more words before the '-' character
                # that separates the descriptive text. The '-' separator
                # must be surrounded by whitespace. The value returned
                # for an option list follows the same structure as for
                # parameter or definition list items. Any line in any 
                # documentation block that matches this is always added
                # to the option list, irrespective of where it occurs. This
                # means option descriptions can be mingled with other
                # documentation fragments and will show up in the options
                # section.

                _change_state option result

                if {![regexp {^\s*(-\w+.*)\s+-(.*)$} $line dontcare result(name) fragment]} {
                    error "Internal error: regexp did not match after switch statement matched."
                }
                lappend result(fragment) $fragment
            }
            {^Returns($|\s.*$)} {
                #ruff
                # Any paragraph that begins with the word 'Returns' is treated
                # as a description of the return value irrespective of where
                # it occurs. It is returned as a list of lines.
                _change_state return result
                lappend result(fragment) $line
            }
            {^\s+} {
                #ruff
                # Lines beginning with spaces
                # are treated as preformatted text unless they are part
                # of a list item. Preformatted text is returned as a list
                # of lines.
                switch -exact -- $result(state) {
                    preformatted -
                    bulletlist -
                    deflist -
                    parameter -
                    option {
                        # No change. Keep adding to existing block
                    }
                    default {
                        _change_state preformatted result
                    }
                }
                lappend result(fragment) $line
            }
            default {
                #ruff
                # All other text blocks are descriptive text paragraphs.
                # Paragraphs may extend across multiple lines and are
                # terminated either when the line matches one of the list
                # items patterns, an indented line (which is treated
                # as preformatted text), or an empty line. Paragraphs
                # are returned as a list of lines.

                switch -exact -- $result(state) {
                    init { _change_state summary result }
                    postsummary -
                    blank -
                    bulletlist -
                    parameter -
                    deflist -
                    option -
                    preformatted { _change_state paragraph result }
                    default {
                        # Stay in same state
                    }
                }
                lappend result(fragment) $line
            }
        }
    }
    _change_state finish result; # To process any leftovers in result(fragment)

    # Returns a list of key value pairs where key is one 
    # of 'parameter', 'option', 'bulletlist', 'deflist', 'parameter',
    # 'preformatted', 'paragraph' or 'return',
    # and the value
    # is the corresponding value.
    return $result(output)

}


# Note new state may be same as old state
# (but a new fragment)
proc ruff::_change_state {new v_name} {
    upvar 1 $v_name result

    # Close off existing state
    switch -exact -- $result(state) {
        bulletlist -
        deflist -
        parameter -
        option {
            if {$result(state) eq "bulletlist"} {
                lappend result(listcollector) $result(fragment)
            } else {
                lappend result(listcollector) $result(name) $result(fragment)
            }
            # If are collecting a list, and new state is same, then
            # this is just another item in the same list and we do not
            # store to output.
            if {$result(state) ne $new} {
                # List type has changed or changing to non-list type
                lappend result(output) $result(state) $result(listcollector)
                set result(listcollector) {}
            }
        }
        return  {
            lappend result(output) return $result(fragment)
        }
        summary {
            lappend result(output) summary $result(fragment)

            # Summary is also included in the paragraphs
            lappend result(output) paragraph $result(fragment)
        }
        paragraph {
            lappend result(output) paragraph $result(fragment)
        }
        preformatted {
            lappend result(output) preformatted $result(fragment)
        }
        postsummary -
        init -
        blank {
            # Nothing to do
        }
        default {
            error "Unknown parse state $result(state)"
        }
    }
    set result(state) $new;     # Restart for next fragment
    set result(name) ""
    set result(fragment) {}
}

proc ruff::distill_docstring {text} {
    # Splits a documentation string to return the documentation lines
    # as a list.
    # text - documentation string to be parsed

    
    set lines {}
    set state init
    foreach line [split $text \n] {
        if {[regexp {^\s*$} $line]} {
            #ruff
            # Initial blank lines are skipped and 
            # multiple empty lines are compressed into one empty line.
            if {$state eq "collecting"} {
                lappend lines ""
                set state empty
            }
            continue
        }
        #ruff
        # The very first non empty line determines the margin. This will
        # be removed from all subsequent lines. Note that this assumes that
        # if tabs are used for indentation, they are used on all lines
        # in consistent fashion.
        if {$state eq "init"} {
            regexp {^(\s*)\S} $line dontcare prefix
            set prefix_len [string length $prefix]
        }
        set state collecting

        # Remove the prefix if it exists from the line
        if {[string match ${prefix}* $line]} {
            set line [string range $line $prefix_len end]
        }

        lappend lines $line
    }

    # Returns a list of lines.
    return $lines
}

proc ruff::distill_body {text} {
    # Given a procedure or method body,
    # returns the documentation lines as a list.
    # text - text to be processed to collect all documentation lines.
    # The first block of contiguous comment lines preceding the 
    # first line of code are treated as documentation lines.

    set lines {}
    set state init;             # init, collecting or searching
    foreach line [split $text \n] {
        set line [string trim $line]; # Get rid of whitespace
        if {$line eq ""} {
            # Blank lines.
            # If in init state, we will stay in init state
            if {$state ne "init"} {
                set state searching
            }
            continue
        }

        if {[string index $line 0] ne "#"} {
            # Not a comment
            set state searching
            continue
        }

        # At this point, the line is a comment line
        if {$state eq "searching"} {
            #ruff
            # The string #ruff at the beginning of a comment line
            # anywhere in the passed in text is considered the start
            # of a documentation block. All subsequent contiguous
            # comment lines are considered documentation lines.
            if {[string match "#ruff*" $line]} {
                set state collecting
                #ruff
                # Note a #ruff on a line by itself will terminate
                # the previous text block.
                set line [string trimright $line]
                if {$line eq "#ruff"} {
                    lappend lines {}
                } else {
                    #ruff If #ruff is followed by additional text
                    # on the same line, it is treated as a continuation
                    # of the previous text block.
                    lappend lines [string range $line 6 end]
                }
            }
        } else {
            # State is init or collecting

            if {$line eq "#"} {
                # Empty comment line
                lappend lines {}
                continue;       # No change in state
            }

            #ruff
            # The leading comment character and a single space (if present)
            # are trimmed from the returned lines.
            if {[string index $line 1] eq " "} {
                lappend lines [string range $line 2 end]
            } else {
                lappend lines [string range $line 1 end]
            }
            set state collecting
            continue
        }
    }

    # Returns a list of lines that comprise the raw documentation.
    return $lines
}

proc ruff::extract_docstring {text} {
    # Parses a documentation string to return a structured text representation.
    # text - documentation string to be parsed
    #
    # The command extracts structured text from the given string
    # as described in the documentation for the distill_docstring
    # and parse commands. The result is further processed to
    # return a list of type and value elements described below:
    # deflist - the corresponding value is another list containing
    #   definition item name and its value as a string.
    # bulletlist - the corresponding value is a list of strings
    #   each being one list item.
    # paragraph - the corresponding value is a string comprising
    #   the paragraph.
    # preformatted - the corresponding value is a string comprising
    #   preformatted text.


    set paragraphs {}

    # Loop and construct the documentation
    foreach {type content} [parse [distill_docstring $text]] {
        switch -exact -- $type {
            deflist {
                # Each named list is a list of pairs
                set deflist {}
                foreach {name desc} $content {
                    lappend deflist $name [join $desc " "]
                }
                lappend paragraphs deflist $deflist
            }
            bulletlist {
                # Bullet lists are lumped with paragraphs
                set bulletlist {}
                foreach desc $content {
                    lappend bulletlist [join $desc " "]
                }
                lappend paragraphs bulletlist $bulletlist
            }
            summary {
                # Do nothing. Summaries are same as the first
                # paragraph. For docstrings, we do not show
                # them separately like we do for procs
            }
            paragraph {
                lappend paragraphs paragraph [join $content " "]
            }
            preformatted {
                lappend paragraphs preformatted [join $content \n]
            }
            default {
                error "Text fragments of type '$type' not supported in docstrings"
            }
        }
    }
    return $paragraphs
}

proc ruff::extract_proc {procname} {

    # Extracts meta information from a Tcl procedure.
    # procname - name of the procedure
    #
    # The command retrieves metainformation about
    # a Tcl procedure. See the command extract_proc_or_method
    # for details.
    #
    # Returns a dictionary containing metainformation for the command.
    #

    set param_names [info args $procname]
    set param_defaults {}
    foreach name $param_names {
        if {[info default $procname $name val]} {
            lappend param_defaults $name $val
        }
    }
    return [extract_proc_or_method proc $procname [info args $procname] $param_defaults [info body $procname]]
}

proc ruff::extract_ooclass_method {class method} {

    # Extracts metainformation for the method in oo:: class
    # class - name of the class
    #
    # The command retrieves metainformation about
    # a Tcl class method. See the command extract_proc_or_method
    # for details.
    #
    # Returns a dictionary containing documentation related to the command.
    #

    
    switch -exact -- $method {
        constructor {
            foreach {params body} [info class constructor $class] break
        }
        destructor  {
            set body [lindex [info class destructor $class] 0]
            set params {}
        }
        default {
            foreach {params body} [info class definition $class $method] break
        }
    }


    set param_names {}
    set param_defaults {}
    foreach param $params {
        lappend param_names [lindex $param 0]
        if {[llength $param] > 1} {
            lappend param_defaults [lindex $param 0] [lindex $param 1]
        }
    }

    return [extract_proc_or_method method $method $param_names $param_defaults $body $class]
}


proc ruff::extract_proc_or_method {proctype procname param_names param_defaults body {class ""}} {
    # Helper procedure used by extract_proc and extract_ooclass_method to
    # construct metainformation for a method or proc.
    #  proctype - should be either 'proc' or 'method'
    #  procname - name of the proc or method
    #  param_names - list of parameter names in order
    #  param_defaults - list of parameter name and default values
    #  body - the body of the proc or method
    #  class - the name of the class to which the method belongs. Not used
    #   for proc types.
    #
    # The command parses the $body parameter as described by the distill_body
    # and parse commands and then constructs the metainformation for
    # the proc or method using this along with the other passed arguments.
    # The metainformation is returned as a dictionary with the following keys:
    #   name - name of the proc or method
    #   parameters - a list of parameters. Each element of the
    #     list is a pair or a triple, consisting of the parameter name,
    #     the description and possibly the default value if there is one.
    #   options - a list of options. Each element is a pair consisting
    #     of the name and its description.
    #   description - a list of paragraphs describing the command. The
    #     list contains preformatted, paragraph, bulletlist and deflist
    #     elements as described for the extract_docstring command.
    #   return - a description of the return value of the command
    #   summary - a copy of the first paragraph if it was present
    #     before the parameter descriptions.
    #   source - the source code of the command
    #

    array set param_default $param_defaults
    array set params {}
    array set options {}
    set paragraphs {}

    # Loop and construct the documentation
    foreach {type content} [parse [distill_body $body]] {
        switch -exact -- $type {
            parameter {
                # For each parameter, check if it is a 
                # parameter in the proc/method definition
                foreach {name desc} $content {
                    if {[lsearch -exact $param_names $name] >= 0} {
                        set params($name) [join $desc " "]
                    } else {
                        #TBD - how to handle this? For now, assume it's
                        #a parameter as well
                        app::log_error "Parameter '$name' not listed in arguments for '$procname'"
                        set params($name) [join $desc " "]
                    }
                }
            }
            summary -
            return {
                set doc($type) [join $content " "]
            }
            deflist {
                # Named lists are lumped with paragraphs
                # Each named list is a list of pairs
                set deflist {}
                foreach {name desc} $content {
                    lappend deflist $name [join $desc " "]
                }
                lappend paragraphs deflist $deflist
            }
            bulletlist {
                # Bullet lists are lumped with paragraphs
                set bulletlist {}
                foreach desc $content {
                    lappend bulletlist [join $desc " "]
                }
                lappend paragraphs bulletlist $bulletlist
            }
            option {
                foreach {name desc} $content {
                    if {[lsearch -exact $param_names "args"] < 0} {
                        app::log_error "Documentation for '$procname' contains option '$name' but the procedure definition does not have an 'args' parameter"
                    }
                    set options($name) [join $desc " "]
                }
            }
            paragraph {
                lappend paragraphs paragraph [join $content " "]
            }
            preformatted {
                lappend paragraphs preformatted [join $content \n]
            }
            default {
                error "Unknown text fragment type '$type'."
            }
        }
    }

    set doc(name)        $procname
    set doc(class)       $class
    set doc(description) $paragraphs
    set doc(proctype)    $proctype

    # Construct parameter descriptions. Note those not listed in the
    # actual proc definition are left out even if they are in the params
    # table
    set doc(parameters) {}
    foreach name $param_names {
        if {[info exists params($name)]} {
            set paramdata [dict create name $name description $params($name) type parameter]
        } else {
            set paramdata [dict create name $name type parameter]
        }

        # Check if there is a default
        if {[info exists param_default($name)]} {
            dict set paramdata default $param_default($name)
        }

        lappend doc(parameters) $paramdata
    }

    # Add the options into the parameter table
    foreach name [lsort [array names options]] {
        lappend doc(parameters) [dict create name $name description $options($name) type option]
    }

    set source "$proctype $procname "
    set param_list {}
    foreach name $param_names {
        if {[info exists param_default($name)]} {
            lappend param_list [list $name $param_default($name)]
        } else {
            lappend param_list $name
        }
    }


    append source "{$param_list} {\n"
    # We need to reformat the body. If nested inside a namespace eval
    # for example, the body will be indented too much. So we undent the
    # least indented line to 0 spaces and then add 4 spaces for each line.
    append source [::textutil::adjust::indent [::textutil::adjust::undent $body] "    "]
    append source "\n}"
    set doc(source) $source

    return [eval dict create [array get doc]]
}


proc ruff::extract_ooclass {classname args} {
    # Extracts metainformation about the specified class
    # classname - name of the class to be documented
    # -includeprivate BOOLEAN - if true private methods are also included
    #  in the metainformation. Default is false.
    #
    # The metainformation. returned is in the form of a dictionary with
    # the following keys:
    # name - name of the class
    # methods - a list of method definitions for this class in the form
    #  returned by extract_ooclass_method with the additional key
    #  'visibility' which may have values 'public' or 'private'.
    # external_methods - a list of names of methods that are
    #  either inherited or mixed in
    # filters - a list of filters defined by the class
    # forwards - a list of forwarded methods, each element in the
    #  list being a dictionary with keys 'name' and 'forward'
    #  corresponding to the forwarded method name and the forwarding command.
    # mixins - a list of names of classes mixed into the class
    # superclasses - a list of names of classes which are direct
    #   superclasses of the class
    # subclasses - a list of classes which are direct subclasses of this class
    # constructor - method definition for the constructor in the format
    #   returned by extract_ooclass_method
    # destructor - method definition for the destructor
    #   returned by extract_ooclass_method
    #
    # Each method definition is in the format returned by the 
    # extract_ooclass_method command with an additional keys:
    # visibility - indicates whether the method is 'public' or 'private'

    array set opts {-includeprivate false}
    array set opts $args

    set result [dict create methods {} external_methods {} \
                    filters {} forwards {} \
                    mixins {} superclasses {} subclasses {} \
                    name $classname \
                   ]

    if {$opts(-includeprivate)} {
        set all_local_methods [info class methods $classname -private]
        set all_methods [info class methods $classname -all -private]
    } else {
        set all_local_methods [info class methods $classname]
        set all_methods [info class methods $classname -all]
    }
    set public_methods [info class methods $classname -all]
    set external_methods {}
    foreach name $all_methods {
        set implementing_class [locate_ooclass_method $classname $name]
        if {[lsearch -exact $all_local_methods $name] < 0} {
            # Skip the destroy method which is standard and 
            # appears in all classes.
            if {$implementing_class ne "::oo::object" ||
                $name ne "destroy"} {
                lappend external_methods [list $name $implementing_class]
            }
            continue
        }

        # Even if a local method, it may be hidden by a mixin
        if {$implementing_class ne $classname} {
            # TBD - should we make a note in the documentation somewhere ?
            app::log_error "Method $name in class $classname is hidden by class $implementing_class."
        }

        if {[lsearch -exact $public_methods $name] >= 0} {
            set visibility public
        } else {
            set visibility private
        }

        if {! [catch {
            set method_info [extract_ooclass_method $classname $name]
        } msg]} {
            dict set method_info visibility $visibility
            #dict set method_info name $name
            dict lappend result methods $method_info
        } else {
            # Error, may be it is a forwarded method
            if {! [catch {
                set forward [info class forward $classname $name]
            }]} {
                dict lappend result forwards [dict create name $name forward $forward]
            } else {
                ruff::app::log_error "Could not introspect method $name in class $classname"
            }
        }
    }

    foreach name {constructor destructor} {
        if {[info class $name $classname] ne ""} {
            # Class has non-empty constructor or destructor
            dict set result $name [extract_ooclass_method $classname $name]
        }
    }

    dict set result name $classname;   # TBD - should we fully qualify this?
    dict set result external_methods $external_methods
    dict set result filters [info class filters $classname]
    dict set result mixins [info class mixins $classname]
    dict set result subclasses [info class subclasses $classname]
    # We do not want to list ::oo::object which is a superclass
    # of all classes.
    set classes {}
    foreach class [info class superclasses $classname] {
        if {$class ne "::oo::object"} {
            lappend classes $class
        }
    }
    dict set result superclasses $classes

    return $result
}


proc ruff::extract {pattern args} {
    # Extracts metainformation for procs and classes 
    #
    # pattern - glob-style pattern to match against procedure and class names
    # -includeclasses BOOLEAN - if true (default), class information
    #     is collected
    # -includeprocs - if true (default), proc information is
    #     collected
    # -includeprivate BOOLEAN - if true private methods are also included.
    #  Default is false.
    #
    # The value of the classes key in the returned dictionary is
    # a dictionary whose keys are class names and whose corresponding values
    # are in the format returned by extract_ooclass.
    # Similarly, the procs key contains a dictionary whose keys
    # are proc names and whose corresponding values are in the format
    # as returned by extract_proc.
    #
    # Note that only the program elements in the same namespace as
    # the namespace of $pattern are returned.
    #
    # Returns a dictionary with keys 'classes' and 'procs'

    array set opts {
        -includeclasses true
        -includeprocs true
        -includeprivate false
        -includeimports false
    }
    array set opts $args

    set classes [dict create]
    if {$opts(-includeclasses)} {
        # We do a catch in case this Tcl version does not support objects
        set class_names {}
        catch {set class_names [info class instances ::oo::class $pattern]}
        foreach class_name $class_names {
            # This covers child namespaces as well which we do not want
            # so filter those out. The differing pattern interpretations in
            # Tcl commands 'info class instances' and 'info procs'
            # necessitates this.
            if {[namespace qualifiers $class_name] ne [namespace qualifiers $pattern]} {
                # Class is in not in desired namespace
                # TBD - do we need to do -includeimports processing here?
                continue
            }
            # Names beginning with _ are treated as private
            if {(!$opts(-includeprivate)) &&
                [string index [namespace tail $class_name] 0] eq "_"} {
                continue
            }
            
            if {[catch {
                set class_info [extract_ooclass $class_name -includeprivate $opts(-includeprivate)]
            } msg]} {
                app::log_error "Could not document class $class_name"
            } else {
                dict set classes $class_name $class_info
            }
        }
    }

    set procs [dict create]
    if {$opts(-includeprocs)} {
        foreach proc_name [info procs $pattern] {
            #ruff
            # -includeimports BOOLEAN - if true commands imported from other
            #  namespaces are also included. Default is false.
            if {(! $opts(-includeimports)) &&
                [namespace origin $proc_name] ne $proc_name} {
                continue;       # Do not want to include imported commands
            }
            # Names beginning with _ are treated as private
            if {(!$opts(-includeprivate)) &&
                [string index [namespace tail $proc_name] 0] eq "_"} {
                continue
            }

            if {[catch {
                set proc_info [extract_proc $proc_name]
            } msg]} {
                app::log_error "Could not document proc $proc_name"
            } else {
                dict set procs $proc_name $proc_info
            }
        }
    }

    return [dict create classes $classes procs $procs]
}


proc ruff::extract_namespace {ns args} {
    # Extracts metainformation for procs and objects in a namespace
    # ns - namespace to examine
    #
    # Any additional options are passed on to the extract command.
    #
    # Returns a dictionary with keys 'classes' and 'procs'. See ruff::extract
    # for details.
    
    return [eval [list extract ${ns}::*] $args]
}

proc ruff::extract_namespaces {namespaces args} {
    # Extracts metainformation for procs and objects in one or more namespace
    # namespaces - list of namespace to examine
    #
    # Any additional options are passed on to the extract_namespace command.
    #
    # Returns a dictionary with keys 'classes' and 'procs'. See ruff::extract
    # for details.
    
    set procs [dict create]
    set classes [dict create]
    foreach ns $namespaces {
        set nscontent [eval [list extract ${ns}::*] $args]
        set procs   [dict merge $procs [dict get $nscontent procs]]
        set classes [dict merge $classes [dict get $nscontent classes]]
    }
    return [dict create procs $procs classes $classes]
}


proc ruff::get_ooclass_method_path {class_name method_name} {
    # Calculates the class search order for a method of the specified class
    # class_name - name of the class to which the method belongs
    # method_name - method name being searched for
    #
    # A method implementation may be provided by the class itself,
    # a mixin or a superclass.
    # This command calculates the order in which these are searched
    # to locate the method. The primary purpose is to find exactly
    # which class actually implements a method exposed by the class.
    #
    # If a class occurs multiple times due to inheritance or
    # mixins, the LAST occurence of the class is what determines
    # the priority of that class in method selection. Therefore
    # the returned search path may contain repeated elements.
    #
    # Note that this routine only applies to a class and cannot be
    # used with individual objects which may have their own mix-ins.


    # TBD - do we need to distinguish private/public methods

    set method_path {}
    #ruff
    # Search algorithm:
    #  - Filters are ignored. They may be invoked but are not considered
    #    implementation of the method itself.
    #  - The mixins of a class are searched even before the class itself
    #    as are the superclasses of the mixins.
    foreach mixin [info class mixins $class_name] {
        # We first need to check if the method name is in the public interface
        # for this class. This step is NOT redundant since a derived
        # class may unexport a method from an inherited class in which
        # case we should not have the inherited classes in the path
        # either.
        if {[lsearch -exact [info class methods $mixin -all] $method_name] < 0} {
            continue
        }

        set method_path [concat $method_path [get_ooclass_method_path $mixin $method_name]]
    }

    #ruff - next in the search path is the class itself
    if {[lsearch -exact [info class methods $class_name] $method_name] >= 0} {
        lappend method_path $class_name
    }

    #ruff - Last in the search order are the superclasses (in recursive fashion)
    foreach super [info class superclasses $class_name] {
        # See comment in mixin code above.
        if {[lsearch -exact [info class methods $super -all] $method_name] < 0} {
            continue
        }
        set method_path [concat $method_path [get_ooclass_method_path $super $method_name]]
    }
    

    #ruff
    # Returns an ordered list containing the classes that are searched
    # to locate a method for the specified class.
    return $method_path
}

proc ruff::locate_ooclass_method {class_name method_name} {
    # Locates the classe that implement the specified method of a class
    # class_name - name of the class to which the method belongs
    # method_name - method name being searched for
    #
    # The matching class may implement the method itself or through
    # one of its own mix-ins or superclasses.
    #
    # Returns the name of the implementing class or an empty string
    # if the method is not implemented.
    
    # Note: we CANNOT just calculate a canonical search path for a
    # given class and then search along that for a class that
    # implements a method. The search path itself will depend on the
    # specific method being searched for due to the fact that a
    # superclass may not appear in a particular search path if a
    # derived class hides a method (this is just one case, there may
    # be others). Luckily, get_ooclass_method_path does exactly this.

    
    set class_path [get_ooclass_method_path $class_name $method_name]

    if {[llength $class_path] == 0} {
        return "";              # Method not found
    }

    # Now we cannot just pick the first element in the path. We have
    # to find the *last* occurence of each class - that will decide
    # the priority order
    set order [dict create]
    set pos 0
    foreach path_elem $class_path {
        dict set order $path_elem $pos
        incr pos
    }

    return [lindex $class_path [lindex [lsort -integer [dict values $order]] 0] 0]
}


proc ruff::_load_all_formatters {} {
    # Loads all available formatter implementations
    foreach formatter [formatters] {
        _load_formatter $formatter
    }
}

proc ruff::_load_formatter {formatter {force false}} {
    # Loads the specified formatter implementation
    variable ruff_dir
    set fmt_cmd [namespace current]::formatter::${formatter}::generate_document
    if {[info commands $fmt_cmd] eq "" || $force} {
        uplevel #0 [list source [file join $ruff_dir ${formatter}_formatter.tcl]]
    }
}


proc ruff::document {formatter classprocinfodict {docstrings {}} args} {
    # Generates documentation for the specified namespaces using the
    # specified formatter.
    # formatter - the formatter to be used to produce the documentation
    # classprocinfodict - dictionary containing the metainformation for
    #  classes and procs for which documentation is to be generated. This
    #  must be in the format returned by the extract command.
    # docstrings - a flat list of pairs consisting of a heading and
    #    corresponding content. These are inserted into the document
    #    before the actual class and command descriptions after being
    #    processed by extract_docstring.
    #
    # All additional arguments are passed through to the specified
    # formatter's generate_document command.
    #
    # Returns the documentation string as generated by the specified formatter.

    _load_formatter $formatter

    set preamble [dict create]
    foreach {sec docstring} $docstrings {
        # Treate the preamble as a "toplevel" preamble
        dict lappend preamble "::" $sec [extract_docstring $docstring]
    }

    return [eval [list [namespace current]::formatter::${formatter}::generate_document $classprocinfodict -preamble $preamble] $args]
}

proc ruff::document_namespace {formatter ns args} {
    # Obsolete, use document_namespaces instead.
    return [eval [list document_namespaces $formatter [list $ns] -title $ns] $args]
}

proc ruff::document_namespaces {formatter namespaces args} {
    # Generates documentation for the specified namespaces using the
    # specified formatter.
    # formatter - the formatter to be used to produce the documentation
    # namespaces - list of namespaces for which documentation is to be generated
    # -includeclasses BOOLEAN - if true (default), class information
    #     is collected
    # -includeprocs BOOLEAN - if true (default), proc information is
    #     collected
    # -includeprivate BOOLEAN - if true private methods are also included
    #  in the generated documentation. Default is false.
    # -includesource BOOLEAN - if true, the source code of the
    #  procedure is also included. Default value is false.
    # -output PATH - if specified, the generated document is written
    #  to the specified file which will overwritten if it already exists.
    # -append BOOLEAN - if true, the generated document is appended
    #  to the specified file instead of overwriting it.
    # -title STRING - specifies the title to use for the page
    # -recurse BOOLEAN - if true, child namespaces are recursively
    #  documented.
    #
    # Any additional arguments are passed through to the document command.
    #
    # Returns the documentation string if the -output option is not
    # specified, otherwise returns an empty string after writing the
    # documentation to the specified file.

    array set opts {
        -includeclasses true
        -includeprocs true
        -includeprivate false
        -includesource false
        -output ""
        -append false
        -title ""
        -recurse false
    }
    array set opts $args
    
    if {$opts(-recurse)} {
        set namespaces [_namespace_tree $namespaces]
    }

    set preamble [dict create]
    foreach ns $namespaces {
        if {[info exists ${ns}::_ruffdoc]} {
            foreach {section docstring} [set ${ns}::_ruffdoc] {
                dict lappend preamble $ns $section [extract_docstring $docstring]
            }
        }
    }

    set classprocinfodict [extract_namespaces $namespaces \
                               -includeclasses $opts(-includeclasses) \
                               -includeprocs $opts(-includeprocs) \
                               -includeprivate $opts(-includeprivate)]

    _load_formatter $formatter
    set doc  [eval \
                  [list formatter::${formatter}::generate_document \
                       $classprocinfodict \
                       -preamble $preamble \
                       -modulename $opts(-title) \
                      ] \
                  $args]
    if {$opts(-output) ne ""} {
        if {$opts(-append)} {
            set fd [open $opts(-output) a]
        } else {
            set fd [open $opts(-output) w]
        }
        if {[catch {
            puts $fd $doc
        } msg]} {
            close $fd
            error $msg
        }
        close $fd
        return
    } else {
        return $doc
    }
}

proc ruff::formatters {} {
    # Get the list of supported formatters.
    #
    # Ruff! can produce documentation in several formats each of which
    # is produced by a specific formatter. This command returns the list
    # of such formatters that can be used with commands like
    # document.
    #
    # Returns a list of available formatters.
    variable ruff_dir
    set formatters {}
    set suffix "_formatter.tcl"
    foreach file [glob [file join $ruff_dir *$suffix]] {
        lappend formatters [string range [file tail $file] 0 end-[string length $suffix]]
    }
    return $formatters
}

proc ruff::_wrap_text {text args} {
    # Wraps a string such that each line is less than a given width
    # and begins with the specified prefix.
    # text - the string to be reformatted
    # The following options may be specified:
    # -width INTEGER - the maximum width of each line including the prefix 
    #  (defaults to 60)
    # -prefix STRING - a string that every line must begin with. Defaults
    #  to an empty string.
    # -prefix1 STRING - prefix to be used for the first line. If unspecified
    #  defaults to the value for the -prefix option if specified
    #  and an empty string otherwise.
    #
    # The given text is transformed such that it consists of
    # a series of lines separated by a newline character
    # where each line begins with the specified prefix and
    # is no longer than the specified width.
    # Further each line is filled with as many characters
    # as possible without breaking a word across lines.
    # Blank lines and leading and trailing spaces are removed.
    #
    # Returns the wrapped and indented text

    set opts [dict merge [dict create -width 60 -prefix ""] $args]

    if {![dict exists $opts -prefix1]} {
        dict set opts -prefix1 [dict get $opts -prefix]
    }

    set prefix [dict get $opts -prefix]
    set prefix1 [dict get $opts -prefix1]

    set width [dict get $opts -width]
    # Reduce the width by the longer prefix length
    if {[string length $prefix] > [string length $prefix1]} {
        incr width  -[string length $prefix]
    } else {
        incr width  -[string length $prefix1]
    }

    # Note the following is not optimal in the sense that
    # it is possible some lines could fit more words but it's
    # simple and quick.

    # First reformat
    set text [textutil::adjust::indent \
                  [::textutil::adjust::adjust $text -length $width] \
                  $prefix]

    # Replace the prefix for the first line. Note that because of
    # the reduction in width based on the longer prefix above,
    # the max specified width will not be exceeded.
    return [string replace $text 0 [expr {[string length $prefix]-1}] $prefix1]
}


proc ruff::document_self {formatter output_dir args} {
    # Generates documentation for Ruff!
    # formatter - the formatter to use
    # output_dir - the output directory where files will be stored. Note
    #  files in this directory with the same name as the output files
    #  will be overwritten!
    # -formatterpath PATH - path to the formatter. If unspecified, the
    #  the input files for the formatter are generated but the formatter
    #  is not run. This option is ignore for the built-in HTML formatter.
    # -includesource BOOLEAN - if true, include source code in documentation.

    variable names

    array set opts {
        -formatterpath ""
        -includesource FALSE
    }
    array set opts $args

    _load_all_formatters;       # So all will be documented!

    set modules [dict create]
    # Enumerate and set the descriptive text for all the modules.
    # TBD - use these settings to generate preambles for the modules
    dict set modules ::ruff \
        [dict create description "$names(display) main module"]
    dict set modules ::ruff::formatter \
        [dict create description "$names(display) formatters"]
    dict set modules ::ruff::formatter::doctools \
        [dict create description "$names(display) formatter for Doctools"]
    dict set modules ::ruff::formatter::naturaldocs \
        [dict create description "$names(display) formatter for NaturalDocs"]
    dict set modules ::ruff::formatter::robodoc \
        [dict create description "$names(display) formatter for ROBODoc"]
    dict set modules ::ruff::formatter::html \
        [dict create description "$names(display) formatter for HTML"]
    dict set modules ::ruff::app \
        [dict create description "$names(display) application callbacks"]

    file mkdir $output_dir
    if {$formatter ne "html"} {
        # For external formatters, we need input and output directories
        set outdir [file join $output_dir output]
        set indir  [file join $output_dir Ruff]
        file mkdir $indir;  # Input for formatter, output for us!
        file mkdir $outdir
    }
    switch -exact -- $formatter {
        naturaldocs {
            set projdir [file join $output_dir proj]
            file mkdir $projdir
            dict for {ns nsdata} $modules {
                set fn [string map {:: _} [string trimleft $ns :]]
                set fn "[file join $indir $fn].tcl"
                document_namespace naturaldocs $ns -output $fn -hidenamespace $ns
            }
            # We want to change the stylesheet for NaturalDocs
            set fd [open [file join $projdir ruff.css] w]
            puts $fd "p { text-indent: 0; margin-bottom: 1em; }"
            puts $fd "blockquote {margin-left: 5em;}"
            close $fd
            if {$opts(-formatterpath) ne ""} {
                if {[catch {
                    eval exec $opts(-formatterpath) [list --input $indir \
                                                   --output HTML $outdir \
                                                   --project $projdir \
                                                   --rebuild \
                                                   --style Default ruff \
                                                  ]
                } msg]} {
                    app::log_error "Error executing NaturalDocs using path '$opts(-formatterpath)': $msg"
                }
            }
        }
        doctools {
            dict for {ns nsdata} $modules {
                set fn [string map {:: _} [string trimleft $ns :]]
                set fn "[file join $indir $fn].man"
                document_namespace doctools $ns -output $fn -hidenamespace $ns \
                    -name $ns \
                    -keywords [list "documentation generation"] \
                    -modulename $ns \
                    -titledesc [dict get $nsdata description] \
                    -version $::ruff::version
            }
            if {$opts(-formatterpath) ne ""} {
                if {[catch {
                    eval exec $opts(-formatterpath) [list -o $outdir html $indir]
                } msg]} {
                    app::log_error "Error executing doctools using path '$opts(-formatterpath)': $msg"
                }
            }
        }
        html {
            # Note here we use $output_dir since will directly produce HTML
            # and not intermediate files
            document_namespaces html ::ruff -recurse true \
                -output [file join $output_dir ruff.html] \
                -titledesc "Ruff! - Runtime Formatting Function Reference (V$::ruff::version)" \
                -copyright "[clock format [clock seconds] -format %Y] Ashok P. Nadkarni" \
                -includesource $opts(-includesource)
        }
        default {
            # The formatter may exist but we do not support it for
            # out documentation.
            error "Formatter '$formatter' not implemented for generating Ruff! documentation."
        }
    }
    return
}


################################################################
#### Application overrides

# The app namespace is for commands the application might want to
# override
namespace eval ruff::app {
}


proc ruff::app::log_error {msg} {
    # Stub function to log Ruff! errors.
    # msg - the message to be logged
    #
    # When Ruff! encounters errors, it calls this command to
    # notify the user. By default, the command writes $msg
    # to stderr output. An application using the ruff package
    # can redefine this command after loading ruff.
    puts stderr "$msg"
}



#
# Robodoc command line:
#  ruff::document_namespace robodoc ::ruff -output out.tcl -hidenamespace ::ruff
#  exec robodoc --src out.tcl --doc out --singlefile --html --nopre --toc
#
# doctools command line:
# ::ruff::document_namespace doctools ::ruff -output ruff.man
#  exec tclsh86 c:/bin/tcl86/bin/dtplite.tcl -o ruff.html html ruff.man
#
# NaturalDocs command line:
#  ::ruff::document_namespace naturaldocs ::ruff -output nd/nd.tcl -hidenamespace ::ruff
#  exec perl {\bin\NaturalDocs\NaturalDocs} -i nd -o HTML out -p proj
#  exec cmd /c start out\\index.html &
#
# or to document Ruff!
#   ruff::document_self naturaldocs ndout {perl c:/bin/naturaldocs/naturaldocs}


package provide ruff $::ruff::version
