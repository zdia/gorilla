#
# ----------------------------------------------------------------------
# pwsafe::v2::reader: reads an existing file from a stream
# ----------------------------------------------------------------------
#

namespace eval pwsafe::v2 {}

catch {
    itcl::delete class pwsafe::v2::reader
}

itcl::class pwsafe::v2::reader {
    #
    # An object of type pwsafe::db, to read into
    #

    protected variable db

    #
    # object to read data from, using its "read <numChars>" method
    #

    protected variable source

    #
    # An object of type iblowfish::cbc
    #

    protected variable engine

    #
    # We can not be reused; complain if someone tries to
    #

    protected variable used

    #
    # read one field; returns [list type data]; or empty list on eof
    #

    protected method readField {} {
	#
	# first block contains field length and type
	#

	set encryptedLength [$source read 8]
	if {[string length $encryptedLength] == 0 && [$source eof]} {
	    return [list]
	}
	if {[string length $encryptedLength] != 8} {
	    error [ mc "less than 8 bytes remaining for length field" ]
	}
	set fixedEncryptedLength [pwsafe::int::genderbender $encryptedLength]
	set decryptedLength [$engine decrypt $fixedEncryptedLength]
	set fixedDecryptedLength [pwsafe::int::genderbender $decryptedLength]

	if {[binary scan $fixedDecryptedLength ic fieldLength fieldType] != 2} {
	    error [ mc "oops" ]
	}

	#
	# field length sanity check
	#

	if {$fieldLength < 0 || $fieldLength > 65536} {
	    error [ mc "field length %d looks insane" $fieldLength ]
	}

	#
	# data is padded to 8 bytes
	#

	set numBlocks [expr {($fieldLength + 7) / 8}]

	if {$numBlocks == 0} {
	    set numBlocks 1
	}

	set dataLength [expr {$numBlocks * 8}]

	#
	# decrypt field
	#

	set encryptedData [$source read $dataLength]

	if {[string length $encryptedData] != $dataLength} {
	    error [ mc "out of data" ]
	}

	set fixedEncryptedData [pwsafe::int::genderbender $encryptedData]
	set decryptedData [$engine decrypt $fixedEncryptedData]
	set fixedDecryptedData [pwsafe::int::genderbender $decryptedData]

	#
	# adjust length of data; truncate padding
	#

	set fieldData [string range $fixedDecryptedData 0 [expr {$fieldLength - 1}]]

	#
	# field decrypted successfully
	#

	pwsafe::int::randomizeVar decryptedData fixedDecryptedData
	return [list $fieldType $fieldData]
    }

    protected method readAllFields {{percentvar ""}} {
	if {$percentvar != ""} {
	    upvar $percentvar pcv
	}

	set fileSize [$source size]

	#
	# Format Description Block:
	#
	# Name: " !!!Version 2 File Format!!! " [...]
	# Password: "pre-2.0"
	# Notes: Used to store preferences
	#

	set nameField [readField]
	set passField [readField]
	set prefField [readField]

	#
	# Check if the nameField matches the expected magic. If not, then
	# this is likely a file in pre-2.0 format.
	#

	set v2magic [string range [lindex $nameField 1] 1 27]

	if {$v2magic != "!!!Version 2 File Format!!!"} {
	    #
	    # Version 1 file?
	    #

	    while {![$source eof]} {
		set filePos [$source tell]

		if {$filePos != -1 && $fileSize != -1 && \
			$fileSize != 0 && $filePos <= $fileSize} {
		    set percent [expr {100+(100*$filePos/$fileSize)}]
		} else {
		    set percent -1
		}

		set pcv $percent

		set recordnumber [$db createRecord]

		#
		# The name contains both the title and user name, separated by
		# "SPLTCHR" '\xad'. If the user name is "DEFUSERCHR" '\xa0', it
		# is supposed to be replaced by the default user name - which
		# we don't support yet.
		#
		# When Password Safe 2.x exports a file as 1.x, it prepends the
		# group name to the title. That seems too much of a borderline
		# case to support.
		#

		set titleAndUser [split [lindex $nameField 1] "\xad"]

		if {[llength $titleAndUser] == 1} {
		    $db setFieldValue $recordnumber 3 [lindex $titleAndUser 0]
		} elseif {[llength $titleAndUser] == 2} {
		    $db setFieldValue $recordnumber 3 [lindex $titleAndUser 0]
		    if {![string equal [lindex $titleAndUser 1] "\xa0"]} {
			$db setFieldValue $recordnumber 4 [lindex $titleAndUser 1]
		    }
		} else {
		    error [ mc "V1 name field looks suspect" ]
		}

		$db setFieldValue $recordnumber 6 [lindex $passField 1]
		$db setFieldValue $recordnumber 5 [lindex $prefField 1]

		pwsafe::int::randomizeVar titleAndUser nameField passField prefField

		set nameField [readField]
		if {[llength $nameField] == 0} {
		    # eof
		    break
		}

		set passField [readField]
		set prefField [readField]
	    }

	    return
	}

	#
	# Set preferences
	#

	$db setPreferencesFromString [lindex $prefField 1]

	#
	# Using UTF-8?
	#

	set isUTF8 [$db getPreference "IsUTF8"]
	
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
		set percent [expr {100.0*double($filePos)/double($fileSize)}]
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
		    # Text fields may be stored in UTF-8
		    #

		    if {$isUTF8} {
			set fieldValue [encoding convertfrom utf-8 $fieldValue]
		    }
		}
		5 {
		    #
		    # Notes field uses CRLF for line breaks, we want LF only.
		    #

		    if {$isUTF8} {
			set fieldValue [encoding convertfrom utf-8 $fieldValue]
		    }

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
	# RND|H(RND)|SALT|IP|
	#
	# RND is an 8 byte random value, used along with H(RND) to quickly
	# verify the password.
	#
	# SALT is the salt used for encrypting the data
	#
	# IP is the initial initialization vector value
	#

	set rnd [$source read 8]
	set hrnd [$source read 20]
	set salt [$source read 20]
	set ip [$source read 8]

	if {[string length $rnd] != 8 || \
		[string length $hrnd] != 20 || \
		[string length $salt] != 20 || \
		[string length $ip] != 8} {
	    pwsafe::int::randomizeVar rnd hrnd salt ip
	    error [ mc "end of file while reading header" ]
	}

	#
	# Verify the password
	#

	set myhrnd [pwsafe::int::computeHRND $rnd [$db getPassword]]
	if {![string equal $hrnd $myhrnd]} {
	    pwsafe::int::randomizeVar rnd salt ip myhrnd
	    error [ mc "wrong password" ]
	}

	pwsafe::int::randomizeVar rnd hrnd myhrnd

	#
	# the Blowfish key is SHA1(passphrase|salt)
	#

	set temp [$db getPassword]
	append temp $salt
	set key [pwsafe::int::sha1isz $temp]
	pwsafe::int::randomizeVar temp salt

	#
	# Create decryption engine using key and initialization vector
	#

	set engine [iblowfish::cbc \#auto $key [pwsafe::int::genderbender $ip]]
	pwsafe::int::randomizeVar key ip

	readAllFields $pcvp
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
# pwsafe::v2::writer: writes to a stream
# ----------------------------------------------------------------------
#

catch {
    itcl::delete class pwsafe::v2::writer
}

itcl::class pwsafe::v2::writer {
    #
    # The object of type pwsafe::db to dump records from
    #

    protected variable db

    #
    # object to write data from, using its "write <numChars>" method
    #

    protected variable sink

    #
    # An object of type iblowfish::cbc
    #

    protected variable engine

    #
    # We can not be reused; complain if someone tries to
    #

    protected variable used

    #
    # write one field
    #

    protected method writeField {fieldType fieldData} {
	#
	# first 8 byte block contains field length and type
	#

	set fieldDataLength [string length $fieldData]
	set data [binary format ic $fieldDataLength $fieldType]
	append data "\0\0\0"

	#
	# append fieldData
	#

	append data $fieldData

	#
	# pad to 8 bytes
	#

	if {$fieldDataLength == 0} {
	    # there must be at least one block of data
	    append data "\x00\x00\x00\x00\x00\x00\x00\x00"
	} elseif {[expr {$fieldDataLength % 8}] != 0} {
	    set padLength [expr {7-($fieldDataLength % 8)}]
	    append data [string range \
		    "\x00\x00\x00\x00\x00\x00\x00\x00" \
		    0 $padLength]
	}

	#
	# assert length
	#

	set l [string length $data]
	if {[expr {$l%8}] != 0} {
	    error [ mc "oops" ]
	}

	#
	# encrypt data
	#

	set swappedData [pwsafe::int::genderbender $data]
	set encryptedData [$engine encrypt $swappedData]
	set swappedEncryptedData [pwsafe::int::genderbender $encryptedData]

	#
	# write encrypted data
	#

	$sink write $swappedEncryptedData

	pwsafe::int::randomizeVar data swappedData encryptedData \
		swappedEncryptedData
    }

    protected method writeAllFields {{percentvar ""}} {
	if {$percentvar != ""} {
	    upvar $percentvar pcv
	}

	#
	# Format Description Block:
	#
	# Name: " !!!Version 2 File Format!!! " [...]
	# Password: "pre-2.0"
	# Notes: Used to store preferences
	#

	set magic " !!!Version 2 File Format!!! "
	append magic "Please upgrade to PasswordSafe 2.0"
	append magic " or later"

	writeField 0 $magic
	writeField 6 "2.0"
	writeField 5 [$db getPreferencesAsString]

	#
	# Using UTF-8?
	#

	set isUTF8 [$db getPreference "IsUTF8"]
	
	#
	# Dump all records
	#

	set allRecords [$db getAllRecordNumbers]
	set numRecords [llength $allRecords]
	set countRecords 0

	foreach recordNumber $allRecords {
	    incr countRecords
	    set pcv [expr {100.0*double($countRecords)/double($numRecords)}]

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
			# Text fields may be stored in UTF-8
			#

			if {$isUTF8} {
			    set fieldValue [encoding convertto utf-8 $fieldValue]
			}

			if {$fieldValue == ""} {
			    set ignoreField 1
			}
		    }
		    5 {
			#
			# Notes field uses CRLF for line breaks, we want LF only.
			#

			if {$isUTF8} {
			    set fieldValue [encoding convertto utf-8 $fieldValue]
			}

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
			
			if {[tk windowingsystem] == "aqua"} {
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
	# RND|H(RND)|SALT|IP|
	#
	# RND is an 8 byte random value, used along with H(RND) to quickly
	# verify the password.
	#
	# SALT is the salt used for encrypting the data
	#
	# IP is the initial initialization vector value
	#

	set rnd [pwsafe::int::randomString 8]
	set hrnd [pwsafe::int::computeHRND $rnd [$db getPassword]]
	set salt [pwsafe::int::randomString 20]
	set ip [pwsafe::int::randomString 8]

	$sink write $rnd
	$sink write $hrnd
	$sink write $salt
	$sink write $ip

	pwsafe::int::randomizeVar rnd hrnd
	
	#
	# the Blowfish key is SHA1(passphrase|salt)
	#

	set temp [$db getPassword]
	append temp $salt
	set key [pwsafe::int::sha1isz $temp]

	pwsafe::int::randomizeVar temp salt

	#
	# Create encryption engine using key and initialization vector
	#

	set engine [iblowfish::cbc \#auto $key [pwsafe::int::genderbender $ip]]
	pwsafe::int::randomizeVar key ip
	writeAllFields $pcvp
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

