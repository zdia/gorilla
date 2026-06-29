#
# ----------------------------------------------------------------------
# pwsafe::io::streamreader: reads from a Tcl stream
# pwsafe::io::streamwrite: writes to a Tcl stream
# ----------------------------------------------------------------------
#
# Note: stream must not be non-blocking
#

catch {
    itcl::delete class pwsafe::io::streamreader
    itcl::delete class pwsafe::io::streamwriter
}

itcl::class pwsafe::io::streamreader {
    protected variable stream
    protected variable sz

    public method read {numChars} {
	return [::read $stream $numChars]
    }

    public method eof {} {
	return [::eof $stream]
    }

    public method tell {} {
	return [::tell $stream]
    }

    public method size {} {
	return $sz
    }

    constructor {stream_ sz_} {
	set stream $stream_
	set sz $sz_
    }
}

itcl::class pwsafe::io::streamwriter {
    protected variable stream

    public method write {data} {
	return [::puts -nonewline $stream $data]
    }

    constructor {stream_} {
	set stream $stream_
    }
}

#
# ----------------------------------------------------------------------
# pwsafe::io::stringreader: reads from a string
# pwsafe::io::stringwriter: writes to a string
# ----------------------------------------------------------------------
#

catch {
    itcl::delete class pwsafe::io::stringreader
    itcl::delete class pwsafe::io::stringwriter
}

itcl::class pwsafe::io::stringreader {
    protected variable data
    protected variable index

    public method read {numChars} {
	if {$index >= [string length $data]} {
	    return ""
	}
	set result [string range $data $index [expr {$index + $numChars - 1}]]
	incr index $numChars
	return $result
    }

    public method eof {} {
	if {$index >= [string length $data]} {
	    return 1
	}
	return 0
    }

    public method tell {} {
	return $index
    }

    public method size {} {
	return [string length $data]
    }

    constructor {data_} {
	set data $data_
	set index 0
    }
}

itcl::class pwsafe::io::stringwriter {
    public variable data

    public method write {x} {
	append data $x
    }
}

#
# ----------------------------------------------------------------------
# Dump a human redably formatted record to a Tcl output stream
# ----------------------------------------------------------------------
#

proc pwsafe::io::dumpRecord {db out rn} {
    set fields [$db getFieldsForRecord $rn]
    puts $out "Record \# $rn"
    foreach field [lsort -integer $fields] {
	set value [$db getFieldValue $rn $field]
	switch -- $field {
	    1 {
		puts $out "      UUID: $value"
	    }
	    2 {
		puts $out "     Group: $value"
	    }
	    3 {
		puts $out "     Title: $value"
	    }
	    4 {
		puts $out "  Username: $value"
	    }
	    5 {
		set value [string map {\n {\n            }} $value]
		puts $out "     Notes: $value"
	    }
	    6 {
		puts $out "  Password: $value"
	    }
	    default {
		set fn "<$field>"
		puts $out "      [format %4s $fn]: $value"
	    }
	}
    }
}

