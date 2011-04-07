# all.tcl
#
# tcltest::runAllTests will look recursively for this file in each
# subdirectory
# ----------------------------------------------------------------------

package require tcltest 2.2

# default search path is the actual working directory
tcltest::configure -testdir [file dirname [file normalize [info script]]]

eval tcltest::configure $argv

tcltest::runAllTests
