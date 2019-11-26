#!/bin/sh
PATH=/bin:/sbin export PATH
PYTHONPATH=/opt/xpra/users/system/xpra-2.3.2/install/lib/python:/opt/xpra/users/system/xpra-2.3.2/install/lib64/python export PYTHONPATH
PORT=2000
OPDT=opdt199
ps -ef|grep xpra | grep :$PORT |grep -v grep || /opt/xpra/users/system/xpra-2.3.2/install/bin/xpra attach ssh:claeyje@opvmwstsx11:$PORT &
#ssh -X opvmwstsx11 "DISPLAY=:$PORT /usr/local/bin/rdesktop -z -B -x l -u 'publications\claeyje' -a 16 -D -g 1920x1200 -k fr-be $OPDT" &
# Start opdt on second screen
ssh -X opvmwstsx11 "DISPLAY=:$PORT /usr/local/bin/rdesktop -z -B -x l -u 'publications\claeyje' -a 16 -D -g 1920x1200+1920+0 -k fr-be $OPDT" &
