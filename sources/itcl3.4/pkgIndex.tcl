# Tcl package index file, version 1.0
# modified for multiplatform use

package require Tcl 8.5

set lib libitcl3.4
if { $::tcl_platform(platform) eq "windows" } { set lib itcl34 }

set ::env(ITCL_LIBRARY) $dir
package ifneeded Itcl 3.4 [list load [file join $dir "$lib[info sharedlibextension]"] Itcl]
