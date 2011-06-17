# RunAllTests.tcl
#
# This is the master script to run all of the tests of the password manager
# Password Gorilla
#
# Use:
# bash: 	tkcon gorilla.tcl --tcltest
# tkcon: 	cd ../unit-tests
# 				source RunAllTests.tcl
# 
# Versions tested:
# 1.5.3.5 pre-release
# ----------------------------------------------------------------------

package require tcltest 2.2

# default search path is the actual working directory
tcltest::workingDirectory [file dirname [file normalize [info script]]]
tcltest::singleProcess 1	;# caller environment will be used
tcltest::verbose { pass }

# set testFolderList [list csv-import csv-export merge lock-database]
set testFolderList [ list csv-import csv-export lock-database backup ]

foreach testFolder $testFolderList {
	cd [file join [tcltest::workingDirectory] $testFolder]
	set testList [glob *.test]
	foreach testFile $testList {
		source $testFile
	}
	cd ..
}

tcltest::cleanupTests	;# will give the results and exit 
