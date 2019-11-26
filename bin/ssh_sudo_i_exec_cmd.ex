#!/usr/bin/expect -f
#exp_internal 1
set server [lindex $argv 0]
set pass $env(mypasswd)
set cmd [lrange $argv 1 24]
# puts server
# puts $pass
# puts $cmd
set timeout 1
log_user 0
stty -echo
spawn -noecho ssh $server -t sudo -i
match_max  1000
expect -re ".*assword.*"
send -- "$pass\r"
stty echo
expect "#"
send -- "$cmd\r"
send -- "exit\r"
interact 
#expect eof
#wait
