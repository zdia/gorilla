
#
#   CriTcl - build C extensions on-the-fly
#
#   Copyright (c) 2001-2004 Jean-Claude Wippler
#   Copyright (c) 2002-2004 Steve Landers
#
#   See http://www.purl.org/tcl/wiki/critcl


namespace eval ::critcl {
  proc check args {}
  proc config args {}
  proc cheaders args {}
  proc csources args {}
  proc clibraries args {}
  proc cinit args {}
  proc ccode args {}
  proc ccommand args {}
  proc cproc args {}
  proc cdata args {}
  proc tk args {}
  proc tsources args {}
  proc cheaders args {}
  proc cdefines args {}
  proc done args {return 1}
  proc check args {return 0}

  proc loadlib {dir package version} {
    global tcl_platform
    set path [file join $dir [critcl::platform]]
    set lib [file join $path $package[info sharedlibextension]]
    set plat [file join $path critcl.tcl]
    set provide "package provide $package $version"
    append provide "; [list load $lib $package]; [list source $plat]"
    foreach t [glob -nocomplain [file join $dir Tcl *.tcl]] {
      append provide "; [list source $t]"
    }
    package ifneeded $package $version $provide
    package ifneeded critcl 0.0 "package provide critcl 0.0; [list source [file join $dir critcl.tcl]]"
  }

  proc platform {} {
        global tcl_platform
        set plat [lindex $tcl_platform(os) 0]
        set mach $tcl_platform(machine)
        switch -glob -- $mach {
            sun4* { set mach sparc }
            intel -
            i*86* { set mach x86 }
            "Power Macintosh" { set mach ppc }
        }
	switch -- $plat {
	  AIX   { set mach ppc }
	  HP-UX { set mach hppa }
	}
        return "$plat-$mach"
    }
}

