if {[file exists twofish.tcl]} {
    source twofish.tcl
}

package require Itcl
package require Tcl 8.4
package require tcltest
package require itwofish

proc h2b {hex} {
    return [binary format H* $hex]
}

proc b2h {bin} {
    binary scan $bin H* dummy
    return $dummy
}

#
# Twofish ECB test vectors, from http://www.schneier.com/code/ecb_ival.txt
# key bytes, clear bytes, cipher bytes
#

set testVectors {
    00000000000000000000000000000000 00000000000000000000000000000000 9F589F5CF6122C32B6BFEC2F2AE8C35A
    0123456789ABCDEFFEDCBA98765432100011223344556677 00000000000000000000000000000000 CFD1D2E5A9BE9CDF501F13B892BD2248
    0123456789ABCDEFFEDCBA987654321000112233445566778899AABBCCDDEEFF 00000000000000000000000000000000 37527BE0052334B89F0CFCCAE87CFA20

    00000000000000000000000000000000 00000000000000000000000000000000 9F589F5CF6122C32B6BFEC2F2AE8C35A
    00000000000000000000000000000000 9F589F5CF6122C32B6BFEC2F2AE8C35A D491DB16E7B1C39E86CB086B789F5419
    9F589F5CF6122C32B6BFEC2F2AE8C35A D491DB16E7B1C39E86CB086B789F5419 019F9809DE1711858FAAC3A3BA20FBC3
    D491DB16E7B1C39E86CB086B789F5419 019F9809DE1711858FAAC3A3BA20FBC3 6363977DE839486297E661C6C9D668EB
    019F9809DE1711858FAAC3A3BA20FBC3 6363977DE839486297E661C6C9D668EB 816D5BD0FAE35342BF2A7412C246F752
    6363977DE839486297E661C6C9D668EB 816D5BD0FAE35342BF2A7412C246F752 5449ECA008FF5921155F598AF4CED4D0
    816D5BD0FAE35342BF2A7412C246F752 5449ECA008FF5921155F598AF4CED4D0 6600522E97AEB3094ED5F92AFCBCDD10
    5449ECA008FF5921155F598AF4CED4D0 6600522E97AEB3094ED5F92AFCBCDD10 34C8A5FB2D3D08A170D120AC6D26DBFA
    6600522E97AEB3094ED5F92AFCBCDD10 34C8A5FB2D3D08A170D120AC6D26DBFA 28530B358C1B42EF277DE6D4407FC591
    34C8A5FB2D3D08A170D120AC6D26DBFA 28530B358C1B42EF277DE6D4407FC591 8A8AB983310ED78C8C0ECDE030B8DCA4


    000000000000000000000000000000000000000000000000 00000000000000000000000000000000 EFA71F788965BD4453F860178FC19101
    000000000000000000000000000000000000000000000000 EFA71F788965BD4453F860178FC19101 88B2B2706B105E36B446BB6D731A1E88
    EFA71F788965BD4453F860178FC191010000000000000000 88B2B2706B105E36B446BB6D731A1E88 39DA69D6BA4997D585B6DC073CA341B2
    88B2B2706B105E36B446BB6D731A1E88EFA71F788965BD44 39DA69D6BA4997D585B6DC073CA341B2 182B02D81497EA45F9DAACDC29193A65
    39DA69D6BA4997D585B6DC073CA341B288B2B2706B105E36 182B02D81497EA45F9DAACDC29193A65 7AFF7A70CA2FF28AC31DD8AE5DAAAB63
    182B02D81497EA45F9DAACDC29193A6539DA69D6BA4997D5 7AFF7A70CA2FF28AC31DD8AE5DAAAB63 D1079B789F666649B6BD7D1629F1F77E
    7AFF7A70CA2FF28AC31DD8AE5DAAAB63182B02D81497EA45 D1079B789F666649B6BD7D1629F1F77E 3AF6F7CE5BD35EF18BEC6FA787AB506B
    D1079B789F666649B6BD7D1629F1F77E7AFF7A70CA2FF28A 3AF6F7CE5BD35EF18BEC6FA787AB506B AE8109BFDA85C1F2C5038B34ED691BFF
    3AF6F7CE5BD35EF18BEC6FA787AB506BD1079B789F666649 AE8109BFDA85C1F2C5038B34ED691BFF 893FD67B98C550073571BD631263FC78
    AE8109BFDA85C1F2C5038B34ED691BFF3AF6F7CE5BD35EF1 893FD67B98C550073571BD631263FC78 16434FC9C8841A63D58700B5578E8F67


    0000000000000000000000000000000000000000000000000000000000000000 00000000000000000000000000000000 57FF739D4DC92C1BD7FC01700CC8216F
    0000000000000000000000000000000000000000000000000000000000000000 57FF739D4DC92C1BD7FC01700CC8216F D43BB7556EA32E46F2A282B7D45B4E0D
    57FF739D4DC92C1BD7FC01700CC8216F00000000000000000000000000000000 D43BB7556EA32E46F2A282B7D45B4E0D 90AFE91BB288544F2C32DC239B2635E6
    D43BB7556EA32E46F2A282B7D45B4E0D57FF739D4DC92C1BD7FC01700CC8216F 90AFE91BB288544F2C32DC239B2635E6 6CB4561C40BF0A9705931CB6D408E7FA
    90AFE91BB288544F2C32DC239B2635E6D43BB7556EA32E46F2A282B7D45B4E0D 6CB4561C40BF0A9705931CB6D408E7FA 3059D6D61753B958D92F4781C8640E58
    6CB4561C40BF0A9705931CB6D408E7FA90AFE91BB288544F2C32DC239B2635E6 3059D6D61753B958D92F4781C8640E58 E69465770505D7F80EF68CA38AB3A3D6
    3059D6D61753B958D92F4781C8640E586CB4561C40BF0A9705931CB6D408E7FA E69465770505D7F80EF68CA38AB3A3D6 5AB67A5F8539A4A5FD9F0373BA463466
    E69465770505D7F80EF68CA38AB3A3D63059D6D61753B958D92F4781C8640E58 5AB67A5F8539A4A5FD9F0373BA463466 DC096BCD99FC72F79936D4C748E75AF7
    5AB67A5F8539A4A5FD9F0373BA463466E69465770505D7F80EF68CA38AB3A3D6 DC096BCD99FC72F79936D4C748E75AF7 C5A3E7CEE0F1B7260528A68FB4EA05F2
    DC096BCD99FC72F79936D4C748E75AF75AB67A5F8539A4A5FD9F0373BA463466 C5A3E7CEE0F1B7260528A68FB4EA05F2 43D5CEC327B24AB90AD34A79D0469151
}

set testNum 0
set passed 0
set failed 0

if {[llength $argv] == 0} {
    foreach {key clear cipher} $testVectors {
	incr testNum
	set engine [itwofish::ecb \#auto [h2b $key]]
	set encrypted [$engine encryptBlock [h2b $clear]]
	set decrypted [$engine decryptBlock $encrypted]
	itcl::delete object $engine
	if {![string equal -nocase $cipher [b2h $encrypted]]} {
	    puts "varkey-$testNum: encryption failed: [b2h $encrypted] != $cipher"
	    incr failed
	} elseif {![string equal -nocase $clear [b2h $decrypted]]} {
	    puts "varkey-$testNum: decryption failed: [b2h $decrypted] != $clear"
	    incr failed
	} else {
	    puts "varkey-$testNum: passed"
	    incr passed
	}
    }

    exit 0
}

#
# Test the implementation akainst the known-answer tests published on
# Bruce Schneier's Website.
#

set filename [lindex $argv 0]
set file [open $filename]

#
# Expected input:
#
# I=<nn>   - test number
# KEY=...  - key to use, in hex
# PT=...   - plain text, in hex
# CT=...   - cipher text, in hex
# IV=...   - initialization vector, for CBC mode
#

set keysize 0
set cbcenc 0
set goti 0
set gotiv 0
set gotmc 0

while {![eof $file]} {
    set line [string trim [gets $file]]

    switch -glob -- $line {
	"Monte Carlo Test" {
	    #
	    # The mctInner constant that was used in tst2fish.c to generate
	    # the file that we are testing against. The reference code
	    # sets this to 100, but the published files seem like they
	    # were generated with a setting of 10000.
	    #
	    set mctInner 10000
	    set gotmc 1
	}
	"*CBC*ENCRYPTION*" {
	    #
	    # The CBC tests are not reversible, i.e., we can not decrypt
	    # the text that was encrypted, or vice versa. Therefore, the
	    # direction diven in the file's header is significant.
	    #
	    set cbcenc 1
	}
	KEYSIZE=* {
	    set keysize [string range $line 8 end]
	}
	I=* {
	    set i [string range $line 2 end]
	    set goti 1
	}
	KEY=* {
	    set key [string range $line 4 end]
	}
	IV=* {
	    set iv [string range $line 3 end]
	    set gotiv 1
	}
	PT=* {
	    set pt [string range $line 3 end]
	}
	CT=* {
	    set ct [string range $line 3 end]
	}
    }

    if {$line eq "" && $goti} {
	# run test

	incr testNum
	set testname "$filename-$keysize-$testNum"

	if {$gotiv && $gotmc} {
	    #
	    # Monte Carlo Test, CBC mode
	    #

	    set engine [itwofish::cbc \#auto [h2b $key] [h2b $iv]]

	    if {$cbcenc} {
		set tpt [h2b $pt]
		set tct [h2b $iv]

		for {set i 0} {$i < $mctInner} {incr i} {
		    set ctPrev $tct
		    set tct [$engine encrypt $tpt]
		    set tpt $ctPrev
		}

		set encrypted $tct
		set decrypted [h2b $pt]
	    } else {
		set tct [h2b $ct]

		for {set i 0} {$i < $mctInner} {incr i} {
		    set tct [$engine decrypt $tct]
		}

		set encrypted [h2b $ct]
		set decrypted $tct
	    }

	    itcl::delete object $engine
	} elseif {$gotiv} {
	    #
	    # CBC mode test
	    #

	    set engine [itwofish::cbc \#auto [h2b $key] [h2b $iv]]
	    set encrypted [$engine encrypt [h2b $pt]]
	    $engine configure -salt [h2b $iv]
	    set decrypted [$engine decrypt $encrypted]
	    itcl::delete object $engine
	} elseif {$gotmc} {
	    #
	    # Monte Carlo Test, ECB mode
	    #

	    set engine [itwofish::ecb \#auto [h2b $key]]
	    set data [h2b $pt]

	    for {set i 0} {$i < $mctInner} {incr i} {
		set data [$engine encryptBlock $data]
	    }

	    set encrypted $data

	    for {set i 0} {$i < $mctInner} {incr i} {
		set data [$engine decryptBlock $data]
	    }

	    set decrypted $data
	    itcl::delete object $engine
	} else {
	    #
	    # ECB mode test
	    #

	    set engine [itwofish::ecb \#auto [h2b $key]]
	    set encrypted [$engine encryptBlock [h2b $pt]]
	    set decrypted [$engine decryptBlock $encrypted]
	    itcl::delete object $engine
	}

	if {![string equal -nocase $ct [b2h $encrypted]]} {
	    # encrypted text does not match expectation
	    puts "$testname: encryption failed: [b2h $encrypted] != $ct"
	    incr failed
	} elseif {![string equal -nocase $pt [b2h $decrypted]]} {
		# decrypted text does not match original plaintext
	    puts "$testname: decryption failed: [b2h $decrypted] != $pt"
	    incr failed
	} else {
	    puts "$testname: passed"
	    incr passed
	}

	set goti 0
	set gotiv 0
    }
}


if {0} {
    cd /Frank/soft/gorilla/twofish
    source itwofish.tcl
    set t [itwofish::itwofish \#auto [h2b 0123456789ABCDEFFEDCBA9876543210]]
    set e [$t encryptBlock 0123456789abcdef]
    set d [$t decryptBlock $e]
}

