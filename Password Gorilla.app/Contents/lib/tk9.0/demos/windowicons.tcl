# windowicons.tcl --
#
# This demonstration script showcases the wm iconphoto and wm iconbadge commands.
#

if {![info exists widgetDemo]} {
    error "This script should be run from the \"widget\" demo."
}

set w .windowicons
destroy $w
toplevel $w
wm title $w "Window Icon Demonstration"
positionWindow $w

## See Code / Dismiss buttons
pack [addSeeDismiss $w.buttons $w] -side bottom -fill x

image create photo icon -data {
    iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABGdBTUEAALGP
    C/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3Cc
    ulE8AAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAArQNAAK0DQEdFIm+AAAJ
    QElEQVRYw+WXW2xdV5nHf/ty7lcf2/FxYsdOnMSNC0HTpDiRKJWAQjWCEQNU
    SEAFfUOiQqrEC2+IxwpemDLSzNBBCCQeQEKqRJgBSikiuGlN22TqhsR27OPL
    8eWc43Pdt7X22osHHydOm4FBPM6Slr69paX9/32Xtb614f/7MP6vC3O5f8L3
    G7HJyZPHBwfz5wrF7HQ6nRwxLTOhQuU4PW+z3eq9Xa+33rq9cms7k8pHjvfS
    3w8wOfk52u1u8oHpiUff897JJ8+dO/nI6LHho6OjQ3ahkMYwTTZ2O2zXutS3
    G/7ayubq7Vtr/7Ve2f7RytLam4ViXq1t/vRvB0ilPsjzz3+LZ5/9j7MzM5Nf
    /8hj5//5H97/YNbK5hkfTFLMxAEQQvD766v0yBGIEBEEuPUGi9dv7lx77cb3
    Vm9vfqc0WNi9evUKWr/xLh3rfuLj45+l0bjM7m768U98/OJ/fulLH/3wiemx
    eCafxRcKw7TJxKC+12RpbYdAx7HsOCrSRNpg+sQQj1w8nS0N5h8JAvm+rWr9
    9ZmZB2qWdZq9vWt/GWBm5im+9rUn6HRGPv7EE4/++2P/eOFkV0FkJTDQgCaX
    TbO1tcV2R2EmCxBJQixs2+R9EwV00MFAceJE2ZiZOT7VaTsPLyxU5orFTK1c
    fphq9bX7A8zOfoV8Ps3c3NsXPvWpD37vc5//0ETNt8gNjDAzlsdAE0vliTCR
    xEhnC2CaRIZNMmZiaonv9mh1PcrDJQZzCfK5OGNjQ8e2tvZO37y5+ctk0naq
    1fn7A4yOnmd5uVp4/PGHn/vylz8xe+zoEIP5JAMpA0OHeK6DG4TEk2li8Tha
    QxRpIg0q6DGUNjg6UuLYSInhYoYoigiCgHQ6TrGYnlpd3Q1ffvk3L128+ITe
    2Hj1XoBLl55menqcbDb1haeeevyrDz102tJaE7ctLBMqG1X23Ag7kcKOJzAA
    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
    UHVibGljIERvbWFpbiBEZWRpY2F0aW9uIGh0dHA6Ly9jcmVhdGl2ZWNvbW1v
    bnMub3JnL3B1YmxpY2RvbWFpbi96ZXJvLzEuMC/G4735AAAAIXRFWHRDcmVh
    dGlvbiBUaW1lADIwMTAtMDMtMjlUMDg6MDg6MzD47LxwAAAAJXRFWHRkYXRl
    OmNyZWF0ZQAyMDIxLTA4LTE1VDIwOjU0OjM5LTA0OjAwNBT3DQAAACV0RVh0
    ZGF0ZTptb2RpZnkAMjAyMS0wOC0xNVQyMDo1NDoxMS0wNDowMDSDBqsAAADI
    elRYdERlc2NyaXB0aW9uAAAY042OwQqCQBCGn6B3GOy+Cl0qTAjEc1HRJVhW
    HXUrd2pmLXr7tDrVpcMP838w/F+wxxxyprsgB2ALclAxtRAbaBirRdB4f5mH
    oTeuJlUxYoly8nRRxHW4HahO30SvmI5Y+CCBF4dPhzg0CYwOLs45GdKfG+sK
    hBuy2H4xUlM1i76+BhcBwwirLj/bAlJqjXXzP9UyxmuHzp8feiknLPW6Q/H9
    moy3yK1oqvROUE2yH99suX45PwEyf2MTOoCNrQAAABl0RVh0U29mdHdhcmUA
    d3d3Lmlua3NjYXBlLm9yZ5vuPBoAAABWdEVYdFNvdXJjZQBodHRwczovL29w
    ZW5jbGlwYXJ0Lm9yZy9kZXRhaWwvMzUyMzMvdGFuZ28taW5ldHJuZXQtd2Vi
    LWJyb3dzZXItYnktd2Fyc3phd2lhbmth5nAuRgAAACB0RVh0VGl0bGUAdGF
    uZ28gaW5ldHJuZXQgd2ViIGJyb3dzZXLyr62TAAAAAElFTkSuQmCC
}

set ::tk::icons::base_icon(.) icon

# Create a copy of the image just created, magnified according to the
# display's DPI scaling level.  Since the zooom factor must be an integer,
# the copy will only be effectively magnified if $tk::scalingPct >= 200.
image create photo icon2
icon2 copy icon -zoom [expr {$tk::scalingPct / 100}]

pack [button $w.i -text "Set Window Icon to Globe" -image icon2 \
	-compound top -command {wm iconphoto . icon}] -fill x -padx 3p
pack [button $w.b -text "Set Badge to 3" -command {wm iconbadge . 3}] \
	-fill x -padx 3p
pack [button $w.e -text "Set Badge to 11" -command {wm iconbadge . 11}] \
	-fill x -padx 3p
pack [button $w.f -text "Reset Badge" -command {wm iconbadge . ""}] \
	-fill x -padx 3p
