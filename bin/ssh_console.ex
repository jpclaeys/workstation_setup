#!/usr/bin/expect -f
set server [lindex $argv 0]
set pass [lindex $argv 1]
log_user 0
spawn -noecho ssh $server -l root -t
match_max 100000
expect "*?assword:*"
send -- "$pass\r"
send -- "exit\r"
interact
