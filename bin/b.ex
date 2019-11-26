#!/usr/bin/expect -f
set server [lrange $argv 0 0]
set pass [lrange $argv 1 0]
spawn -noecho ssh $server -t sudo -i
expect "*?assword?\r"
send -- "$pass\r"
interact 
send -- "\r"
expect eof
