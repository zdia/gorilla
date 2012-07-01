package require Tcl 8.4
package require Itcl
package require sha256
package require iblowfish
package require itwofish

#
# ----------------------------------------------------------------------
# This file contains the public API for the pwsafe package
# ----------------------------------------------------------------------
#

namespace eval pwsafe {}

#
# ----------------------------------------------------------------------
# createFromStream: create a pwsafe::db object from a stream object
# ----------------------------------------------------------------------
#

proc pwsafe::createFromStream {stream password version {percentvar ""}} {
    if {$percentvar != ""} {
	upvar $percentvar pcv
	set pcvp "pcv"
    } else {
	set pcvp ""
    }

    set db [namespace current]::[pwsafe::db #auto $password]

    if {$version == 3} {
	set reader [namespace current]::[pwsafe::v3::reader #auto $db $stream]
    } else {
	set reader [namespace current]::[pwsafe::v2::reader #auto $db $stream]
    }

    if {[catch {$reader readFile $pcvp} oops]} {
	set origErrorInfo $::errorInfo
	itcl::delete object $reader
	itcl::delete object $db
	error $oops $origErrorInfo
    }

    itcl::delete object $reader
    return $db
}

#
# ----------------------------------------------------------------------
# createFromFile: create a pwsafe object from a file
# ----------------------------------------------------------------------
#

proc pwsafe::createFromFile {fileName password {percentvar ""}} {
    if {$percentvar != ""} {
	upvar $percentvar pcv
	set pcvp "pcv"
    } else {
	set pcvp ""
    }

    if {[catch {set size [file size $fileName]}]} {
	set size -1
    }

    set file [open $fileName "r"]
    fconfigure $file -translation binary

    #
    # Check if the file begins with the Password Save 3.x "PWS3" magic.
    #

    set magic [::read $file 4]
    ::seek $file 0

    set stream [namespace current]::[pwsafe::io::streamreader #auto $file $size]

    if {[catch {
			if {[string equal $magic "PWS3"]} {
		    set db [pwsafe::createFromStream $stream $password 3 $pcvp]
			} else {
		    set db [pwsafe::createFromStream $stream $password 2 $pcvp]
			}
						    } oops]} {
			set origErrorInfo $::errorInfo
			itcl::delete object $stream
			catch {close $file}
			error $oops $origErrorInfo
    }
    itcl::delete object $stream

    if {[catch {close $file} oops]} {
	itcl::delete object $db
	error $oops
    }

    return $db
}

#
# ----------------------------------------------------------------------
# createFromString: create a pwsafe object from an (in-memory) string
# ----------------------------------------------------------------------
#

proc pwsafe::createFromString {data password {percentvar ""}} {
    if {$percentvar != ""} {
	upvar $percentvar pcv
	set pcvp "pcv"
    } else {
	set pcvp ""
    }

    #
    # Check if the string begins with the Password Save 3.x "PWS3" magic.
    #

    set stream [namespace current]::[pwsafe::io::stringreader #auto $data]

    if {[catch {
	if {[string equal -length 4 $data "PWS3"]} {
	    set db [pwsafe::createFromStream $stream $password 3 $pcvp]
	} else {
	    set db [pwsafe::createFromStream $stream $password 2 $pcvp]
	}
    } oops]} {
	set origErrorInfo $::errorInfo
	itcl::delete object $stream
	error $oops $origErrorInfo
    }

    itcl::delete object $stream
    return $db
}

#
# ----------------------------------------------------------------------
# writeToFile: write a pwsafe object to a file
# ----------------------------------------------------------------------
#

proc pwsafe::writeToFile {db fileName version {percentvar ""}} {
    if {$percentvar != ""} {
	upvar $percentvar pcv
	set pcvp "pcv"
    } else {
	set pcvp ""
    }

    #
    # Write to a temporary file first, then make sure that the
    # real destination file does not exist (delete if it does),
    # then rename the file. This way, the existing database is
    # not lost, if something goes wrong.
    #

    set tmpFileName $fileName
    append tmpFileName ".tmp"

    set file [open $tmpFileName "w"]
    fconfigure $file -translation binary

    set stream [namespace current]::[pwsafe::io::streamwriter #auto $file]

    if {$version == 3} {
	set writer [namespace current]::[pwsafe::v3::writer #auto $db $stream]
    } elseif {$version == 2} {
	set writer [namespace current]::[pwsafe::v2::writer #auto $db $stream]
    } else {
	error [ mc "invalid version %s" $version ]
    }

    if {[catch {$writer writeFile $pcvp} oops]} {
	set origErrorInfo $::errorInfo
	itcl::delete object $writer
	itcl::delete object $stream
	catch {close $file}
	catch {file delete $tmpFileName}
	error $oops $origErrorInfo
    }

	itcl::delete object $writer
	itcl::delete object $stream
	close $file

	#
	# Done writing to temporary file.
	#

	file rename -force -- $tmpFileName $fileName
	
} ; # end proc pwsafe::writeToFile

#
# ----------------------------------------------------------------------
# writeToString: write a pwsafe object to a string
# ----------------------------------------------------------------------
#

proc pwsafe::writeToString {db version {percentvar ""}} {
    if {$percentvar != ""} {
	upvar $percentvar pcv
	set pcvp "pcv"
    } else {
	set pcvp ""
    }


    set stream [namespace current]::[pwsafe::io::stringwriter #auto]

    if {$version == 3} {
	set writer [namespace current]::[pwsafe::v3::writer #auto $db $stream]
    } elseif {$version == 2} {
	set writer [namespace current]::[pwsafe::v2::writer #auto $db $stream]
    } else {
	error [ mc "invalid version %s" $version ]
    }

    if {[catch {$writer writeFile $pcvp} oops]} {
	set origErrorInfo $::errorInfo
	itcl::delete object $writer
	itcl::delete object $stream
	catch {close $file}
	error $oops $origErrorInfo
    }

    set result [$stream cget -data]
    itcl::delete object $writer
    itcl::delete object $stream
    return $result
}

#
# ----------------------------------------------------------------------
# pwsafe::dumpAllRecords: print all records in a human readable manner
# ----------------------------------------------------------------------
#

proc pwsafe::dumpAllRecords {db out} {
    foreach rn [$db getAllRecordNumbers] {
	pwsafe::io::dumpRecord $db $out $rn
    }
}

#
# ----------------------------------------------------------------------
# Source the pwsafe::db implementation and the various helpers
# ----------------------------------------------------------------------
#

set pwsafeDir [file dirname [info script]]
source [file join $pwsafeDir "pwsafe-int.tcl"]
source [file join $pwsafeDir "pwsafe-db.tcl"]
source [file join $pwsafeDir "pwsafe-io.tcl"]
source [file join $pwsafeDir "pwsafe-v2.tcl"]
source [file join $pwsafeDir "pwsafe-v3.tcl"]
unset pwsafeDir

#
# ----------------------------------------------------------------------
# finishing touches
# ----------------------------------------------------------------------
#

package provide pwsafe 0.2
