#
# ----------------------------------------------------------------------
# ISAAC: a fast cryptographic random number generator
# Derived from the source code for ISAAC by Bob Jenkins.
#
# ISAAC (Indirection, Shift, Accumulate, Add, and Count) generates
# 32-bit random numbers. Cycles are guaranteed to be at least 2^40
# values long, and they are 2^8295 values long on average. The
# results are uniformly distributed, unbiased, and unpredictable
# unless you know the seed.
#
# For more information, see the ISAAC homepage at
# http://www.burtleburtle.net/bob/rand/isaacafa.html
#
# This implementation (c) 2004 by Frank Pilhofer. Released under BSD
# license.
# ----------------------------------------------------------------------
#

package require Tcl 8.4

namespace eval isaac {
    #
    # Random numbers
    #

    variable randrsl
    variable randcnt 256

    #
    # Internal state
    #

    variable mm
    variable aa
    variable bb
    variable cc
}

#
# Mix helper
#

proc isaac::mix {a b c d e f g h} {
    set a [expr {($a ^ ($b << 11)) & 0xffffffff}]
    set d [expr {($d + $a) & 0xffffffff}]
    set b [expr {($b + $c) & 0xffffffff}]

    set b [expr {($b ^ ($c >> 2)) & 0xffffffff}]
    set e [expr {($e + $b) & 0xffffffff}]
    set c [expr {($c + $d) & 0xffffffff}]

    set c [expr {($c ^ ($d << 8)) & 0xffffffff}]
    set f [expr {($f + $c) & 0xffffffff}]
    set d [expr {($d + $e) & 0xffffffff}]

    set d [expr {($d ^ ($e >> 16)) & 0xffffffff}]
    set g [expr {($g + $d) & 0xffffffff}]
    set e [expr {($e + $f) & 0xffffffff}]

    set e [expr {($e ^ ($f << 10)) & 0xffffffff}]
    set h [expr {($h + $e) & 0xffffffff}]
    set f [expr {($f + $g) & 0xffffffff}]

    set f [expr {($f ^ ($g >> 4)) & 0xffffffff}]
    set a [expr {($a + $f) & 0xffffffff}]
    set g [expr {($g + $h) & 0xffffffff}]

    set g [expr {($g ^ ($h << 8)) & 0xffffffff}]
    set b [expr {($b + $g) & 0xffffffff}]
    set h [expr {($h + $a) & 0xffffffff}]

    set h [expr {($h ^ ($a >> 9)) & 0xffffffff}]
    set c [expr {($c + $h) & 0xffffffff}]
    set a [expr {($a + $b) & 0xffffffff}]

    return [list $a $b $c $d $e $f $g $h]
}

#
# Initialize, from a (binary) seed string
#

proc isaac::init {seed} {
    variable aa
    variable bb
    variable cc
    variable mm

    #
    # Seed needs to be 256 * 32 bit integers
    #

    set slen [string length $seed]
    if {$slen < 1024} {
	append seed [string repeat "\0" [expr {1024-$slen}]]
    }
    binary scan $seed i256 iseed

    #
    # Initialize
    #

    set aa 0
    set bb 0
    set cc 0
    set mm [list]

    set a 0x9e3779b9
    set b 0x9e3779b9
    set c 0x9e3779b9
    set d 0x9e3779b9
    set e 0x9e3779b9
    set f 0x9e3779b9
    set g 0x9e3779b9
    set h 0x9e3779b9
    set tmm [list]

    for {set i 0} {$i < 4} {incr i} {
	foreach {a b c d e f g h} [mix $a $b $c $d $e $f $g $h] {}
    }

    for {set i 0} {$i < 256} {incr i 8} {
	incr a [lindex $iseed $i]
	incr b [lindex $iseed [expr {$i + 1}]]
	incr c [lindex $iseed [expr {$i + 2}]]
	incr d [lindex $iseed [expr {$i + 3}]]
	incr e [lindex $iseed [expr {$i + 4}]]
	incr f [lindex $iseed [expr {$i + 5}]]
	incr g [lindex $iseed [expr {$i + 6}]]
	incr h [lindex $iseed [expr {$i + 7}]]
	set a [expr {$a & 0xffffffff}]
	set b [expr {$b & 0xffffffff}]
	set c [expr {$c & 0xffffffff}]
	set d [expr {$d & 0xffffffff}]
	set e [expr {$e & 0xffffffff}]
	set f [expr {$f & 0xffffffff}]
	set g [expr {$g & 0xffffffff}]
	set h [expr {$h & 0xffffffff}]
	foreach {a b c d e f g h} [mix $a $b $c $d $e $f $g $h] {}
	lappend tmm $a $b $c $d $e $f $g $h
    }

    for {set i 0} {$i < 256} {incr i 8} {
	incr a [lindex $tmm $i]
	incr b [lindex $tmm [expr {$i + 1}]]
	incr c [lindex $tmm [expr {$i + 2}]]
	incr d [lindex $tmm [expr {$i + 3}]]
	incr e [lindex $tmm [expr {$i + 4}]]
	incr f [lindex $tmm [expr {$i + 5}]]
	incr g [lindex $tmm [expr {$i + 6}]]
	incr h [lindex $tmm [expr {$i + 7}]]
	set a [expr {$a & 0xffffffff}]
	set b [expr {$b & 0xffffffff}]
	set c [expr {$c & 0xffffffff}]
	set d [expr {$d & 0xffffffff}]
	set e [expr {$e & 0xffffffff}]
	set f [expr {$f & 0xffffffff}]
	set g [expr {$g & 0xffffffff}]
	set h [expr {$h & 0xffffffff}]
	foreach {a b c d e f g h} [mix $a $b $c $d $e $f $g $h] {}
	lappend mm $a $b $c $d $e $f $g $h
    }

    isaac
}

#
# Produce some more random numbers
#

proc isaac::isaac {} {
    variable aa
    variable bb
    variable cc
    variable mm
    variable randrsl
    variable randcnt

    set cc [expr {($cc + 1) & 0xffffffff}]
    set bb [expr {($bb + $cc) & 0xffffffff}]

    set randrsl [list]

    for {set i 0} {$i < 256} {incr i} {
	set x [lindex $mm $i]

	if {($i % 4) == 0} {
	    set aa [expr {($aa ^ ($aa << 13)) & 0xffffffff}]
	} elseif {($i % 4) == 1} {
	    set aa [expr {($aa ^ ($aa >>  6)) & 0xffffffff}]
	} elseif {($i % 4) == 2} {
	    set aa [expr {($aa ^ ($aa <<  2)) & 0xffffffff}]
	} else {
	    set aa [expr {($aa ^ ($aa >> 16)) & 0xffffffff}]
	}

	set tmp [lindex $mm [expr {($i + 128) & 0xff}]]
	set aa  [expr {($tmp + $aa) & 0xffffffff}]

	set tmp [lindex $mm [expr {($x >> 2) & 0xff}]]
	set y   [expr {($tmp + $aa + $bb) & 0xffffffff}]
	set mm  [lreplace $mm $i $i $y]

	set tmp [lindex $mm [expr {($y >> 10) & 0xff}]]
	set bb  [expr {($tmp + $x) & 0xffffffff}]
	lappend randrsl $bb
    }

    set randcnt 0
}

#
# ----------------------------------------------------------------------
# Public interface
# ----------------------------------------------------------------------
#

#
# Initialize with a random (binary string) seed
#

proc isaac::srand {seed} {
    init $seed
}

#
# Generates an integer random number in the [0,0xffffffff] interval
#

proc isaac::int32 {} {
    variable randcnt
    variable randrsl

    if {$randcnt >= 256} {
	isaac
    }

    set res [lindex $randrsl $randcnt]
    incr randcnt
    return $res
}

#
# Generates a floating-point random number in the [0,1) interval
#

proc isaac::rand {} {
    set tmp [int32]
    return [expr {double($tmp) / 4294967296.0}]
}

#
# ----------------------------------------------------------------------
# Print test vectors, for comparison with the original code
# ----------------------------------------------------------------------
#

proc isaac::test {} {
    variable randrsl

    init [string repeat "\0" 1024]
    for {set i 0} {$i < 2} {incr i} {
	isaac
	for {set j 0} {$j < 256} {incr j} {
	    puts -nonewline [format "%.8x " [lindex $randrsl $j]]
	    if {($j & 7) == 7} {
		puts ""
	    }
	}
    }
}

proc isaac::test2 {} {
    srand [string repeat "\0" 1024]
    for {set j 0} {$j < 256} {incr j} {
	int32
    }
    for {set i 0} {$i < 2} {incr i} {
	for {set j 0} {$j < 256} {incr j} {
	    set random [int32]
	    puts -nonewline [format "%.8x " $random]
	    if {($j & 7) == 7} {
		puts ""
	    }
	}
    }
}

