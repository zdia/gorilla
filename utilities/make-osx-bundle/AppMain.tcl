
if {[string first "-psn" [lindex $argv 0]] == 0} { set argv [lrange $argv 1 end]}

#console show

if [catch {source [file join [file dirname [info script]] gorilla.tcl]}] { puts $errorInfo}

