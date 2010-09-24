To compile the sha256 extension, do the following:

1) Obtain a tclkit executable file for your platform and a
critcl2.kit file from http://www.equi4.com/tclkit/

2) In the sha1 directory of the Password Gorilla distribution,
execute the following command:

tclkit-linux-x86_64 critcl2.kit -pkg sha256c.tcl

Note, replace "tclkit-linux-x86_64" with the name of the tclkit
executable for your particular platform.

This will create a lib/ directory containing a sha256c/ directory.

2) move the sha256c/ directory to the sources/ directory
(i.e., place it adjacent to the sha1/ directory).


Note, the above assumes that your system has a working compiler
installed.  How to install a compiler if you do not already have one
installed is beyond the scope of this document.  Refer to the critcl
documentation for information on installing a compatible compiler for
windows, and refer to your distributions documentation for
installation of a compiler otherwise.
