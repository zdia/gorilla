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
tcltest::singleProcess 1
tcltest::skipDirectories [tcltest::workingDirectory]
tcltest::match *.test

set argv {}
eval tcltest::configure $argv

# If a file named all.tcl is found in a subdirectory of the scanned
# test directory, it will be sourced in the caller's context.

tcltest::runAllTests
