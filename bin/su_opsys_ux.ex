#!/usr/bin/expect -f
set name opsys_ux
set pass $name
log_user 0
spawn -noecho su - $name
match_max 100000
expect "*?assword:*"
send -- "$pass\r"
send -- "exec bash\r"
send -- ". ~claeyje/root_profile 2> /dev/null \r"
send -- "\r"
interact
