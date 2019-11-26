#!/usr/bin/env expect

proc slurp {file} {
    set fh [open $file r]
    set ret [read $fh]
    close $fh
    return $ret
}

set iplist [slurp iplist.txt]

puts -nonewline $iplist
