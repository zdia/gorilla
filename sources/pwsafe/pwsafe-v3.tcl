#
# ----------------------------------------------------------------------
# pwsafe::v3::reader: reads an existing file from a stream
# ----------------------------------------------------------------------
#

namespace eval pwsafe::v3 {}

catch {
    itcl::delete class pwsafe::v3::reader
}

itcl::class pwsafe::v3::reader {
    #
    # An object of type pwsafe::db, to read into
    #

    protected variable db

    #
    # Object to read data from, using its "read <numChars>" method
    #

    protected variable source

    #
    # An object of type itwofish::cbc
    #

    protected variable engine

    #
    # The HMAC-SHA 256 engine
    #

    protected variable hmacEngine

    #
    # We can not be reused; complain if someone tries to
    #

    protected variable used

    #
    # Read one field; returns [list type data]; or empty list on eof
    #

    protected method readField {} {
	#
	# first block contains field length and type
	#

	set encryptedFirstBlock [$source read 16]

	if {$encryptedFirstBlock == "PWS3-EOFPWS3-EOF"} {
	    # EOF marker
	    return [list]
	}

	if {[string length $encryptedFirstBlock] == 0 && [$source eof]} {
	    error [ mc "EOF while reading field" ]
	}

	if {[string length $encryptedFirstBlock] != 16} {
	    error [ mc "less than 16 bytes remaining for first block" ]
	}

	set decryptedFirstBlock [$engine decrypt $encryptedFirstBlock]

	if {[binary scan $decryptedFirstBlock ic fieldLength fieldType] != 2} {
	    error [ mc "oops" ]
	}

	#
	# field length sanity check
	#

	if {$fieldLength < 0 || $fieldLength > 65536} {
	    error [ mc "field length %d looks insane" $fieldLength ]
	}

	#
	# remainder of the first block contains data
	#

	if {$fieldLength <= 11} {
	    set fieldData [string range $decryptedFirstBlock 5 [expr {$fieldLength + 4}]]
	    pwsafe::int::randomizeVar decryptedFirstBlock
	    return [list $fieldType $fieldData]
	}

	set fieldData [string range $decryptedFirstBlock 5 end]
	pwsafe::int::randomizeVar decryptedFirstBlock
	incr fieldLength -11

	#
	# remaining data is stored in multiple blocks
	#

	set numBlocks [expr {($fieldLength + 15) / 16}]
	set dataLength [expr {$numBlocks * 16}]

	#
	# decrypt field
	#

	set encryptedData [$source read $dataLength]

	if {[string length $encryptedData] != $dataLength} {
	    error [ mc "out of data" ]
	}

	set decryptedData [$engine decrypt $encryptedData]

	#
	# adjust length of data; truncate padding
	#

	append fieldData [string range $decryptedData 0 [expr {$fieldLength - 1}]]

	#
	# field decrypted successfully
	#

	pwsafe::int::randomizeVar decryptedData
	return [list $fieldType $fieldData]
    }

    protected method readHeaderFields {} {
	#
	# Read header fields.
	#

	while {![$source eof]} {
	    set field [readField]

	    set fieldType [lindex $field 0]
	    set fieldValue [lindex $field 1]

	    if {$fieldType == -1} {
		break
	    }

	    sha2::HMACUpdate $hmacEngine $fieldValue

	    #
	    # Format the header's field type, if necessary
	    #

	    switch -- $fieldType {
		0 {
		    #
		    # Version
		    #

		    binary scan $fieldValue cc minor major
		    set fieldValue [list $major $minor]
		}
		1 {
		    #
		    # UUID
		    #

		    binary scan $fieldValue H* tmp
		    set fieldValue [string range $tmp 0 7]
		    append fieldValue "-" [string range $tmp 8 11]
		    append fieldValue "-" [string range $tmp 12 15]
		    append fieldValue "-" [string range $tmp 16 19]
		    append fieldValue "-" [string range $tmp 20 31]
		}
	    }

	    $db setHeaderField $fieldType $fieldValue
	}

	#
	# If there is no version header field, then add one. The rest of
	# the code uses it to detect v3 files, assuming v2 otherwise.
	#

	if {![$db hasHeaderField 0]} {
	    $db setHeaderField 0 [list 3 0]
	}
    }

    protected method readAllFields {{percentvar ""}} {
	if {$percentvar != ""} {
	    upvar $percentvar pcv
	}

	set fileSize [$source size]

	#
	# Remaining fields are user data
	#

	set first 1

	while {![$source eof]} {
	    set field [readField]

	    if {[llength $field] == 0} {
		# eof
		break
	    }

	    set filePos [$source tell]

	    if {$filePos != -1 && $fileSize != -1 && \
		    $fileSize != 0 && $filePos <= $fileSize} {
		set percent [expr {100+(100*$filePos/$fileSize)}]
	    } else {
		set percent -1
	    }

	    set pcv $percent

	    set fieldType [lindex $field 0]
	    set fieldValue [lindex $field 1]

	    if {$fieldType == -1} {
		set first 1
		continue
	    }

	    if {$first} {
		set recordnumber [$db createRecord]
		set first 0
	    }

	    sha2::HMACUpdate $hmacEngine $fieldValue

	    #
	    # Format the field's type, if necessary
	    #

	    switch -- $fieldType {
		1 {
		    #
		    # UUID
		    #

		    binary scan $fieldValue H* tmp
		    set fieldValue [string range $tmp 0 7]
		    append fieldValue "-" [string range $tmp 8 11]
		    append fieldValue "-" [string range $tmp 12 15]
		    append fieldValue "-" [string range $tmp 16 19]
		    append fieldValue "-" [string range $tmp 20 31]
		}
		2 -
		3 -
		4 -
		6 -
		13 {
		    #
		    # Text fields are always stored in UTF-8
		    #

		    set fieldValue [encoding convertfrom utf-8 $fieldValue]
		}
		5 {
		    #
		    # Notes field uses CRLF for line breaks, we want LF only.
		    #

		    set fieldValue [encoding convertfrom utf-8 $fieldValue]
		    set fieldValue [string map {\r\n \n} $fieldValue]
		}
		7 -
		8 -
		9 -
		10 -
		12 {
		    #
		    # (7) Creation Time, (8) Password Modification Time,
		    # (9) Last Access Time, (10) Password Lifetime and
		    # (11) Last Modification Time are of type time_t,
		    # i.e., a 4 byte (little endian) integer
		    #

		    if {[binary scan $fieldValue i fieldValue] != 1} {
			continue
		    }

		    #
		    # Make unsigned
		    #

		    set fieldValue [expr {($fieldValue + 0x100000000) % 0x100000000}]

		    #
		    # On Mac, we have to adjust for the different epoch
		    #

		    if {[info exists ::tcl_platform(platform)] && \
			    [string equal $::tcl_platform(platform) "macintosh"]} {
			incr fieldValue 2082844800
		    }
		}
	    }

	    $db setFieldValue $recordnumber $fieldType $fieldValue
	    pwsafe::int::randomizeVar fieldType fieldValue
	}
    }

    public method readFile {{percentvar ""}} {
	if {$used} {
	    error [ mc "this object can not be reused" ]
	}

	set used 1

	if {$percentvar != ""} {
	    upvar $percentvar pcv
	    set pcvp "pcv"
	} else {
	    set pcvp ""
	}

	#
	# The file is laid out as follows:
	#
	# TAG|SALT|ITER|H(P')|B1|B2|B3|B4|IV|
	#
	# TAG is the sequence of 4 ASCII characters "PWS3"
	#
	# SALT is a 256 bit random value
	#
	# ITER is the number of iterations for the password stretching.
	#
	# P' is the "stretched key" H_<ITER>(Password,SALT)
	#
	# B1 and B2 are two 128-bit blocks encrypted with Twofish using
	# P' as the key, in ECB mode.
	#
	# B3 and B4 are two 128-bit blocks encrypted with Twofish using
	# P' as the key, in ECB mode.
	#
	# IV is the 128-bit random initial value for CBC mode.
	#

	set tag [$source read 4]

	if {$tag != "PWS3"} {
	    error [ mc "file does not have PWS3 magic" ]
	}

	set salt [$source read 32]
	set biter [$source read 4]
	set hskey [$source read 32]
	set b1 [$source read 16]
	set b2 [$source read 16]
	set b3 [$source read 16]
	set b4 [$source read 16]
	set iv [$source read 16]

	if {[string length $salt] != 32 || \
		[string length $biter] != 4 || \
		[string length $hskey] != 32 || \
		[string length $b1] != 16 || \
		[string length $b2] != 16 || \
		[string length $b3] != 16 || \
		[string length $b4] != 16 || \
		[string length $iv] != 16} {
	    pwsafe::int::randomizeVar salt hskey b1 b2 b3 b4 iv
	    error [ mc "end of file while reading header" ]
	}

	#
	# Verify the password
	#

	if {[binary scan $biter i iter] != 1} {
	    error [ mc "Failed to scan key stretch iteration count from binary data." ]
	}

	if {$iter < 2048} {
	    #
	    # Low security. Warn.
	    #

	    set dbWarnings [$db cget -warningsDuringOpen]
	    lappend dbWarnings "File only uses low-security $iter iterations\
		for key stretching; at least 2048 recommended."
	    $db configure -warningsDuringOpen $dbWarnings
	}

	$db configure -keyStretchingIterations $iter

	set myskey [pwsafe::int::computeStretchedKey $salt [$db getPassword] $iter $pcvp]
	set myhskey [sha2::sha256 -bin $myskey]
	if {![string equal $hskey $myhskey]} {
	    pwsafe::int::randomizeVar salt hskey b1 b2 b3 b4 iv myskey myhskey
	    error [ mc "wrong password" ]
	}

	pwsafe::int::randomizeVar salt hskey myhskey

	#
	# The real key is encrypted using Twofish in ECB mode, using
	# the stretched passphrase as its key.
	#

	set hdrEngine [itwofish::ecb \#auto $myskey]
	pwsafe::int::randomizeVar myskey

	#
	# Decrypt the real key from b1 and b2, and the key L that is
	# used to calculate the HMAC
	#

	set key [$hdrEngine decryptBlock $b1]
	append key [$hdrEngine decryptBlock $b2]
	pwsafe::int::randomizeVar b1 b2

	set hmacKey [$hdrEngine decryptBlock $b3]
	append hmacKey [$hdrEngine decryptBlock $b4]
	set hmacEngine [sha2::HMACInit $hmacKey]
	pwsafe::int::randomizeVar b3 b4 hmacKey

	itcl::delete object $hdrEngine

	#
	# Create decryption engine using key and initialization vector
	#

	set engine [itwofish::cbc \#auto $key $iv]
	pwsafe::int::randomizeVar key iv

	#
	# Read data
	#

	if {[catch {
	    readHeaderFields
	    readAllFields $pcvp
	} oops]} {
	    set errorInfo $::errorInfo
	    sha2::HMACFinal $hmacEngine
	    itcl::delete object $engine
	    set engine ""
	    error $oops $errorInfo
	}

	#
	# Read and validate HMAC
	#

	set hmac [$source read 32]
	set myHmac [sha2::HMACFinal $hmacEngine]

	if {![string equal $hmac $myHmac]} {
	    set dbWarnings [$db cget -warningsDuringOpen]
	    lappend dbWarnings "Database authentication failed. File may\
		have been tampered with."
	    $db configure -warningsDuringOpen $dbWarnings
	}

	pwsafe::int::randomizeVar hmac myHmac
	itcl::delete object $engine
	set engine ""
    }

    constructor {db_ source_} {
	set db $db_
	set source $source_
	set engine ""
	set used 0
    }

    destructor {
	if {$engine != ""} {
	    itcl::delete object $engine
	}
    }
}

#
# ----------------------------------------------------------------------
# pwsafe::v3::writer: writes to a stream
# ----------------------------------------------------------------------
#

catch {
    itcl::delete class pwsafe::v3::writer
}

itcl::class pwsafe::v3::writer {
    #
    # The object of type pwsafe::db to dump records from
    #

    protected variable db

    #
    # object to write data from, using its "write <numChars>" method
    #

    protected variable sink

    #
    # An object of type itwofish::cbc
    #

    protected variable engine

    #
    # The HMAC-SHA 256 engine
    #

    protected variable hmacEngine

    #
    # We can not be reused; complain if someone tries to
    #

    protected variable used

    #
    # Write one field
    #

    protected method writeField {fieldType fieldData} {
	#
	# First 16 byte block contains field length, type, and up to 16
	# bytes of data
	#

	set fieldDataLength [string length $fieldData]
	set data [binary format ic $fieldDataLength $fieldType]

	#
	# Append fieldData
	#

	append data $fieldData

	#
	# Pad to 16 bytes
	#

	set dataLength [expr {$fieldDataLength + 5}]

	if {($dataLength % 16) != 0} {
	    set padLength [expr {15-($dataLength % 16)}]
	    append data [string range [pwsafe::int::randomString 15] 0 $padLength]
	}

	#
	# Assert length
	#

	set l [string length $data]
	if {[expr {$l%16}] != 0} {
	    error [ mc "oops" ]
	}

	#
	# Encrypt data
	#

	set encryptedData [$engine encrypt $data]

	#
	# Write encrypted data
	#

	$sink write $encryptedData

	pwsafe::int::randomizeVar data encryptedData
    }

    protected method writeHeaderFields {} {
	#
	# Password Safe 3.01 requires that header fields 0 (version),
	# 1 (UUID) and 2 (non-default preferences) are all present, and
	# in exactly this order. Make sure to please it.
	#

	#
	# Version: 3.0
	#

	$db setHeaderField 0 [list 3 0]

	if {![$db hasHeaderField 1]} {
	    #
	    # Default dummy UUID. (Password Safe 3.01 ignores it. So do we.)
	    #
	    $db setHeaderField 1 00000000-0000-0000-0000-000000000000
	}

	#
	# No need to set field 2. There is always a preferences string.
	#

	#
	# Write header fields
	#

	foreach fieldType [$db getAllHeaderFields] {
	    set fieldValue [$db getHeaderField $fieldType]

	    switch -- $fieldType {
		0 {
		    #
		    # Version
		    #

		    set major [lindex $fieldValue 0]
		    set minor [lindex $fieldValue 1]
		    set fieldValue [binary format cc $minor $major]
		}
		1 {
		    #
		    # UUID
		    #

		    set fieldValue [string map {- {}} $fieldValue]
		    set fieldValue [binary format H* $fieldValue]
		}
	    }

	    writeField $fieldType $fieldValue
	    sha2::HMACUpdate $hmacEngine $fieldValue
	}

	#
	# End of header
	#

	writeField -1 ""
    }

    protected method writeAllFields {{percentvar ""}} {
	if {$percentvar != ""} {
	    upvar $percentvar pcv
	}

	#
	# Dump all records
	#

	set allRecords [$db getAllRecordNumbers]
	set numRecords [llength $allRecords]
	set countRecords 0

	foreach recordNumber $allRecords {
	    incr countRecords
	    set pcv [expr {100+(100*$countRecords/$numRecords)}]

	    foreach fieldType [$db getFieldsForRecord $recordNumber] {
		set fieldValue [$db getFieldValue $recordNumber $fieldType]
		set ignoreField 0

		switch -- $fieldType {
		    1 {
			#
			# UUID
			#

			set fieldValue [string map {- {}} $fieldValue]
			set fieldValue [binary format H* $fieldValue]
		    }
		    2 -
		    3 -
		    4 -
		    6 -
		    13 {
			#
			# Text fields are always stored in UTF-8
			#

			set fieldValue [encoding convertto utf-8 $fieldValue]

			if {$fieldValue == ""} {
			    set ignoreField 1
			}
		    }
		    5 {
			#
			# Notes field uses CRLF for line breaks, we want LF only.
			#

			set fieldValue [encoding convertto utf-8 $fieldValue]
			set fieldValue [string map {\n \r\n} $fieldValue]

			if {$fieldValue == ""} {
			    set ignoreField 1
			}
		    }
		    7 -
		    8 -
		    9 -
		    10 -
		    12 {
			#
			# (7) Creation Time, (8) Password Modification Time,
			# (9) Last Access Time, (10) Password Lifetime and
			# (11) Last Modification Time are of type time_t,
			# i.e., a 4 byte (little endian) integer
			#

			#
			# Make unsigned
			#

			set fieldValue [expr {($fieldValue + 0x100000000) % 0x100000000}]

			#
			# On Mac, we have to adjust for the different epoch
			#
			
			if {[info exists ::tcl_platform(platform)] && \
				[string equal $::tcl_platform(platform) "macintosh"]} {
			    incr fieldValue -2082844800
			}

			#
			# Make 32 bit, and encode to binary
			#

			set fieldValue [expr {$fieldValue & 0xffffffff}]
			set fieldValue [binary format i $fieldValue]
		    }
		}

		if {$ignoreField} {
		    continue
		}

		writeField $fieldType $fieldValue
		sha2::HMACUpdate $hmacEngine $fieldValue
		pwsafe::int::randomizeVar fieldType fieldValue
	    }

	    writeField -1 ""
	}
    }

    public method writeFile {{percentvar ""}} {
	if {$used} {
	    error [ mc "this object can not be reused" ]
	}

	set used 1

	if {$percentvar != ""} {
	    upvar $percentvar pcv
	    set pcvp "pcv"
	} else {
	    set pcvp ""
	}

	#
	# The file is laid out as follows:
	#
	# TAG|SALT|ITER|H(P')|B1|B2|B3|B4|IV|
	#
	# TAG is the sequence of 4 ASCII characters "PWS3"
	#
	# SALT is a 256 bit random value
	#
	# ITER is the number of iterations for the password stretching.
	#
	# P' is the "stretched key" H_<ITER>(Password,SALT)
	#
	# B1 and B2 are two 128-bit blocks encrypted with Twofish using
	# P' as the key, in ECB mode.
	#
	# B3 and B4 are two 128-bit blocks encrypted with Twofish using
	# P' as the key, in ECB mode.
	#
	# IV is the 128-bit random initial value for CBC mode.
	#

	set salt [pwsafe::int::randomString 32]
	set iter [$db cget -keyStretchingIterations]
	set skey [pwsafe::int::computeStretchedKey $salt [$db getPassword] $iter $pcvp ]
	set hskey [sha2::sha256 -bin $skey]

	$sink write "PWS3"
	$sink write $salt
	$sink write [binary format i $iter]
	$sink write $hskey

	#
	# The real key is encrypted using Twofish in ECB mode, using
	# the stretched passphrase as its key.
	#

	set hdrEngine [itwofish::ecb \#auto $skey]
	pwsafe::int::randomizeVar skey

	set k1 [pwsafe::int::randomString 16]
	set k2 [pwsafe::int::randomString 16]
	set h1 [pwsafe::int::randomString 16]
	set h2 [pwsafe::int::randomString 16]

	set b1 [$hdrEngine encryptBlock $k1]
	set b2 [$hdrEngine encryptBlock $k2]
	set b3 [$hdrEngine encryptBlock $h1]
	set b4 [$hdrEngine encryptBlock $h2]
	::itcl::delete object $hdrEngine

	$sink write $b1
	$sink write $b2
	$sink write $b3
	$sink write $b4

	set key $k1
	append key $k2

	set hmacKey $h1
	append hmacKey $h2

	pwsafe::int::randomizeVar k1 k2 h1 h2

	#
	# Create encryption engine
	#

	set iv [pwsafe::int::randomString 16]
	$sink write $iv

	set engine [itwofish::cbc \#auto $key $iv]
	set hmacEngine [sha2::HMACInit $hmacKey]
	pwsafe::int::randomizeVar iv key hmacKey

	#
	# Write data
	#

	writeHeaderFields
	writeAllFields $pcvp

	#
	# Write EOF marker
	#

	$sink write "PWS3-EOFPWS3-EOF"

	#
	# Write HMAC
	#

	$sink write [sha2::HMACFinal $hmacEngine]

	itcl::delete object $engine
	set engine ""
    }

    constructor {db_ sink_} {
	set db $db_
	set sink $sink_
	set engine ""
	set used 0
    }

    destructor {
	if {$engine != ""} {
	    itcl::delete object $engine
	}
    }
}

# tool for testing purposes!

proc hex { str } {
	binary scan $str H* hex
	return $hex			 
} 
