#
# Test vectors by Eric Young
# http://www.schneier.com/code/vectors.txt
#

package require Itcl
package require Tcl 8.4
package require iblowfish

proc h2b {hex} {
    return [binary format H* $hex]
}

proc b2h {bin} {
    binary scan $bin H* dummy
    return $dummy
}

#
# ecb test data; key bytes, clear bytes, cipher bytes
#

set testVectors {
    0000000000000000 0000000000000000 4EF997456198DD78
    FFFFFFFFFFFFFFFF FFFFFFFFFFFFFFFF 51866FD5B85ECB8A
    3000000000000000 1000000000000001 7D856F9A613063F2
    1111111111111111 1111111111111111 2466DD878B963C9D
    0123456789ABCDEF 1111111111111111 61F9C3802281B096
    1111111111111111 0123456789ABCDEF 7D0CC630AFDA1EC7
    0000000000000000 0000000000000000 4EF997456198DD78
    FEDCBA9876543210 0123456789ABCDEF 0ACEAB0FC6A0A28D
    7CA110454A1A6E57 01A1D6D039776742 59C68245EB05282B
    0131D9619DC1376E 5CD54CA83DEF57DA B1B8CC0B250F09A0
    07A1133E4A0B2686 0248D43806F67172 1730E5778BEA1DA4
    3849674C2602319E 51454B582DDF440A A25E7856CF2651EB
    04B915BA43FEB5B6 42FD443059577FA2 353882B109CE8F1A
    0113B970FD34F2CE 059B5E0851CF143A 48F4D0884C379918
    0170F175468FB5E6 0756D8E0774761D2 432193B78951FC98
    43297FAD38E373FE 762514B829BF486A 13F04154D69D1AE5
    07A7137045DA2A16 3BDD119049372802 2EEDDA93FFD39C79
    04689104C2FD3B2F 26955F6835AF609A D887E0393C2DA6E3
    37D06BB516CB7546 164D5E404F275232 5F99D04F5B163969
    1F08260D1AC2465E 6B056E18759F5CCA 4A057A3B24D3977B
    584023641ABA6176 004BD6EF09176062 452031C1E4FADA8E
    025816164629B007 480D39006EE762F2 7555AE39F59B87BD
    49793EBC79B3258F 437540C8698F3CFA 53C55F9CB49FC019
    4FB05E1515AB73A7 072D43A077075292 7A8E7BFA937E89A3
    49E95D6D4CA229BF 02FE55778117F12A CF9C5D7A4986ADB5
    018310DC409B26D6 1D9D5C5018F728C2 D1ABB290658BC778
    1C587F1C13924FEF 305532286D6F295A 55CB3774D13EF201
    0101010101010101 0123456789ABCDEF FA34EC4847B268B2
    1F1F1F1F0E0E0E0E 0123456789ABCDEF A790795108EA3CAE
    E0FEE0FEF1FEF1FE 0123456789ABCDEF C39E072D9FAC631D
    0000000000000000 FFFFFFFFFFFFFFFF 014933E0CDAFF6E4
    FFFFFFFFFFFFFFFF 0000000000000000 F21E9A77B71C49BC
    0123456789ABCDEF 0000000000000000 245946885754369A
    FEDCBA9876543210 FFFFFFFFFFFFFFFF 6B5C5A9C5D9E0A5A
}

set testNum 0
set passed 0
set failed 0

foreach {key clear cipher} $testVectors {
    incr testNum
    set engine [iblowfish::ecb \#auto [h2b $key]]
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

#
# set key tests; fixed cleartext, variable key length
#

set key [h2b "F0E1D2C3B4A5968778695A4B3C2D1E0F0011223344556677"]
set clear [h2b "FEDCBA9876543210"]
set cipher {
    F9AD597C49DB005E E91D21C1D961A6D6 E9C2B70A1BC65CF3 BE1E639408640F05
    B39E44481BDB1E6E 9457AA83B1928C0D 8BB77032F960629D E87A244E2CC85E82
    15750E7A4F4EC577 122BA70B3AB64AE0 3A833C9AFFC537F6 9409DA87A90F6BF2
    884F80625060B8B4 1F85031C19E11968 79D9373A714CA34F 93142887EE3BE15C
    03429E838CE2D14B A4299E27469FF67B AFD5AED1C1BC96A8 10851C0E3858DA9F
    E6F51ED79B9DB21F 64A6E14AFD36B46F 80C7D7D45A5479AD 05044B62FA52D080
}

set testNum 0

for {set i 0} {$i < [string length $key]} {incr i} {
    incr testNum
    set engine [iblowfish::ecb \#auto [string range $key 0 $i]]
    set encrypted [$engine encryptBlock $clear]
    set decrypted [$engine decryptBlock $encrypted]
    itcl::delete object $engine
    if {![string equal -nocase [lindex $cipher $i] [b2h $encrypted]]} {
	puts "setkey-$testNum: encryption failed: [b2h $encrypted] != [lindex $cipher $i]"
	incr failed
    } elseif {![string equal -nocase [b2h $clear] [b2h $decrypted]]} {
	puts "setkey-$testNum: decryption failed: [b2h $decrypted] != [b2h $clear]"
	incr failed
    } else {
	puts "setkey-$testNum: passed"
	incr passed
    }
}

#
# chaining mode test data
#

set key [h2b "0123456789ABCDEFF0E1D2C3B4A59687"]
set iv [h2b "FEDCBA9876543210"]
set clear [h2b "37363534333231204E6F77206973207468652074696D6520666F722000"]
set cbccipher [h2b "6B77B4D63006DEE605B156E27403979358DEB9E7154616D959F1652BD5FF92CC"]
set clearlen [string length $clear]

set testNum 0
set engine [iblowfish::cbc \#auto $key $iv]
set encrypted [$engine encrypt $clear]
$engine configure -salt $iv
set decrypted [$engine decrypt $encrypted]
set decrypted [string range $decrypted 0 [expr {$clearlen - 1}]]
itcl::delete object $engine
if {![string equal -nocase [b2h $cbccipher] [b2h $encrypted]]} {
    puts "chaining-$testNum: encryption failed: [b2h $encrypted] != [b2h $cbccipher]"
    incr failed
} elseif {![string equal -nocase [b2h $clear] [b2h $decrypted]]} {
    puts "chaining-$testNum: decryption failed: [b2h $decrypted] != [b2h $clear]"
    incr failed
} else {
    puts "chaining-$testNum: passed"
    incr passed
}

puts "$passed tests passed, $failed tests failed."
