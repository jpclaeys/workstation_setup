#!/usr/bin/expect -f
set server [lrange $argv 0 0]
set cmd [lrange $argv 1 24]
set name opsys_ux
set pass $name
log_user 0
spawn -noecho ssh $server -t su - $name
match_max 100000
expect "*?assword:*"
send -- "$pass\r"
send -- "exec bash\r"
send -- ". ~claeyje/root_profile 2> /dev/null \r"
send -- "$cmd\r"
send -- "exit\r"
interact
