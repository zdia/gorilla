# Tcl package index file, version 1.0

set ::env(ITCL_LIBRARY) $dir
package ifneeded Itcl 3.4 [list load [file join $dir "libitcl3.4.dylib"] Itcl]
