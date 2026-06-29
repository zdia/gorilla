#
# ----------------------------------------------------------------------
# pwsafe internal helpers
# ----------------------------------------------------------------------
#

namespace eval pwsafe {}
namespace eval pwsafe::int {}

variable pwsafe::int::sha1isz_K {
    0x5A827999 0x5A827999 0x5A827999 0x5A827999
    0x5A827999 0x5A827999 0x5A827999 0x5A827999
    0x5A827999 0x5A827999 0x5A827999 0x5A827999
    0x5A827999 0x5A827999 0x5A827999 0x5A827999
    0x5A827999 0x5A827999 0x5A827999 0x5A827999
    0x6ED9EBA1 0x6ED9EBA1 0x6ED9EBA1 0x6ED9EBA1
    0x6ED9EBA1 0x6ED9EBA1 0x6ED9EBA1 0x6ED9EBA1
    0x6ED9EBA1 0x6ED9EBA1 0x6ED9EBA1 0x6ED9EBA1
    0x6ED9EBA1 0x6ED9EBA1 0x6ED9EBA1 0x6ED9EBA1
    0x6ED9EBA1 0x6ED9EBA1 0x6ED9EBA1 0x6ED9EBA1
    0x8F1BBCDC 0x8F1BBCDC 0x8F1BBCDC 0x8F1BBCDC
    0x8F1BBCDC 0x8F1BBCDC 0x8F1BBCDC 0x8F1BBCDC
    0x8F1BBCDC 0x8F1BBCDC 0x8F1BBCDC 0x8F1BBCDC
    0x8F1BBCDC 0x8F1BBCDC 0x8F1BBCDC 0x8F1BBCDC
    0x8F1BBCDC 0x8F1BBCDC 0x8F1BBCDC 0x8F1BBCDC
    0xCA62C1D6 0xCA62C1D6 0xCA62C1D6 0xCA62C1D6
    0xCA62C1D6 0xCA62C1D6 0xCA62C1D6 0xCA62C1D6
    0xCA62C1D6 0xCA62C1D6 0xCA62C1D6 0xCA62C1D6
    0xCA62C1D6 0xCA62C1D6 0xCA62C1D6 0xCA62C1D6
    0xCA62C1D6 0xCA62C1D6 0xCA62C1D6 0xCA62C1D6
}

#
# This SHA1 implementation is taken from Don Libes' version
# in tcllib. The only difference is the "isz" parameter; if
# set to true, the "initial H buffer" is set to all zeroes
# instead of the well-defined constants. Oh, and the result
# is returned in binary format, not in hex.
#
# pwsafe calls this SHA1_init_state_zero, and uses it to
# compute a hash to validate the password with. It is almost
# certainly due to a bug in an early pwsafe implementation
# that later versions still want to be compatible with.
#

proc pwsafe::int::sha1isz {msg {isz 0}} {
    variable sha1isz_K

    #
    # 4. MESSAGE PADDING
    #

    # pad to 512 bits (512/8 = 64 bytes)
    
    set msgLen [string length $msg]
    
    # last 8 bytes are reserved for msgLen
    # plus 1 for "1"
    
    set padLen [expr {56 - $msgLen%64}]
    if {$msgLen % 64 >= 56} {
	incr padLen 64
    }

    # 4a. and b. append single 1b followed by 0b's
    append msg [binary format "a$padLen" \200]

    # 4c. append 64-bit length
    # Our implementation obviously limits string length to 32bits.
    append msg \0\0\0\0[binary format "I" [expr {8*$msgLen}]]
    #
    # 7. COMPUTING THE MESSAGE DIGEST
    #

    # initial H buffer

    if {!$isz} {
	set H0 [expr {int(0x67452301)}]
	set H1 [expr {int(0xEFCDAB89)}]
	set H2 [expr {int(0x98BADCFE)}]
	set H3 [expr {int(0x10325476)}]
	set H4 [expr {int(0xC3D2E1F0)}]
    } else {
	set H0 0
	set H1 0
	set H2 0
	set H3 0
	set H4 0
    }

    #
    # process message in 16-word blocks (64-byte blocks)
    #

    # convert message to array of 32-bit integers
    # each block of 16-words is stored in M($i,0-16)

    binary scan $msg I* words
    set blockLen [llength $words]

    for {set i 0} {$i < $blockLen} {incr i 16} {
	# 7a. Divide M[i] into 16 words W[0], W[1], ...
	set W [lrange $words $i [expr {$i+15}]]
	
	# 7b. For t = 16 to 79 let W[t] = ....
	set t   16
	set t3  12
	set t8   7
	set t14  1
	set t16 -1
	for {} {$t < 80} {incr t} {
	    set x [expr {[lindex $W [incr t3]] ^ [lindex $W [incr t8]] ^ \
		    [lindex $W [incr t14]] ^ [lindex $W [incr t16]]}]
	    lappend W [expr {($x << 1) | (($x >> 31) & 1)}]
	}

	# 7c. Let A = H[0] ....
	set A $H0
	set B $H1
	set C $H2
	set D $H3
	set E $H4
	
	# 7d. For t = 0 to 79 do
	# because of use in 64bit systems it is important to cut off the lower part
	# by an AND: value & 0xffffffff)
	for {set t 0} {$t < 20} {incr t} {
	    set TEMP [expr {(((($A << 5) & 0xffffffff)| (($A >> 27) & 0x1f)) + \
		    (($B & $C) | ((~$B) & $D)) \
		    + $E + [lindex $W $t] + [lindex $sha1isz_K $t]) & 0xffffffff}]
			set E $D
	    set D $C
	    set C [expr {(($B << 30) & 0xffffffff) | (($B >> 2) & 0x3fffffff)}]
	    set B $A
	    set A $TEMP
	}
	for {} {$t<40} {incr t} {
	    set TEMP [expr {(((($A << 5) & 0xffffffff) | (($A >> 27) & 0x1f)) + \
		    ($B ^ $C ^ $D) \
		    + $E + [lindex $W $t] + [lindex $sha1isz_K $t]) & 0xffffffff}]
	    set E $D
	    set D $C
	    set C [expr {(($B << 30) & 0xffffffff) | (($B >> 2) & 0x3fffffff)}]
	    set B $A
	    set A $TEMP
	}
	for {} {$t<60} {incr t} {
	    set TEMP [expr {(((($A << 5) & 0xffffffff) | (($A >> 27) & 0x1f)) + \
		    (($B & $C) | ($B & $D) | ($C & $D)) \
		    + $E + [lindex $W $t] + [lindex $sha1isz_K $t]) & 0xffffffff}]
	    set E $D
	    set D $C
	    set C [expr {(($B << 30)  & 0xffffffff) | (($B >> 2) & 0x3fffffff)}]
	    set B $A
	    set A $TEMP
	}
	for {} {$t<80} {incr t} {
	    set TEMP [expr {(((($A << 5) & 0xffffffff)| (($A >> 27) & 0x1f)) + \
		    ($B ^ $C ^ $D) \
		    + $E + [lindex $W $t] + [lindex $sha1isz_K $t]) & 0xffffffff}]
	    set E $D
	    set D $C
	    set C [expr {(($B << 30) & 0xffffffff) | (($B >> 2) & 0x3fffffff)}]
	    set B $A
	    set A $TEMP
	}
	set H0 [expr {int(($H0 + $A) & 0xffffffff)}]
	set H1 [expr {int(($H1 + $B) & 0xffffffff)}]
	set H2 [expr {int(($H2 + $C) & 0xffffffff)}]
	set H3 [expr {int(($H3 + $D) & 0xffffffff)}]
	set H4 [expr {int(($H4 + $E) & 0xffffffff)}]
    }

    return [binary format IIIII $H0 $H1 $H2 $H3 $H4]
}

#
# pwsafe 2 uses blowfish incorrectly. Blowfish wants big endian
# integers (i.e., \x00\x00\x00\x01 becomes 1). Pwsafe just
# casts char* to long*, which does the Wrong Thing on a little
# endian architecture (like x86). So we frequently have to
# change a number's sex.
#

proc pwsafe::int::genderbender {val} {
    binary scan $val i* vals
    return [binary format I* $vals]
}

#
# (For Password Safe 2)
# H(RND) is SHA1_init_state_zero(tempSalt|Cipher(RND));
#   tempSalt = SHA1(RND|{0x00,0x00}|password);
#   Cipher(RND) is 1000 encryptions of RND, with tempSalt as the
#   encryption key. In short, a kind of HMAC dependant on the
#   password. Written before the HMAC RFC came out, no good reason
#   to change. (If it ain't broke...)
#

proc pwsafe::int::computeHRND {RND password} {
    set temp $RND
    append temp "\x00\x00"
    append temp $password
    set tempSalt [pwsafe::int::sha1isz $temp]
    set engine [iblowfish::ecb \#auto $tempSalt]
    set cipher [pwsafe::int::genderbender $RND]
    for {set i 0} {$i < 1000} {incr i} {
	set cipher [$engine encryptBlock $cipher]
    }
    itcl::delete object $engine

    set temp [pwsafe::int::genderbender $cipher]
    append temp "\x00\x00"
    return [pwsafe::int::sha1isz $temp 1]
}

#
# Password Safe 3 uses a "stretched key" of the user's passphrase and
# the SALT, as defined by the hash-function-based key stretching
# algorithm in http://www.schneier.com/paper-low-entropy.pdf
# (Section 4.1), with SHA-256 as the hash function, and a variable
# number of iterations that is stored in the file.
#

proc pwsafe::int::computeStretchedKey {salt password iterations pvar_in} {
	upvar $pvar_in pvar
	set st [sha2::SHA256Init] ;# st = stretched key
# puts [info commands ::sha2::*]
# puts "salt [hex $salt]\npassword $password iterations $iterations"
    sha2::SHA256Update $st $password
# puts "sha2::Hex [sha2::Hex $st]"
    sha2::SHA256Update $st $salt
    set Xi [sha2::SHA256Final $st]
# puts "Xi [hex $Xi]"
	set blocks [ expr { $iterations / 256 } ]
	for {set j 0} {$j < $blocks} {incr j} {
		for {set i 0} {$i < 256} {incr i} {
			set Xi [sha2::sha256 -bin $Xi]
		}
		set pvar [ expr { 100 * $j * 256 / $iterations } ]
	}
	set remain [ expr {$iterations - ($j * 256) } ]
	for {set i 0} {$i < $remain} {incr i} {
		set Xi [sha2::sha256 -bin $Xi]
	}
	set pvar 100
	return $Xi
}

proc pwsafe::int::calculateKeyStrechForDelay { seconds } {

	set iter 1024
	set elapsed 0

	# quickly locate an iteration amount that produces some measurable
	# time delay - as the iteration count increases by powers of 2 this
	# should reasonably quickly locate a useful value on very fast CPU's

	while { $elapsed < 256 } {
		set iter [ expr { $iter * 2 } ]
		set elapsed [ pwsafe::int::keyStretchMsDelay $iter ]
	}

	# compute and return a final iteration amount based upon the located value
	# above and the requested time delay factor
  
	return [ expr { int( ceil( $iter * ( $seconds * 1000.0 / $elapsed ) ) ) } ]

	#ruff
	#
	# Computes a V3 keystretch iteration value that produces a time
	# delay of "seconds".  Note that the returned value will be
	# dependent upon whether the sha256 C extension is in use or not.
	#
	# seconds - the number of seconds that the V3 keystrech function should execute
	#
	# returns an iteration count value

} ; # end proc pwsafe::int::calculateKeyStrechForDelay

proc pwsafe::int::keyStretchMsDelay { iter } {

	set salt [ pwsafe::int::randomString 32 ]
	set start [ clock milliseconds ]
	set junk 0 ; # used as the "progress variable" for computeStretchedKey
	pwsafe::int::computeStretchedKey $salt "The quick brown fox jumped over the lazy dog." $iter junk
	return [ expr { [ clock milliseconds ] - $start } ]

	#ruff
	#
	# Computes the time in milliseconds to perform a V3 keystretch using
	# iter iterations
	#
	# iter - the number of iterations for the V3 keystretch algorithm
	#
	# returns a time value in milliseconds

} ; # end pwsafe::int::keyStretchMsDelay

#
# Generate a string of pseudo-random data
#

proc pwsafe::int::randomString {length} {
    set randomOctets [list]
    #
    # Use ISAAC PRNG, if present
    #
    if {[namespace exists ::isaac]} {
	for {set i 0} {$i < $length} {incr i} {
	    set rand [::isaac::rand]
	    lappend randomOctets [expr {127-int($rand*256.)}]
	}
    } else {
	for {set i 0} {$i < $length} {incr i} {
	    lappend randomOctets [expr {127-int(rand()*256.)}]
	}
    }
    return [binary format c* $randomOctets]
}

#
# Overwrite a variable's contents with a random string
#

proc pwsafe::int::randomizeVar {args} {
    foreach var $args {
	uplevel 1 "set $var \[pwsafe::int::randomString \[string length \$$var\]\]"
    }
}

# tool for testing purposes

proc hex { str } {
	binary scan $str H* hex
	return $hex			 
} 
