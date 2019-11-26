#!/usr/bin/expect -f
#exp_internal 1
set server [lindex $argv 0]
set pass $env(XYZ)
# puts server
# puts $pass
set timeout 1
log_user 0
stty -echo
spawn -noecho ssh $server -t sudo -i
match_max  1000
expect "*?assword?\r"
send -- "$pass\r"
stty echo
expect "#"
send -- "uname -a\r"
send -- "exit\r"
interact 
#expect eof
#wait
