#! /bin/sh
# the next line restarts using tclsh \
exec tclsh8.5 "$0" ${1+"$@"}

set myDir [file normalize [file dirname [info script]]]
set myDirDir [file normalize [file dirname $myDir]]

lappend auto_path $myDir
lappend auto_path [file join $myDirDir sha1]
lappend auto_path [file join $myDirDir blowfish]
lappend auto_path [file join $myDirDir twofish]

package require sha256
package require iblowfish
package require itwofish
package require pwsafe
package require base64

set b64testfile {
    QmWWZUVopydNWoFFyGLFAzrBGPOTn077gTBwQl5A+eNVJDil0K3p7xyKTgsq
    domg2GcDhHIID9HGO/NNxljIOeiYIsAV10xi9HadvqaKeR6qns3dkW3M19YA
    L6XSfvDLzAM3U51Q2CwY+56ValsIr93qTX8/XoeqXIXT0c/eWeYTdbihylVt
    te2gjTDqOmfITU66F8ZQ16fyUerdqHCfT+TOLeKU5FijLt5ga4sXhzbR1O7S
    Qgxt1BM0JFosViPeUcD+uRJrrZ6FQNFJn53LDtmWuGrlrg3Dnm4/7Ez3mp0h
    vBGSueusZbxHjfnomP8QX58ZPZLxUkdzJYkpIn6hkLw2HNiH++WlNDr78GKM
    eK2vkY1A5neoQn5XBWJnpET04W9g3Tl26xDR3Dpg/0Q/rdcc/d/aLonkMcyv
    SnoKuzP9DpLhleArYdbuilE+QUFZP/pqpxhdvSkXCUCGNqYL8QBjRglV1uIl
    u/4mPzomaU5y9TTr+ffQ4zcS4dAdaQMorXtyjoSAJEriJsYn8WWQm+mP26ws
    XyrJMc7BrW1ZIzBZQ5cIK/xTwSQGjZ1jxanRyltsbbnGT9Yq+Ai+6Wh9g/PJ
    yzLZTJGZr8nPNAupTyJ6MIoEFs9/LEsBou/mR04a0tgC4R+ZnKHh7rbgqPu2
    C6OPnyAyLhibuqYLVHLa78ZNcvfKj+b7mcmgj7sk9RVJySmAbIp0ZyE7BnQG
    GVnBTe5hL/YYHTFdPlsrTRuHN9upXOgEU84cmpOb8+HqScQfDyj6fSAh0a4w
    QgA35tCxjlVPfpk+heBdnz2L/j8MSVxIvLkkcRrCVUt0ohiTbKOIxtPGJfVt
    Dx50iEMj41CQrU5cqDnWHBfnCf1wm+Yr+GYJjnwbJRMrumox9earwppQmO+Y
    Vuej//btqHEiy0Oy+jm1FKep5+1LaNZHCRbfT4a8TSnX3cjormg9ZEd1ZxD6
    aL50DUM9ELUb6rgpwcwRn3KcmD5DNHrNG0N97fRA20hQ1bv0FCl+iuB4kv4t
    FnQlblnWmtvbYZx99gPCx2K0GIEmWPUL/qMIjjG/JvTH2YZf/PB/Pb7vOj48
    wwerNRTuRiEW2F0CQS2oJkokjmIBLesbrMCAxI12n6mdcF+gaMX+aNZfk8Aj
    W18iYvV7270k
}

set testfile [base64::decode $b64testfile]

set db [pwsafe::createFromString $testfile TESTKEY]
#pwsafe::dumpAllRecords $db stdout

set data [pwsafe::writeToString $db 3]
set db2 [pwsafe::createFromString $data TESTKEY]
pwsafe::dumpAllRecords $db2 stdout

itcl::delete object $db
