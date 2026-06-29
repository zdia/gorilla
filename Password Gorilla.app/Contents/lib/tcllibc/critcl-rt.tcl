#
#   Critcl - build C extensions on-the-fly
#
#   Copyright (c) 2001-2007 Jean-Claude Wippler
#   Copyright (c) 2002-2007 Steve Landers
#
#   See http://wiki.tcl.tk/critcl
#
#   This is the Critcl runtime that loads the appropriate
#   shared library when a package is requested
#

namespace eval ::critcl::runtime {}

proc ::critcl::runtime::loadlib {dir package version libname initfun tsrc mapping args} {
    # XXX At least parts of this can be done by the package generator,
    # XXX like listing the Tcl files to source. The glob here allows
    # XXX code-injection after-the-fact, by simply adding a .tcl in
    # XXX the proper place.
    set path [file join $dir [MapPlatform $mapping]]
    set ext [info sharedlibextension]
    set lib [file join $path $libname$ext]
    set provide [list]

    # Now the runtime equivalent of a series of 'preFetch' commands.
    if {[llength $args]} {
	set preload [file join $path preload$ext]
	foreach p $args {
	    set prelib [file join $path $p$ext]
	    if {[file readable $preload] && [file readable $prelib]} {
		lappend provide [list load $preload];# XXX Move this out of the loop, do only once.
		lappend provide [list ::critcl::runtime::preload $prelib]
	    }
	}
    }

    lappend provide [list load $lib $initfun]
    foreach t $tsrc {
	lappend loadcmd "::critcl::runtime::Fetch \$dir [list $t]"
    }
    lappend provide "package provide $package $version"
    package ifneeded $package $version [join $provide "\n"]
    return
}

proc ::critcl::runtime::preFetch {path ext dll} {
    set preload [file join $path preload$ext]
    if {![file readable $preload]} return

    set prelib [file join $path $dll$ext]
    if {![file readable $prelib]} return

    load $preload ; # Defines next command.
    ::critcl::runtime::preload $prelib
    return
}

proc ::critcl::runtime::Fetch {dir t} {
    # The 'Ignore' disables compile & run functionality.

    # Background: If the regular critcl package is already loaded, and
    # this prebuilt package uses its defining .tcl file also as a
    # 'tsources' then critcl might try to collect data and build it
    # because of the calls to its API, despite the necessary binaries
    # already being present, just not in the critcl cache. That is
    # redundant in the best case, and fails in the worst case (no
    # compiler), preventing the use o a perfectly fine package. The
    # 'ignore' call now tells critcl that it should ignore any calls
    # made to it by the sourced files, and thus avoids that trouble.

    # The other case, the regular critcl package getting loaded after
    # this prebuilt package is irrelevant. At that point the tsources
    # were already run, and used the dummy procedures defined in the
    # critcl-rt.tcl, which ignore the calls by definition.

    set t [file join $dir tcl $t]
    ::critcl::Ignore $t
    uplevel #0 [list source $t]
    return
}

proc ::critcl::runtime::precopy {dll} {
    # This command is only used on Windows when preloading out of a
    # VFS that doesn't support direct loading (usually, a Starkit)
    #   - we preserve the dll name so that dependencies are satisfied
    #	- The critcl::runtime::preload command is defined in the supporting
    #     "preload" package, implemented in "critcl/lib/critcl/critcl_c/preload.c"

    global env
    if {[info exists env(TEMP)]} {
	set dir $env(TEMP)
    } elseif {[info exists env(TMP)]} {
	set dir $env(TMP)
    } elseif {[file exists $env(HOME)]} {
	set dir $env(HOME)
    } else {
	set dir .
    }
    set dir [file join $dir TCL[pid]]
    set i 0
    while {[file exists $dir]} {
	append dir [incr i]
    }
    set new [file join $dir [file tail $dll]]
    file mkdir $dir
    file copy $dll $new
    return $new
}

proc ::critcl::runtime::MapPlatform {{mapping {}}} {
    # A sibling of critcl::platform that applies the platform mapping

    set platform [::platform::generic]
    set version $::tcl_platform(osVersion)
    if {[string match "macosx-*" $platform]} {
	# "normalize" the osVersion to match OSX release numbers
	set v [split $version .]
	set v1 [lindex $v 0]
	set v2 [lindex $v 1]
	incr v1 -4
	set version 10.$v1.$v2
    } else {
	# Strip trailing non-version info
	regsub -- {-.*$} $version {} version
    }
    foreach {config map} $mapping {
	if {![string match $config $platform]} continue
	set minver [lindex $map 1]
	if {[package vcompare $version $minver] < 0} continue
	set platform [lindex $map 0]
	break
    }
    return $platform
}

# Dummy implementation of the critcl package, if not present
if {![llength [info commands ::critcl::Ignore]]} {
    namespace eval ::critcl {}
    proc ::critcl::Ignore {args} {
		namespace eval ::critcl::v {}
		set ::critcl::v::ignore([file normalize [lindex $args 0]]) .
	    }
}
if {![llength [info commands ::critcl::api]]} {
    namespace eval ::critcl {}
    proc ::critcl::api {args} {}
}
if {![llength [info commands ::critcl::at]]} {
    namespace eval ::critcl {}
    proc ::critcl::at {args} {}
}
if {![llength [info commands ::critcl::cache]]} {
    namespace eval ::critcl {}
    proc ::critcl::cache {args} {}
}
if {![llength [info commands ::critcl::ccode]]} {
    namespace eval ::critcl {}
    proc ::critcl::ccode {args} {}
}
if {![llength [info commands ::critcl::ccommand]]} {
    namespace eval ::critcl {}
    proc ::critcl::ccommand {args} {}
}
if {![llength [info commands ::critcl::cdata]]} {
    namespace eval ::critcl {}
    proc ::critcl::cdata {args} {}
}
if {![llength [info commands ::critcl::cdefines]]} {
    namespace eval ::critcl {}
    proc ::critcl::cdefines {args} {}
}
if {![llength [info commands ::critcl::cflags]]} {
    namespace eval ::critcl {}
    proc ::critcl::cflags {args} {}
}
if {![llength [info commands ::critcl::cheaders]]} {
    namespace eval ::critcl {}
    proc ::critcl::cheaders {args} {}
}
if {![llength [info commands ::critcl::check]]} {
    namespace eval ::critcl {}
    proc ::critcl::check {args} {return 0}
}
if {![llength [info commands ::critcl::cinit]]} {
    namespace eval ::critcl {}
    proc ::critcl::cinit {args} {}
}
if {![llength [info commands ::critcl::clibraries]]} {
    namespace eval ::critcl {}
    proc ::critcl::clibraries {args} {}
}
if {![llength [info commands ::critcl::compiled]]} {
    namespace eval ::critcl {}
    proc ::critcl::compiled {args} {return 1}
}
if {![llength [info commands ::critcl::compiling]]} {
    namespace eval ::critcl {}
    proc ::critcl::compiling {args} {return 0}
}
if {![llength [info commands ::critcl::config]]} {
    namespace eval ::critcl {}
    proc ::critcl::config {args} {}
}
if {![llength [info commands ::critcl::cproc]]} {
    namespace eval ::critcl {}
    proc ::critcl::cproc {args} {}
}
if {![llength [info commands ::critcl::csources]]} {
    namespace eval ::critcl {}
    proc ::critcl::csources {args} {}
}
if {![llength [info commands ::critcl::debug]]} {
    namespace eval ::critcl {}
    proc ::critcl::debug {args} {}
}
if {![llength [info commands ::critcl::done]]} {
    namespace eval ::critcl {}
    proc ::critcl::done {args} {return 1}
}
if {![llength [info commands ::critcl::failed]]} {
    namespace eval ::critcl {}
    proc ::critcl::failed {args} {return 0}
}
if {![llength [info commands ::critcl::framework]]} {
    namespace eval ::critcl {}
    proc ::critcl::framework {args} {}
}
if {![llength [info commands ::critcl::include]]} {
    namespace eval ::critcl {}
    proc ::critcl::include {args} {}
}
if {![llength [info commands ::critcl::ldflags]]} {
    namespace eval ::critcl {}
    proc ::critcl::ldflags {args} {}
}
if {![llength [info commands ::critcl::license]]} {
    namespace eval ::critcl {}
    proc ::critcl::license {args} {}
}
if {![llength [info commands ::critcl::load]]} {
    namespace eval ::critcl {}
    proc ::critcl::load {args} {return 1}
}
if {![llength [info commands ::critcl::make]]} {
    namespace eval ::critcl {}
    proc ::critcl::make {args} {}
}
if {![llength [info commands ::critcl::meta]]} {
    namespace eval ::critcl {}
    proc ::critcl::meta {args} {}
}
if {![llength [info commands ::critcl::platform]]} {
    namespace eval ::critcl {}
    proc ::critcl::platform {args} {}
}
if {![llength [info commands ::critcl::preload]]} {
    namespace eval ::critcl {}
    proc ::critcl::preload {args} {}
}
if {![llength [info commands ::critcl::source]]} {
    namespace eval ::critcl {}
    proc ::critcl::source {args} {}
}
if {![llength [info commands ::critcl::tcl]]} {
    namespace eval ::critcl {}
    proc ::critcl::tcl {args} {}
}
if {![llength [info commands ::critcl::tk]]} {
    namespace eval ::critcl {}
    proc ::critcl::tk {args} {}
}
if {![llength [info commands ::critcl::tsources]]} {
    namespace eval ::critcl {}
    proc ::critcl::tsources {args} {}
}
if {![llength [info commands ::critcl::userconfig]]} {
    namespace eval ::critcl {}
    proc ::critcl::userconfig {args} {}
}

# Define a clone of platform::generic, if needed
if {![llength [info commands ::platform::generic]]} {
    namespace eval ::platform {}
    proc ::platform::generic {} {
        global tcl_platform
    
        set plat [string tolower [lindex $tcl_platform(os) 0]]
        set cpu  $tcl_platform(machine)
    
        switch -glob -- $cpu {
    	sun4* {
    	    set cpu sparc
    	}
    	intel -
    	ia32* -
    	i*86* {
    	    set cpu ix86
    	}
    	x86_64 {
    	    if {$tcl_platform(wordSize) == 4} {
    		# See Example <1> at the top of this file.
    		set cpu ix86
    	    }
    	}
    	ppc -
    	"Power*" {
    	    set cpu powerpc
    	}
    	"arm*" {
    	    set cpu arm
    	}
    	ia64 {
    	    if {$tcl_platform(wordSize) == 4} {
    		append cpu _32
    	    }
    	}
        }
    
        switch -glob -- $plat {
    	windows {
    	    if {$tcl_platform(platform) eq "unix"} {
    		set plat cygwin
    	    } else {
    		set plat win32
    	    }
    	    if {$cpu eq "amd64"} {
    		# Do not check wordSize, win32-x64 is an IL32P64 platform.
    		set cpu x86_64
    	    }
    	}
    	sunos {
    	    set plat solaris
    	    if {[string match "ix86" $cpu]} {
    		if {$tcl_platform(wordSize) == 8} {
    		    set cpu x86_64
    		}
    	    } elseif {![string match "ia64*" $cpu]} {
    		# sparc
    		if {$tcl_platform(wordSize) == 8} {
    		    append cpu 64
    		}
    	    }
    	}
    	darwin {
    	    set major [lindex [split $tcl_platform(osVersion) .] 0]
    	    if {$major > 19} {
    		set plat macos
    	    } else {
    		set plat macosx
    	    }
    	    # Correctly identify the cpu when running as a 64bit
    	    # process on a machine with a 32bit kernel
    	    if {$cpu eq "ix86"} {
    		if {$tcl_platform(wordSize) == 8} {
    		    set cpu x86_64
    		}
    	    }
    	}
    	aix {
    	    set cpu powerpc
    	    if {$tcl_platform(wordSize) == 8} {
    		append cpu 64
    	    }
    	}
    	hp-ux {
    	    set plat hpux
    	    if {![string match "ia64*" $cpu]} {
    		set cpu parisc
    		if {$tcl_platform(wordSize) == 8} {
    		    append cpu 64
    		}
    	    }
    	}
    	osf1 {
    	    set plat tru64
    	}
    	default {
    	    set plat [lindex [split $plat _-] 0]
    	}
        }
    
        return "${plat}-${cpu}"
    }
}


