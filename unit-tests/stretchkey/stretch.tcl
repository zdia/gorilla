# Developer version for PWGorilla's stretchkey extension
#
# TODO: modify to create a stretch.test file
#

proc hex { str } {
  binary scan $str H* hex
  return $hex
}

proc computeStretchedKey_tcl { passwordsalt iterations blocksize pvar_in} {
  # upvar $pvar_in pvar

  set token [sha2::SHA256Init]
  sha2::SHA256Update $token $passwordsalt
  set Xi [sha2::SHA256Final $token]
puts "Xi [hex $Xi]"

  set blocks [ expr { $iterations / $blocksize } ]
  for {set j 0} {$j < $blocks} {incr j} {
    for {set i 0} {$i < $blocksize} {incr i} {
      set Xi [sha2::sha256 -bin $Xi]
    }
    set pvar [ expr { 100 * $j * $blocksize / $iterations } ]
  }
# #
  set remain [ expr {$iterations - ($j * $blocksize) } ]
# puts "remain: $remain Xi [hex $Xi]"
  for {set i 0} {$i < $remain} {incr i} {
    set Xi [sha2::sha256 -bin $Xi]
  }
  set pvar 100

  # for {set j 0} {$j < $iterations} {incr j} {
      # set Xi [sha2::sha256 -bin $Xi]
  # }
  return $Xi
}

proc pvarCallback {name1 name2 op} {
  puts -nonewline .
}

proc load-extension { folder extension } {
  #ruff
  # loads a Tcl extension depending on the existing platform
  #
  # folder - contains the platform dependent subfolders
  # extension - name of extension to be loaded
  #
  # returns 1 if extension is loaded elsewise 0
  #

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

  set lib [ file join $::gorilla::Dir $folder $extension-$os-$machine[ info sharedlibextension ] ]

  if { [ catch { load $lib } ] } {
    # puts stderr "Using Tcl code only"
    return 0
  }

  return 1
}

# ----------------------------------------------------------------------
# main
# ----------------------------------------------------------------------

package require sha256

load [pwd]/stretchkey.so

set iter 4096
set blocksize 2048
set salt 12345678901234567890123456789012
set password sha256

puts "-----------------------------------------------"
puts "Bench for sha256 stretchkey"
puts "iterations:\t$iter  "
puts "blocksize:\t$blocksize"
puts "-----------------------------------------------"
puts "Tcl wrapped:"

set start [ clock milliseconds ]
set hashResult [computeStretchedKey_tcl $password$salt $iter $blocksize pvar]
puts "elapsed time: [ expr { [ clock milliseconds ] - $start } ] ms"
puts "result=[hex $hashResult]"

puts "\nPure C:"

trace add variable pvar write pvarCallback

set start [ clock milliseconds ]
# puts "size=[string length $password$salt]"
puts "\nresult=[hex [computeStretchedKey_c $password$salt $iter $blocksize "pvar"]]"
puts "elapsed time: [ expr { [ clock milliseconds ] - $start } ] ms"
# puts "pvar: $pvar"

# ------------------ Todo ----------------------
# set acceleration(stretchkey) [load-extension sha256c stretchkey]

# internal check for load status with:
# if { gorilla::extension(stretchkey) } {
    # action
# }
# we have at initialization time:
# array set gorilla::extension [list stretchkey 0 sha256c 0 twofish 0]

