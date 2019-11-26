#!/usr/bin/expect -f
set server [lrange $argv 0 0]
set cmd [lrange $argv 1 9]
set name opsys_ux
set pass $name
log_user 0
spawn -noecho ssh $server -t su - $name
match_max 100000
expect "*?assword:*"
send -- "$pass\r"
log_user 0
send -- "stty -echo\r"
send -- "exec bash\r"
send -- ". ~claeyje/root_profile \r"
send -- "stty echo\r"
send -- "$cmd\r"
send -- "exit\r"
#send -- "\r"
interact
