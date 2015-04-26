# Makefile for twofish2tcl.c

# Author: Richard Ellis
# Copyright 2015 Richard Ellis

# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation 51
# Franklin Street, Suite 500 Boston, MA 02110-1335

# Note - force i486 compilation on 32-bit systems so as to be most
# compatible with the largest number of CPUs likely to be running Gorilla. 
# This will cost some performance but it increases the compatibility of the
# resulting compiled shared object file.

# If you wish to recompile for your specific 32-bit architecture, simply
# change 'i486' below to the appropriate GCC arch name for your CPU,
# recompile, and replace the existing twofish.so within the apprirpiate
# *-ix86 directory for your OS

ARCH := $(shell getconf LONG_BIT)

ifeq ($(ARCH),32)
    CPU := -march=i486 -mtune=i486
endif

CFLAGS := -std=c99 -Wall -fPIC -O3 -fomit-frame-pointer \
          $(shell pkg-config --cflags tcl) -DUSE_TCL_STUBS $(CPU)

LDFLAGS := -fPIC -shared $(shell pkg-config --libs tcl) -ltclstub8.5

CC := gcc

.DEFAULT_GOAL := twofish2tcl.so

twofish2tcl.o: twofish2tcl.c tables.h Makefile
	$(CC) $(CFLAGS) -o twofish2tcl.o -c twofish2tcl.c

twofish2tcl.so: twofish2tcl.o
	$(CC) -o twofish2tcl.so twofish2tcl.o $(LDFLAGS)

.PHONY: clean
clean:
	rm -fv twofish2tcl.o twofish2tcl.so
