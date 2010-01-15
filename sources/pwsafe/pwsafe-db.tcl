#
# ----------------------------------------------------------------------
# pwsafe::db: holds password records, and provides an API to them
# ----------------------------------------------------------------------
#

namespace eval pwsafe {}

catch {
    itcl::delete class pwsafe::db
}

itcl::class pwsafe::db {
    #
    # field types:
    #
    # Name                    Field Type    Value Type   Comments
    # -----------------------------------------------------------
    # UUID                        1         UUID
    # Group                       2         Text         [2]
    # Title                       3         Text
    # Username                    4         Text
    # Notes                       5         Text
    # Password                    6         Text
    # Creation Time               7         time_t
    # Password Modification Time  8         time_t
    # Last Access Time            9         time_t
    # Password Lifetime           10        time_t       [4]
    # Password Policy             11        4 bytes      [5]
    # Last Mod. time              12        time_t
    # URL                         13        Text
    # Autotype                    14        Text
    #
    # [2] The "Group" is meant to support displaying the entries in a
    # tree-like manner. Groups can be heirarchical, with elements separated
    # by a period, supporting groups such as "Finance.credit cards.Visa".
    # This implies that periods entered by the user will have a backslash
    # prepended to them. A backslash entered by the user will have another
    # backslash prepended.
    #
    # [4] Password lifetime is in seconds, and a value of zero means
    # "forever".
    #
    # [5] Unused so far
    #
    # Not all records use all fields. pwsafe-2.05 only seems to use the
    # UUID, Group, Title, Username, Nodes and Password fields. I have
    # omitted some documentation for the other fields.
    #
    # For more detail, look at the pwsafe documentation, or, better yet,
    # the pwsafe source code -- the documentation seems to be based on
    # a good helping of wishful thinking; e.g., it says that all Text
    # fields are Unicode, but they are not.
    #

    #
    # Preferences: {type number name registry-name default persistent}
    #
    # Need to keep in sync with pwsafe's corelib/PWSPrefs.cpp
    #

    protected common utf8Default 0
    protected common utf8PrefNumber 24

    protected common allPreferences {
	{B 0 AlwaysOnTop alwaysontop 0 1}
	{B 1 ShowPWDefault showpwdefault 0 1}
	{B 2 ShowPWInList showpwinlist 0 1}
	{B 3 SortAscending sortascending 1 1}
	{B 4 UseDefUser usedefuser 0 1}
	{B 5 SaveImmediately saveimmediately 0 1}
	{B 6 PWUseLowercase pwuselowercase 1 1}
	{B 7 PWUseUppercase pwuseuppercase 1 1}
	{B 8 PWUseDigits pwusedigits 1 1}
	{B 9 PWUseSymbols pwusesymbols 0 1}
	{B 10 PWUseHexDigits pwusehexdigits 0 1}
	{B 11 PWEasyVision pweasyvision 0 1}
	{B 12 DontAskQuestion dontaskquestion 0 1}
	{B 13 DeleteQuestion deletequestion 0 1}
	{B 14 DCShowsPassword DCShowsPassword 0 1}
	{B 15 DontAskMinimizeClearYesNo DontAskMinimizeClearYesNo 0 1}
	{B 16 DatabaseClear DatabaseClear 0 1}
	{B 17 DontAskSaveMinimize DontAskSaveMinimize 0 1}
	{B 18 QuerySetDef QuerySetDef 1 1}
	{B 19 UseNewToolbar UseNewToolbar 1 1}
	{B 20 UseSystemTray UseSystemTray 1 1}
	{B 21 LockOnWindowLock LockOnWindowLock 1 1}
	{B 22 LockOnIdleTimeout LockOnIdleTimeout 1 1}
	{B 23 EscExits EscExits 1 1}
	{B 24 IsUTF8 isutf8 0 1}
	{I 0 Column1Width column1width -1 0}
	{I 1 Column2Width column2width -1 0}
	{I 2 Column3Width column3width -1 0}
	{I 3 Column4Width column4width -1 0}
	{I 4 SortedColumn sortedcolumn 0 1}
	{I 5 PWLenDefault pwlendefault 8 1}
	{I 6 MaxMRUItems maxmruitems 4 1}
	{I 7 IdleTimeout IdleTimeout 5 1}
	{S 0 CurrentBackup currentbackup "" 1}
	{S 1 CurrentFile currentfile "" 0}
	{S 2 LastView lastview "list" 1}
	{S 3 DefUserName defusername "" 1}
    }

    #
    # Internal data:
    #
    # header is an array, the index is <type>
    #
    # records is an array, the index is <record number>,<type>
    #
    # Record number and type are both integers. The type has the value
    # of the type byte, as identified in the pwsafe "documentation."
    # The value of the array element is the field value.
    #
    # recordnumbers is a list of all record numbers that are available
    # in the records array
    #

    protected variable engine
    protected variable password
    protected variable header
    protected variable preferences
    protected variable records
    protected variable recordnumbers
    protected variable nextrecordnumber

    #
    # The number of iterations for the key-stretching algorithm in the
    # V3 format.
    #

    public variable keyStretchingIterations

    #
    # Warnings during opening the file.
    #

    public variable warningsDuringOpen

    #
    # constructor
    #

    constructor {password_} {
	set nextrecordnumber 0
	set recordnumbers [list]
	set engine [namespace current]::[itwofish::ecb #auto \
		[pwsafe::int::randomString 16]]
	set password [encryptField $password_]
	array set preferences {}
	array set header {}
	set keyStretchingIterations 2048
	set warningsDuringOpen [list]
    }

    #
    # Encrypt a field, so that we don't store anything in cleartext
    #

    private method encryptField {data} {
	set dataLen [string length $data]
	set msg [pwsafe::int::randomString 4]
	append msg [binary format I $dataLen]
	append msg $data
	incr dataLen 8
	if {($dataLen % 16) != 0} {
	    set padLen [expr {16-($dataLen%16)}]
	    append msg [pwsafe::int::randomString $padLen]
	    incr dataLen $padLen
	}
	set blocks [expr {$dataLen/16}]
	set encryptedMsg ""
	for {set i 0} {$i < $blocks} {incr i} {
	    append encryptedMsg [$engine encryptBlock \
		    [string range $msg [expr {16*$i}] [expr {16*$i+15}]]]
	}
	pwsafe::int::randomizeVar msg
	return $encryptedMsg
    }

    private method decryptField {encryptedMsg} {
	set eml [string length $encryptedMsg]
	set blocks [expr {$eml/16}]
	set decryptedMsg ""
	for {set i 0} {$i < $blocks} {incr i} {
	    append decryptedMsg [$engine decryptBlock \
		    [string range $encryptedMsg [expr {16*$i}] [expr {16*$i+15}]]]
	}
	binary scan $decryptedMsg @4I msgLen
	set res [string range $decryptedMsg 8 [expr {7+$msgLen}]]
	pwsafe::int::randomizeVar decryptedMsg
	return $res
    }

    #
    # Accessors for our data members
    #

    public method getPassword {} {
	return [decryptField $password]
    }

    public method checkPassword {oldPassword} {
	if {![string equal $oldPassword [decryptField $password]]} {
	    return 0
	}
	return 1
    }

    public method setPassword {newPassword} {
	set password [encryptField $newPassword]
    }

    #
    # Manage preferences
    #

    public method getPreferencesAsString {} {
	set result ""
	set isUTF8 [getPreference "IsUTF8"]

	for {set index 0} {$index < [llength $allPreferences]} {incr index} {
	    set prefItem [lindex $allPreferences $index]

	    if {![lindex $prefItem 5]} {
		# not persistent
		continue
	    }

	    set prefType [lindex $prefItem 0]
	    set prefNumber [lindex $prefItem 1]
	    set prefDefault [lindex $prefItem 4]

	    if {[info exists preferences($prefType,$prefNumber)]} {
		set prefValue $preferences($prefType,$prefNumber)

		if {[string length $result] > 0} {
		    append result " "
		}
		append result $prefType " " $prefNumber " "
		if {$prefType == "B" || $prefType == "I"} {
		    append result $prefValue
		} else {
		    if {$isUTF8} {
			set prefValue [encoding convertto utf-8 $prefValue]
		    }
		    append result "\"" [string map {\\ \\\\ \" \\\"} \
			    $prefValue] "\""
		}
	    }
	}

	return $result
    }

    public method setPreferencesFromString {newPreferences} {
	#
	# String is of the form "X nn vv X nn vv..." Where X=[BIS]
	# for binary, integer and string, resp., nn is the numeric
	# value of the enum, and vv is the value, {1.0} for bool,
	# unsigned integer for int, and quoted string for String.
	# Only values != default are stored.
	#

	set isUTF8 [getPreference "IsUTF8"]

	set i 0
	while {$i < [string length $newPreferences]} {
	    set prefType [string index $newPreferences $i]
	    if {[string is space $prefType]} {
		incr i
		continue
	    }

	    if {$prefType != "B" && $prefType != "I" && \
		    $prefType != "S"} {
		error "unknown preference type: $prefType"
	    }

	    #
	    # Space between preference type and preference number
	    #

	    incr i
	    while {$i < [string length $newPreferences] && \
		    [string is space [string index $newPreferences $i]]} {
		incr i
	    }

	    #
	    # Preference number
	    #

	    set prefNumberString ""
	    while {$i < [string length $newPreferences] && \
		    [string is digit [string index $newPreferences $i]]} {
		append prefNumberString [string index $newPreferences $i]
		incr i
	    }

	    if {$i >= [string length $newPreferences]} {
		error "premature end of preference"
	    }

	    if {[scan $prefNumberString "%d" prefNumber] != 1} {
		error "expected preference number, got $prefNumberString"
	    }

	    #
	    # Space between preference number and preference value
	    #

	    while {$i < [string length $newPreferences] && \
		    [string is space [string index $newPreferences $i]]} {
		incr i
	    }

	    #
	    # Preference value
	    #

	    if {$prefType == "B" || $prefType == "I"} {
		set prefValString ""
		while {$i < [string length $newPreferences] && \
			[string is digit [string index $newPreferences $i]]} {
		    append prefValString [string index $newPreferences $i]
		    incr i
		}
		if {[scan $prefValString "%d" prefValue] != 1} {
		    error "expected number for value, got $prefValString"
		}
	    } elseif {$prefType == "S"} {
		if {[string index $newPreferences $i] != "\""} {
		    error "expected initial quote for string value"
		}
		incr i
		set prefValue ""
		while {$i < [string length $newPreferences]} {
		    set c [string index $newPreferences $i]
		    if {$c == "\\"} {
			append prefValue [string index $newPreferences [incr i]]
		    } elseif {$c == "\""} {
			break
		    } else {
			append prefValue $c
		    }
		    incr i
		}
		if {$i >= [string length $newPreferences]} {
		    error "premature end of string value"
		}
		incr i

		if {$isUTF8} {
		    set prefValue [encoding convertfrom utf-8 $prefValue]
		}
	    }

	    if {$prefType == "B" && $prefNumber == $utf8PrefNumber} {
		set isUTF8 $prefValue
	    }

	    set preferences($prefType,$prefNumber) $prefValue
	}
    }

    #
    # Get/set named preferences
    #

    public method existsPreference {name} {
	for {set index 0} {$index < [llength $allPreferences]} {incr index} {
	    set prefItem [lindex $allPreferences $index]
	    set prefType [lindex $prefItem 0]
	    set prefNumber [lindex $prefItem 1]
	    set prefName [lindex $prefItem 2]

	    if {[string equal $prefName $name]} {
		if {[info exists preferences($prefType,$prefNumber)]} {
		    return 1
		} else {
		    return 0
		}
	    }
	}
	error "no such preference: $name"
    }

    public method getPreference {name} {
	for {set index 0} {$index < [llength $allPreferences]} {incr index} {
	    set prefItem [lindex $allPreferences $index]
	    set prefType [lindex $prefItem 0]
	    set prefNumber [lindex $prefItem 1]
	    set prefName [lindex $prefItem 2]

	    if {[string equal $prefName $name]} {
		if {[info exists preferences($prefType,$prefNumber)]} {
		    return $preferences($prefType,$prefNumber)
		} else {
		    return [lindex $prefItem 4]
		}
	    }
	}
	error "no such preference: $name"
    }

    public method setPreference {name value} {
	for {set index 0} {$index < [llength $allPreferences]} {incr index} {
	    set prefItem [lindex $allPreferences $index]
	    set prefType [lindex $prefItem 0]
	    set prefNumber [lindex $prefItem 1]
	    set prefName [lindex $prefItem 2]

	    if {[string equal $prefName $name]} {
		if {$value != [lindex $prefItem 4]} {
		    set preferences($prefType,$prefNumber) $value
		} elseif {[info exists preferences($prefType,$prefNumber)]} {
		    unset preferences($prefType,$prefNumber)
		}
		return
	    }
	}
	error "no such preference: $name"
    }

    #
    # Helper: split a hierarchical group name into its components
    #

    public proc splitGroup {group} {
	#
	# Elements are separated by a period. When a group name contains
	# a period, it is escaped by a backslash. For that to work, a
	# backslash is also escaped, i.e., group "\." becomes "\\\.".
	#
	# If the hierarchical name does not contain any slashes, we can
	# simply use split.
	#

	if {[string first "\\" $group] == -1} {
	    set result [split $group .]
	    foreach element $result {
		if {$element == ""} {
		    error "group name can not be empty"
		}
	    }
	    return $result
	}

	#
	# Have to parse ...
	#

	set result [list]
	set element ""

	for {set index 0} {$index < [string length $group]} {incr index} {
	    set c [string index $group $index]
	    if {$c == "\\"} {
		append element [string index $group [incr index]]
	    } elseif {$c == "."} {
		if {$element == ""} {
		    error "group name can not be empty"
		}
		lappend result $element
		set element ""
	    } else {
		append element $c
	    }
	}

	if {$element == ""} {
	    error "group name can not be empty"
	}

	lappend result $element
	return $result
    }

    #
    # Helper: concatenate a list of groups into a hierarchical name
    #

    public proc concatGroups {groups} {
	set result ""
	set index 0
	foreach element $groups {
	    if {$index > 0} {
		append result "."
	    }
	    if {$element == ""} {
		error "group name can not be empty"
	    }
	    append result [string map {\\ \\\\ . \\.} $element]
	    incr index
	}
	return $result
    }

    #
    # Reserve a recordnumber
    #

    public method createRecord {} {
	set nn [incr nextrecordnumber]
	lappend recordnumbers $nn
	return $nn
    }

    #
    # Delete a record
    #

    public method deleteRecord {rn} {
	set index [lsearch -exact -integer $recordnumbers $rn]
	if {$index != -1} {
	    set recordnumbers [lreplace $recordnumbers $index $index]
	    array unset records $rn,*
	}
    }

    #
    # Does a specific record number exist?
    #

    public method existsRecord {rn} {
	if {[lsearch -exact -integer $recordnumbers $rn] == -1} {
	    return 0
	}
	return 1
    }

    #
    # Get all record numbers
    #

    public method getAllRecordNumbers {} {
	return [lsort -integer $recordnumbers]
    }

    #
    # Does a specific record have a specific field
    #

    public method existsField {rn field} {
	if {![info exists records($rn,$field)]} {
	    if {![existsRecord $rn]} {
		error "record $rn does not exist"
	    }
	    return 0
	}
	return 1
    }

    #
    # Get a list of all fields that are available for a record
    #
    
    public method getFieldsForRecord {rn} {
	set names [array names records -glob $rn,*]
	if {[llength $names] == 0} {
	    error "record $rn does not exist"
	}
	set result [list]
	foreach name $names {
	    lappend result [lindex [split $name ,] 1]
	}
	return [lsort -integer $result]
    }

    #
    # Get the value of a field
    #
    
    public method getFieldValue {rn field} {
	if {![info exists records($rn,$field)]} {
	    if {![existsRecord $rn]} {
		error "record $rn does not exist"
	    }
	    error "record $rn does not have field $field"
	}

	if {$field == 2 || $field == 3 || $field == 4 || \
		$field == 5 || $field == 6} {
	    # text fields
	    return [encoding convertfrom utf-8 \
			[decryptField $records($rn,$field)]]
	}
	    
	return [decryptField $records($rn,$field)]
    }

    #
    # Set the value of a field
    #

    public method setFieldValue {rn field value} {
	if {![existsRecord $rn]} {
	    error "record $rn does not exist"
	}

	if {$field == 2 || $field == 3 || $field == 4 || \
		$field == 5 || $field == 6} {
	    # text fields
	    set records($rn,$field) [encryptField \
					 [encoding convertto utf-8 $value]]
	} else {
	    set records($rn,$field) [encryptField $value]
	}
    }

    #
    # Unset the value of a field. Deletes the record if this was the
    # last field.
    #

    public method unsetFieldValue {rn field} {
	if {![existsRecord $rn]} {
	    return
	}
	if {[info exists records($rn,$field)]} {
	    pwsafe::int::randomizeVar records($rn,$field)
	    unset records($rn,$field)
	    if {[llength [getFieldsForRecord $rn]] == 0} {
		deleteRecord $rn
	    }
	}
    }

    #
    # Get the value of a header field
    #

    public method hasHeaderField {field} {
	if {$field == 2} {
	    return 1
	}
	return [info exists header($field)]
    }

    public method getHeaderField {field} {
	if {$field == 2} {
	    #
	    # Preferences
	    #

	    return [getPreferencesAsString]
	}

	if {![info exists header($field)]} {
	    error "no header field $field"
	}

	return $header($field)
    }

    #
    # Set the value of a header field
    #

    public method setHeaderField {field value} {
	if {$field == 2} {
	    #
	    # Preferences
	    #

	    setPreferencesFromString $value
	    return
	}

	set header($field) $value
    }

    #
    # Get all header field types
    #

    public method getAllHeaderFields {} {
	set fields [array names header]

	if {![info exists header(2)]} {
	    #
	    # There is always a preferences field.
	    #

	    lappend fields 2
	}

	return [lsort -integer $fields]
    }
}
