package require Tcl 8.4
package require Itcl

namespace eval ::itwofish {

}

catch {
    itcl::delete class ::itwofish::itwofish
}

itcl::class ::itwofish::itwofish {
    #
    # Constants
    #

    private common SK_STEP 0x02020202
    private common SK_BUMP 0x01010101
    private common SK_ROTL 9

    private common BLOCK_SIZE 128
    private common BLOCK_WORDS [expr {$BLOCK_SIZE / 32}]
    private common MAX_KEY_BITS 256
    private common MIN_KEY_BITS 128
    private common MAX_KEY_WORDS [expr {$MAX_KEY_BITS / 32}]

    private common INPUT_WHITEN 0
    private common OUTPUT_WHITEN [expr {$INPUT_WHITEN + $BLOCK_SIZE / 32}]
    private common ROUND_SUBKEYS [expr {$OUTPUT_WHITEN + $BLOCK_SIZE / 32}]

    private common P8x80 {
	0xA9 0x67 0xB3 0xE8 0x04 0xFD 0xA3 0x76 
	0x9A 0x92 0x80 0x78 0xE4 0xDD 0xD1 0x38 
	0x0D 0xC6 0x35 0x98 0x18 0xF7 0xEC 0x6C 
	0x43 0x75 0x37 0x26 0xFA 0x13 0x94 0x48 
	0xF2 0xD0 0x8B 0x30 0x84 0x54 0xDF 0x23 
	0x19 0x5B 0x3D 0x59 0xF3 0xAE 0xA2 0x82 
	0x63 0x01 0x83 0x2E 0xD9 0x51 0x9B 0x7C 
	0xA6 0xEB 0xA5 0xBE 0x16 0x0C 0xE3 0x61 
	0xC0 0x8C 0x3A 0xF5 0x73 0x2C 0x25 0x0B 
	0xBB 0x4E 0x89 0x6B 0x53 0x6A 0xB4 0xF1 
	0xE1 0xE6 0xBD 0x45 0xE2 0xF4 0xB6 0x66 
	0xCC 0x95 0x03 0x56 0xD4 0x1C 0x1E 0xD7 
	0xFB 0xC3 0x8E 0xB5 0xE9 0xCF 0xBF 0xBA 
	0xEA 0x77 0x39 0xAF 0x33 0xC9 0x62 0x71 
	0x81 0x79 0x09 0xAD 0x24 0xCD 0xF9 0xD8 
	0xE5 0xC5 0xB9 0x4D 0x44 0x08 0x86 0xE7 
	0xA1 0x1D 0xAA 0xED 0x06 0x70 0xB2 0xD2 
	0x41 0x7B 0xA0 0x11 0x31 0xC2 0x27 0x90 
	0x20 0xF6 0x60 0xFF 0x96 0x5C 0xB1 0xAB 
	0x9E 0x9C 0x52 0x1B 0x5F 0x93 0x0A 0xEF 
	0x91 0x85 0x49 0xEE 0x2D 0x4F 0x8F 0x3B 
	0x47 0x87 0x6D 0x46 0xD6 0x3E 0x69 0x64 
	0x2A 0xCE 0xCB 0x2F 0xFC 0x97 0x05 0x7A 
	0xAC 0x7F 0xD5 0x1A 0x4B 0x0E 0xA7 0x5A 
	0x28 0x14 0x3F 0x29 0x88 0x3C 0x4C 0x02 
	0xB8 0xDA 0xB0 0x17 0x55 0x1F 0x8A 0x7D 
	0x57 0xC7 0x8D 0x74 0xB7 0xC4 0x9F 0x72 
	0x7E 0x15 0x22 0x12 0x58 0x07 0x99 0x34 
	0x6E 0x50 0xDE 0x68 0x65 0xBC 0xDB 0xF8 
	0xC8 0xA8 0x2B 0x40 0xDC 0xFE 0x32 0xA4 
	0xCA 0x10 0x21 0xF0 0xD3 0x5D 0x0F 0x00 
	0x6F 0x9D 0x36 0x42 0x4A 0x5E 0xC1 0xE0
    }

    private common P8x81 {
	0x75 0xF3 0xC6 0xF4 0xDB 0x7B 0xFB 0xC8 
	0x4A 0xD3 0xE6 0x6B 0x45 0x7D 0xE8 0x4B 
	0xD6 0x32 0xD8 0xFD 0x37 0x71 0xF1 0xE1 
	0x30 0x0F 0xF8 0x1B 0x87 0xFA 0x06 0x3F 
	0x5E 0xBA 0xAE 0x5B 0x8A 0x00 0xBC 0x9D 
	0x6D 0xC1 0xB1 0x0E 0x80 0x5D 0xD2 0xD5 
	0xA0 0x84 0x07 0x14 0xB5 0x90 0x2C 0xA3 
	0xB2 0x73 0x4C 0x54 0x92 0x74 0x36 0x51 
	0x38 0xB0 0xBD 0x5A 0xFC 0x60 0x62 0x96 
	0x6C 0x42 0xF7 0x10 0x7C 0x28 0x27 0x8C 
	0x13 0x95 0x9C 0xC7 0x24 0x46 0x3B 0x70 
	0xCA 0xE3 0x85 0xCB 0x11 0xD0 0x93 0xB8 
	0xA6 0x83 0x20 0xFF 0x9F 0x77 0xC3 0xCC 
	0x03 0x6F 0x08 0xBF 0x40 0xE7 0x2B 0xE2 
	0x79 0x0C 0xAA 0x82 0x41 0x3A 0xEA 0xB9 
	0xE4 0x9A 0xA4 0x97 0x7E 0xDA 0x7A 0x17 
	0x66 0x94 0xA1 0x1D 0x3D 0xF0 0xDE 0xB3 
	0x0B 0x72 0xA7 0x1C 0xEF 0xD1 0x53 0x3E 
	0x8F 0x33 0x26 0x5F 0xEC 0x76 0x2A 0x49 
	0x81 0x88 0xEE 0x21 0xC4 0x1A 0xEB 0xD9 
	0xC5 0x39 0x99 0xCD 0xAD 0x31 0x8B 0x01 
	0x18 0x23 0xDD 0x1F 0x4E 0x2D 0xF9 0x48 
	0x4F 0xF2 0x65 0x8E 0x78 0x5C 0x58 0x19 
	0x8D 0xE5 0x98 0x57 0x67 0x7F 0x05 0x64 
	0xAF 0x63 0xB6 0xFE 0xF5 0xB7 0x3C 0xA5 
	0xCE 0xE9 0x68 0x44 0xE0 0x4D 0x43 0x69 
	0x29 0x2E 0xAC 0x15 0x59 0xA8 0x0A 0x9E 
	0x6E 0x47 0xDF 0x34 0x35 0x6A 0xCF 0xDC 
	0x22 0xC9 0xC0 0x9B 0x89 0xD4 0xED 0xAB 
	0x12 0xA2 0x0D 0x52 0xBB 0x02 0x2F 0xA9 
	0xD7 0x61 0x1E 0xB4 0x50 0x04 0xF6 0xC2 
	0x16 0x25 0x86 0x56 0x55 0x09 0xBE 0x91
    }

    #
    # Functions
    #

    private common MDS_GF_FDBK 0x169

    # ---------------------------------------------------
    # load a compiled C extension for f32 - if one exists
    # ---------------------------------------------------

    set machine $::tcl_platform(machine)
    set os      $::tcl_platform(os)

    # regularize machine name for ix86 variants
    switch -glob -- $machine {
      intel -
      i*86* { set machine x86 }
    }
		
    # regularize os name for Windows variants
    switch -glob -- $os {
      Windows* { set os Windows }
    }

		# since Tcl 8.5.9.1: Darwin >= 10.5
		
# puts stderr "twofish: gorilla::Dir = $gorilla::Dir"
    set lib [ file join $::gorilla::Dir twofish f32-$os-$machine[ info sharedlibextension ] ]
#    puts stderr "twofish: lib -> $lib"

    if { [ catch { load $lib f32 } ] } {
# 	puts stderr "twofish: Using Tcl only f32"
      set callmap [ list -m:f32- f32 ]
    } else {
# 	puts stderr "twofish: Using Critcl f32"
      set callmap [ list -m:f32- f32_critcl ]
    }

# ---------------------------------------------------


    public proc f32 {x k32 keyLen} {
	set b0 [expr {$x & 255}]
	set b1 [expr {($x >> 8) & 255}]
	set b2 [expr {($x >> 16) & 255}]
	set b3 [expr {($x >> 24) & 255}]

	set kl [expr {(($keyLen + 63) / 64) & 3}]

	if {$kl == 0} {
	    set k323 [lindex $k32 3]
	    set b0 [expr {[lindex $P8x81 $b0] ^ ($k323 & 255)}]
	    set b1 [expr {[lindex $P8x80 $b1] ^ (($k323 >> 8) & 255)}]
	    set b2 [expr {[lindex $P8x80 $b2] ^ (($k323 >> 16) & 255)}]
	    set b3 [expr {[lindex $P8x81 $b3] ^ (($k323 >> 24) & 255)}]
	}

	if {$kl == 0 || $kl == 3} {
	    set k322 [lindex $k32 2]
	    set b0 [expr {[lindex $P8x81 $b0] ^ ($k322 & 255)}]
	    set b1 [expr {[lindex $P8x81 $b1] ^ (($k322 >> 8) & 255)}]
	    set b2 [expr {[lindex $P8x80 $b2] ^ (($k322 >> 16) & 255)}]
	    set b3 [expr {[lindex $P8x80 $b3] ^ (($k322 >> 24) & 255)}]
	}

	if {$kl == 0 || $kl == 3 || $kl == 2} {
	    set k320 [lindex $k32 0]
	    set k321 [lindex $k32 1]

	    set t0 [expr {[lindex $P8x80 $b0] ^ ($k321 & 255)}]
	    set t1 [expr {[lindex $P8x81 $b1] ^ (($k321 >> 8) & 255)}]
	    set t2 [expr {[lindex $P8x80 $b2] ^ (($k321 >> 16) & 255)}]
	    set t3 [expr {[lindex $P8x81 $b3] ^ (($k321 >> 24) & 255)}]

	    set t0 [expr {[lindex $P8x80 $t0] ^ ($k320 & 255)}]
	    set t1 [expr {[lindex $P8x80 $t1] ^ (($k320 >> 8) & 255)}]
	    set t2 [expr {[lindex $P8x81 $t2] ^ (($k320 >> 16) & 255)}]
	    set t3 [expr {[lindex $P8x81 $t3] ^ (($k320 >> 24) & 255)}]

	    set b0 [lindex $P8x81 $t0]
	    set b1 [lindex $P8x80 $t1]
	    set b2 [lindex $P8x81 $t2]
	    set b3 [lindex $P8x80 $t3]
	}

	#
	# MDS_GF_FDBK/2 == 180
	# MDS_GF_FDBK/4 == 90
	#

	set b0x [expr {$b0 ^ (($b0 >> 2) ^ (($b0 & 2) ? 180 : 0)) ^ (($b0 & 1) ? 90 : 0)}]
	set b0y [expr {$b0x ^ (($b0 >> 1) ^ (($b0 & 1) ? 180 : 0))}]

	set b1x [expr {$b1 ^ (($b1 >> 2) ^ (($b1 & 2) ? 180 : 0)) ^ (($b1 & 1) ? 90 : 0)}]
	set b1y [expr {$b1x ^ (($b1 >> 1) ^ (($b1 & 1) ? 180 : 0))}]

	set b2x [expr {$b2 ^ (($b2 >> 2) ^ (($b2 & 2) ? 180 : 0)) ^ (($b2 & 1) ? 90 : 0)}]
	set b2y [expr {$b2x ^ (($b2 >> 1) ^ (($b2 & 1) ? 180 : 0))}]

	set b3x [expr {$b3 ^ (($b3 >> 2) ^ (($b3 & 2) ? 180 : 0)) ^ (($b3 & 1) ? 90 : 0)}]
	set b3y [expr {$b3x ^ (($b3 >> 1) ^ (($b3 & 1) ? 180 : 0))}]

	return [expr {((($b0 ^ $b1y ^ $b2x ^ $b3x) | \
			    (($b0x ^ $b1y ^ $b2y ^ $b3) << 8) | \
			    (($b0y ^ $b1x ^ $b2 ^ $b3y) << 16) | \
			    (($b0y ^ $b1 ^ $b2y ^ $b3x) << 24)) + 0x100000000) % \
			  0x100000000}]
    }

    private common RS_GF_FDBK 0x14d

    public proc RS_rem {x} {
	variable RS_GF_FDBK
	set b [expr {$x >> 24}]
	set r [expr {$x & 0x00ffffff}]
	set g2 [expr {(($b << 1) ^ (($b & 0x80) ? $RS_GF_FDBK : 0)) & 255}]
	set g3 [expr {($b >> 1) ^ (($b & 1) ? ($RS_GF_FDBK >> 1) : 0) ^ $g2}]
	return [expr {($r << 8) ^ ($g3 << 24) ^ ($g2 << 16) ^ ($g3 << 8) ^ $b}]
    }

    public proc RS_MDS_Encode {k0 k1} {
	set r $k1

	set r [RS_rem $r]
	set r [RS_rem $r]
	set r [RS_rem $r]
	set r [RS_rem $r]

	set r [expr {$r ^ $k0}]

	set r [RS_rem $r]
	set r [RS_rem $r]
	set r [RS_rem $r]
	set r [RS_rem $r]

	return $r
    }

    #
    # Variables
    #

    public variable keyLen
    public variable key32
    public variable sboxKeys
    public variable subKeys

    #
    # Initialize with key
    #

    constructor {key_} {
	makeKey $key_
    }

    public method makeKey {key_} {
	set kl [string length $key_]

	#
	# Key must be at least 128 bits
	#

	if {$kl < 16} {
	    set padLen [expr {15-$kl}]
	    set padding "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
	    append key_ [string range $padding 0 $padLen]
	    incr kl $padLen
	    incr kl
	}

	#
	# Key must be a multiple of 8 bytes
	#

	if {($kl % 8) != 0} {
	    set padLen [expr {7-($kl%8)}]
	    set padding "\x00\x00\x00\x00\x00\x00\x00"
	    append message [string range $padding 0 $padLen]
	    incr kl $padLen
	    incr kl
	}

	set keyLen [expr {$kl * 8}]

	if {$keyLen > $MAX_KEY_BITS} {
	    error "invalid key length $keyLen"
	}

	binary scan $key_ i* key32s

	set key32 [list]

	foreach k $key32s {
	    lappend key32 [expr {($k + 0x100000000) % 0x100000000}]
	}

	while {[llength $key32] < $MAX_KEY_WORDS} {
	    lappend key32 0
	}

	reKey
    }

    public method reKey {} [ string map $callmap {
	set subkeyCnt [expr {$ROUND_SUBKEYS + 32}]
	set k64Cnt [expr {($keyLen + 63) / 64}]
	set sboxKeys [list]

	for {set i 0} {$i < $k64Cnt} {incr i} {
	    set ke [lindex $key32 [expr {2*$i}]]
	    set ko [lindex $key32 [expr {2*$i+1}]]
	    set sk [RS_MDS_Encode $ke $ko]
	    lappend k32e $ke
	    lappend k32o $ko
	    set sboxKeys [linsert $sboxKeys 0 $sk]
	}

	set subkeyCntDiv2 [expr {$subkeyCnt / 2}]

	for {set i 0} {$i < $subkeyCntDiv2} {incr i} {
#puts stderr "reKey f32: [f32 [expr {$i * $SK_STEP}] $k32e $keyLen] f32_critcl: [f32_critcl [expr {$i * $SK_STEP}] $k32e $keyLen]"
	    set A [-m:f32- [expr {$i * $SK_STEP}] $k32e $keyLen]
#puts stderr "reKey f32: [f32 [expr {$i * $SK_STEP + $SK_BUMP}] $k32o $keyLen] f32_critcl: [f32_critcl [expr {$i * $SK_STEP + $SK_BUMP}] $k32o $keyLen]"
	    set B [-m:f32- [expr {$i * $SK_STEP + $SK_BUMP}] $k32o $keyLen]
	    set B [expr {(($B << 8) % 0x100000000) | ($B >> 24)}]

	    set Ap2B [expr {($A + 2*$B) % 0x100000000}]
	    lappend subKeys [expr {($A + $B) % 0x100000000}]
	    lappend subKeys [expr {(($Ap2B << $SK_ROTL) % 0x100000000) | ($Ap2B >> (32 - $SK_ROTL))}]
	}
    } ]

    #
    # Encryption
    #

    public method intEncrypt {x0 x1 x2 x3} [ string map $callmap {
	#
	# INPUT_WHITEN == 0..3
	#

	set x0 [expr {$x0 ^ [lindex $subKeys 0]}]
	set x1 [expr {$x1 ^ [lindex $subKeys 1]}]
	set x2 [expr {$x2 ^ [lindex $subKeys 2]}]
	set x3 [expr {$x3 ^ [lindex $subKeys 3]}]

	set skie $ROUND_SUBKEYS
	set skio [expr {$ROUND_SUBKEYS + 1}]

	for {set r 0} {$r < 16} {incr r} {
#puts stderr "intEncrypt f32: [f32 $x0 $sboxKeys $keyLen] f32_critcl: [f32_critcl $x0 $sboxKeys $keyLen]"
	    set t0 [-m:f32- $x0 $sboxKeys $keyLen]
#puts stderr "intEncrypt f32: [f32 [expr {(($x1 << 8) % 0x100000000) | ($x1 >> 24)}] $sboxKeys $keyLen] f32_critcl: [f32_critcl [expr {(($x1 << 8) % 0x100000000) | ($x1 >> 24)}] $sboxKeys $keyLen]"
	    set t1 [-m:f32- [expr {(($x1 << 8) % 0x100000000) | ($x1 >> 24)}] $sboxKeys $keyLen]

	    set x2 [expr {$x2 ^ (($t0 + $t1 + [lindex $subKeys $skie]) % 0x100000000)}]
	    set x2 [expr {(($x2 << 31) % 0x100000000) | ($x2 >> 1)}]
	    set x3 [expr {(($x3 << 1) % 0x100000000) | ($x3 >> 31)}]
	    set x3 [expr {$x3 ^ (($t0 + 2*$t1 + [lindex $subKeys $skio]) % 0x100000000)}]

	    if {$r < 15} {
		set tmp $x0
		set x0 $x2
		set x2 $tmp

		set tmp $x1
		set x1 $x3
		set x3 $tmp

		incr skie 2
		incr skio 2
	    }
	}

	#
	# OUTPUT_WHITEN==4..7
	#

	set o0 [expr {$x0 ^ [lindex $subKeys 4]}]
	set o1 [expr {$x1 ^ [lindex $subKeys 5]}]
	set o2 [expr {$x2 ^ [lindex $subKeys 6]}]
	set o3 [expr {$x3 ^ [lindex $subKeys 7]}]

	return [list $o0 $o1 $o2 $o3]
    } ]

    #
    # Decryption
    #

    protected method intDecrypt {x0 x1 x2 x3} [ string map $callmap {
	#
	# OUTPUT_WHITEN==4..7
	#

	set x0 [expr {$x0 ^ [lindex $subKeys 4]}]
	set x1 [expr {$x1 ^ [lindex $subKeys 5]}]
	set x2 [expr {$x2 ^ [lindex $subKeys 6]}]
	set x3 [expr {$x3 ^ [lindex $subKeys 7]}]

	set skie [expr {$ROUND_SUBKEYS + 30}]
	set skio [expr {$ROUND_SUBKEYS + 31}]

	for {set r 16} {$r > 0} {incr r -1} {
#puts stderr "intDecrypt f32: [f32 $x0 $sboxKeys $keyLen] f32_critcl: [f32_critcl $x0 $sboxKeys $keyLen]"
	    set t0 [-m:f32- $x0 $sboxKeys $keyLen]

#puts stderr "intDecrypt f32: [f32 [expr {(($x1 << 8) % 0x100000000) | ($x1 >> 24)}] $sboxKeys $keyLen] f32_critcl: [f32_critcl [expr {(($x1 << 8) % 0x100000000) | ($x1 >> 24)}] $sboxKeys $keyLen]"
	    set t1 [-m:f32- [expr {(($x1 << 8) % 0x100000000) | ($x1 >> 24)}] $sboxKeys $keyLen]

	    set x2 [expr {(($x2 << 1) % 0x100000000) | ($x2 >> 31)}]
	    set x2 [expr {$x2 ^ (($t0 + $t1 + [lindex $subKeys $skie]) % 0x100000000)}]
	    set x3 [expr {$x3 ^ (($t0 + 2*$t1 + [lindex $subKeys $skio]) % 0x100000000)}]
	    set x3 [expr {(($x3 << 31) % 0x100000000) | ($x3 >> 1)}]

	    if {$r > 1} {
		set tmp $x0
		set x0 $x2
		set x2 $tmp

		set tmp $x1
		set x1 $x3
		set x3 $tmp

		incr skie -2
		incr skio -2
	    }
	}

	#
	# INPUT_WHITEN==0..3
	#

	set o0 [expr {$x0 ^ [lindex $subKeys 0]}]
	set o1 [expr {$x1 ^ [lindex $subKeys 1]}]
	set o2 [expr {$x2 ^ [lindex $subKeys 2]}]
	set o3 [expr {$x3 ^ [lindex $subKeys 3]}]

	return [list $o0 $o1 $o2 $o3]
    } ]
}

#
# Twofish - Electronic Codebook Mode.
#

catch {
    itcl::delete class itwofish::ecb
}

itcl::class itwofish::ecb {
    inherit itwofish::itwofish

    constructor {key} {
	itwofish::itwofish::constructor $key
    } {
    }

    #
    # Encrypt a 128 bit (16 octet) message block
    #

    public method encryptBlock {block} {
	if {[binary scan $block iiii x0 x1 x2 x3] != 4} {
	    error "block must be 16 bytes"
	}
	set x0 [expr {($x0 + 0x100000000) % 0x100000000}]
	set x1 [expr {($x1 + 0x100000000) % 0x100000000}]
	set x2 [expr {($x2 + 0x100000000) % 0x100000000}]
	set x3 [expr {($x3 + 0x100000000) % 0x100000000}]
	set d  [intEncrypt $x0 $x1 $x2 $x3]
	return [binary format i4 $d]
    }

    #
    # Decrypt a 128 bit (16 octet) message block
    #

    public method decryptBlock {block} {
	if {[binary scan $block iiii x0 x1 x2 x3] != 4} {
	    error "block must be 16 bytes"
	}
	set x0 [expr {($x0 + 0x100000000) % 0x100000000}]
	set x1 [expr {($x1 + 0x100000000) % 0x100000000}]
	set x2 [expr {($x2 + 0x100000000) % 0x100000000}]
	set x3 [expr {($x3 + 0x100000000) % 0x100000000}]
	set d  [intDecrypt $x0 $x1 $x2 $x3]
	return [binary format i4 $d]
    }
}

#
# Twofish - Cipher Block Chaining
#
# Encrypt or decrypt a message. The object is initialized with the
# password and a salt (also known as the Initialization Vector). The
# salt must be exactly 16 bytes long; it is usually chosen at random.
# The encrypted message is of the same length as the cleartext message,
# but padded to the next multiple of 16 bytes.
#
# To decrypt a message, initialize the object with the same password
# and the same salt that were used for encryption. A decrypted message
# has the same (padded) length as the encrypted message. Protocols
# usually embed information about the message length, so that the
# decrypted message can be properly truncated to the length of the
# original cleartext message.
#
# The object can be used to encrypt/decrypt a stream, by calling the
# encrypt or decrypt method repeatedly, passing subsequent blocks of
# the stream.
#
# When encrypting a stream, all blocks but the last must be a multiple
# of 16 bytes in length.
#
# When decrypting a stream, all blocks, including the last, must be
# a multiple of 16 bytes in length. Again, truncation may be necessary
# if the original cleartext stream was not a multiple of 16 bytes in
# length.
#
# Note that the salt changes over time (i.e., it is updated after 16
# bytes each). To encrypt a new message with the same salt, or to
# switch between encryption and decryption, re-configure the "salt"
# variable, i.e.,
#
# set o [itwofish::cbc #auto MyPassword 0123456789abcdef]
# set cipher [$o encrypt "Hello World"]
# $o configure -salt 0123456789abcdef
# set clear [$o decrypt $cipher] ;# Hello World (plus padding)
# itcl::delete object $o
#

catch {
    itcl::delete class itwofish::cbc
}

itcl::class itwofish::cbc {
    inherit itwofish::itwofish

    public variable salt

    constructor {key salt_} {
	itwofish::itwofish::constructor $key
    } {
	set salt $salt_
	if {[binary scan $salt iiii s0 s1 s2 s3] != 4} {
	    error "salt must be 16 bytes"
	}
    }

    public method encrypt {message} {
	if {[binary scan $salt iiii s0 s1 s2 s3] != 4} {
	    error "salt must be 16 bytes"
	}

	set mlen [string length $message]

	if {($mlen % 16) != 0} {
	    set padLen [expr {15-($mlen%16)}]
	    set padding "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
	    append message [string range $padding 0 $padLen]
	    incr mlen $padLen
	    incr mlen
	}

	set result ""

	for {set i 0} {$i < $mlen} {incr i 16} {
	    if {[binary scan $message @[set i]iiii x0 x1 x2 x3] != 4} {
		error "oops"
	    }

	    set x0 [expr {(($x0 ^ $s0) + 0x100000000) % 0x100000000}]
	    set x1 [expr {(($x1 ^ $s1) + 0x100000000) % 0x100000000}]
	    set x2 [expr {(($x2 ^ $s2) + 0x100000000) % 0x100000000}]
	    set x3 [expr {(($x3 ^ $s3) + 0x100000000) % 0x100000000}]

	    set d  [intEncrypt $x0 $x1 $x2 $x3]

	    set s0 [lindex $d 0]
	    set s1 [lindex $d 1]
	    set s2 [lindex $d 2]
	    set s3 [lindex $d 3]

	    append result [binary format i4 $d]
	}

	set salt [binary format iiii $s0 $s1 $s2 $s3]
	return $result
    }

    public method decrypt {message} {
	if {[binary scan $salt iiii s0 s1 s2 s3] != 4} {
	    error "salt must be 16 bytes"
	}

	set mlen [string length $message]

	if {($mlen % 16) != 0} {
	    error "message must be a multiple of 16 bytes"
	}

	set result ""

	for {set i 0} {$i < $mlen} {incr i 16} {
	    if {[binary scan $message @[set i]iiii x0 x1 x2 x3] != 4} {
		error "oops"
	    }

	    set x0 [expr {($x0 + 0x100000000) % 0x100000000}]
	    set x1 [expr {($x1 + 0x100000000) % 0x100000000}]
	    set x2 [expr {($x2 + 0x100000000) % 0x100000000}]
	    set x3 [expr {($x3 + 0x100000000) % 0x100000000}]

	    set d  [intDecrypt $x0 $x1 $x2 $x3]

	    set d0 [lindex $d 0]
	    set d1 [lindex $d 1]
	    set d2 [lindex $d 2]
	    set d3 [lindex $d 3]

	    set c0 [expr {(($d0 ^ $s0) + 0x100000000) % 0x100000000}]
	    set c1 [expr {(($d1 ^ $s1) + 0x100000000) % 0x100000000}]
	    set c2 [expr {(($d2 ^ $s2) + 0x100000000) % 0x100000000}]
	    set c3 [expr {(($d3 ^ $s3) + 0x100000000) % 0x100000000}]

	    set s0 $x0
	    set s1 $x1
	    set s2 $x2
	    set s3 $x3

	    append result [binary format iiii $c0 $c1 $c2 $c3]
	}

	set salt [binary format iiii $s0 $s1 $s2 $s3]
	return $result
    }
}

package provide itwofish 0.2

