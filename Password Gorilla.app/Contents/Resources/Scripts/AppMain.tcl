# AppMain.tcl - Entry point for Password Gorilla macOS app bundle
set contentsDir [file normalize [file join [file dirname [info nameofexecutable]] ..]]
set env(TCLLIBPATH) [file join $contentsDir lib]
::tcl::tm::add [file join $contentsDir lib tcl9 9.0]
source [file join $contentsDir Resources sources gorilla.tcl]
