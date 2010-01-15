if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded sha256 1.0.1 [list source [file join $dir sha256.tcl]]
