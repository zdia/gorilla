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
	{B 25 HotKeyEnabled hotkeyenabled false 00}
	{B 26 MRUOnFileMenu mruonfilemenu true 00}
	{B 27 DisplayExpandedAddEditDlg displayexpandedaddeditdlg true 0}
	{B 28 MaintainDateTimeStamps maintaindatetimestamps false 1}
	{B 29 SavePasswordHistory savepasswordhistory false 1}
	{B 30 FindWraps findwraps false 0}
	{B 31 ShowNotesDefault shownotesdefault false 1}
	{B 32 BackupBeforeEverySave backupbeforeeverysave true 00}
	{B 33 PreExpiryWarn preexpirywarn false 00}
	{B 34 ExplorerTypeTree explorertypetree false 00}
	{B 35 ListViewGridLines listviewgridlines false 00}
	{B 36 MinimizeOnAutotype minimizeonautotype true 00}
	{B 37 ShowUsernameInTree showusernameintree true 1}
	{B 38 PWMakePronounceable pwmakepronounceable false 1}
	{B 39 ClearClipoardOnMinimize clearclipoardonminimize true 0}
	{B 40 ClearClipoardOneExit clearclipoardoneexit true 0}
	{B 41 ShowToolbar showtoolbar true 00}
	{B 42 ShowNotesAsToolTipsInViews shownotesastooltipsinviews false 00}
	{B 43 DefaultOpenRO defaultopenro false 00}
	{B 44 MultipleInstances multipleinstances true 00}
	{B 45 ShowDragbar showdragbar true 00}
	{B 46 ClearClipboardOnMinimize clearclipboardonminimize true 00}
	{B 47 ClearClipboardOnExit clearclipboardonexit true 00}
	{B 48 ShowFindToolBarOnOpen showfindtoolbaronopen false 00}
	{B 49 NotesWordWrap noteswordwrap false 00}
	{B 50 LockDBOnIdleTimeout lockdbonidletimeout true 1}
	{B 51 HighlightChanges highlightchanges true 00}
	{B 52 HideSystemTray hidesystemtray false 00}
	{B 53 UsePrimarySelectionForClipboard useprimaryselectionforclipboard false 00}
	{B 54 CopyPasswordWhenBrowseToURL copypasswordwhenbrowsetourl true 1}
                                                            
	{I 0 Column1Width column1width -1 0}
	{I 1 Column2Width column2width -1 0}
	{I 2 Column3Width column3width -1 0}
	{I 3 Column4Width column4width -1 0}
	{I 4 SortedColumn sortedcolumn 0 1}
	{I 5 PWLenDefault pwlendefault 8 1}
	{I 6 MaxMRUItems maxmruitems 4 1}
	{I 7 IdleTimeout IdleTimeout 5 1}
	{I 8 DoubleClickAction doubleclickaction 0 1}
	{I 9 HotKey hotkey 0 1}
	{I 10 MaxREItems maxreitems 25 1}
	{I 11 TreeDisplayStatusAtOpen treedisplaystatusatopen 0 1}
	{I 12 NumPWHistoryDefault numpwhistorydefault 3 1}
	{I 13 BackupSuffix backupsuffix 0 1}
	{I 14 BackupMaxIncremented backupmaxincremented 3 1}
	{I 15 PreExpiryWarnDays preexpirywarndays 1 1}
	{I 16 ClosedTrayIconColour closedtrayiconcolour 0 1}
	{I 17 PWDigitMinLength pwdigitminlength 0 1}
	{I 18 PWLowercaseMinLength pwlowercaseminlength 0 1}
	{I 19 PWSymbolMinLength pwsymbolminlength 0 1}
	{I 20 PWUppercaseMinLength pwuppercaseminlength 0 1}
	{I 21 OptShortcutColumnWidth optshortcutcolumnwidth 92 1}
	{I 22 ShiftDoubleClickAction shiftdoubleclickaction 0 1}
                             
	{S 0 CurrentBackup currentbackup "" 1}
	{S 1 CurrentFile currentfile "" 0}
	{S 2 LastView lastview "list" 1}
	{S 3 DefUserName defusername "" 1}
	{S 4 treefont treefont "" 00}
	{S 5 BackupPrefixValue backupprefixvalue "" 00}
	{S 6 BackupDir backupdir "" 00}
	{S 7 AltBrowser altbrowser "" 00}
	{S 8 ListColumns listcolumns "" 00}
	{S 9 ColumnWidths columnwidths "" 00}
	{S 10 DefaultAutotypeString  defaultautotypestring "" 1}
	{S 11 AltBrowserCmdLineParms altbrowsercmdlineparms "" 00}
	{S 12 MainToolBarButtons maintoolbarbuttons "" 00}
	{S 13 PasswordFont passwordfont "" 00}
	{S 14 TreeListSampleText treelistsampletext "AaBbYyZz 0O1IlL" 00}
	{S 15 PswdSampleText pswdsampletext "AaBbYyZz 0O1IlL" 00}
	{S 16 LastUsedKeyboard lastusedkeyboard "" 00}
	{S 17 VKeyboardFontName vkeyboardfontname "" 00}
	{S 18 VKSampleText vksampletext "AaBbYyZz 0O1IlL" 00}
	{S 19 AltNotesEditor altnoteseditor "" 00}
	{S 20 LanguageFile languagefile "" 00}
	{S 21 DefaultSymbols defaultsymbols "" 1}

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

		    # find a suitable quote character for the string preference -
		    # footnote [3] in section 3.2 of the password safe V3 file format
		    # documentation states:
		    #
		    # "Note: normally strings are delimited by the doublequote
		    # character.  However, if this character is in the string value, an
		    # arbitrary character will be chosen to delimit the string."
		    
		    set delim \"
		    # 34 is " in ascii/utf-8
		    # 35 is # in ascii/utf-8 - the next char after "
		    set ascii 35
		    while { ( -1 != [ string first $delim $prefValue ] )
		         && ( $ascii != 34 ) } {
		         set delim [ format %c $ascii ]
		         set ascii [ expr { ($ascii + 1) % 256 } ]
                    }
                    if { $ascii == 34 } {
                        error [ mc "Unable to find unused character with which to quote preference string.\nNormally this should not happen." ]
                    }
		    append result $delim $prefValue $delim 
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
		error [ mc "unknown preference type: %s" $prefType ]
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
		error [ mc "premature end of preference" ]
	    }

	    if {[scan $prefNumberString "%d" prefNumber] != 1} {
		error [ "expected preference number, got %s" $prefNumberString ]
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
		    error [ mc "expected number for value, got %s" $prefValString ]
		}
	    } elseif {$prefType == "S"} {
		# V2 format files use " as string delimiter
		# V3 format files use an arbitrary character (typically dblquote)
		set delim [string index $newPreferences $i]
		incr i
		if { -1 == [ set endi [ string first $delim $newPreferences $i ] ] } {
		  error [ mc "end delimiter '%s' not found in saved DB preference" $delim ]
		}
		set prefValue [ string range $newPreferences $i $endi-1 ]
		set i $endi
		if {$i >= [string length $newPreferences]} {
		    error [ mc "premature end of string value" ]
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

    } ; # end setPreferencesFromString

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
	error [ mc "no such preference: %s" $name ]
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
	error [ mc "no such preference: %s" $name ]
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
	error [ mc "no such preference: %s" $name ]
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
		    error [ mc "group name can not be empty" ]
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
		    error [ mc "group name can not be empty" ]
		}
		lappend result $element
		set element ""
	    } else {
		append element $c
	    }
	}

	if {$element == ""} {
	    error [ mc "group name can not be empty" ]
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
		error [ mc "group name can not be empty" ]
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
		error [ mc "record %d does not exist" $rn ]
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
	    error [ mc "record %d does not exist" $rn ]
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
		error [ mc "record %d does not exist" $rn ]
	    }
	    error [ mc "record %d does not have field %s" $rn $field ]
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
	    error [ mc "record %d does not exist" $rn ]
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
	    error [ mc "no header field %s" $field ]
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
