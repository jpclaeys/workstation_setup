#!/usr/bin/expect -f
# grab the password
set user jp
set host brutus
stty -echo
send_user -- "Password for $user@$host: "
expect_user -re "(.*)\n"
send_user "\n"
stty echo
set pass $expect_out(1,string)
puts $pass
#... later
# send -- "$pass\r"
