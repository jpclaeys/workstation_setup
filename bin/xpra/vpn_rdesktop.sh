#!/bin/sh
PATH=/bin:/sbin export PATH
PYTHONPATH=/opt/xpra/users/system/xpra-2.3.2/install/lib/python:/opt/xpra/users/system/xpra-2.3.2/install/lib64/python export PYTHONPATH

#ssh -X opvmwstsx11 "/usr/local/bin/rdesktop -g 3200x1200 -f -k fr-be -a 16 -u 'publications\ferrarm' opsun06"

ps -ef|grep xpra | grep -v grep || /opt/xpra/users/system/xpra-2.3.2/install/bin/xpra attach ssh:ferrarm@opvmwstsx11:1003 &
ssh -X opvmwstsx11 "DISPLAY=:1003 /usr/local/bin/rdesktop -z -B -x l -u 'publications\ferrarm' -a 16 -D -g 3840x1144 -k fr-be opsun06"
