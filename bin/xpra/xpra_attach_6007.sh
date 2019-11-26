#!/bin/sh
PATH=/bin:/sbin export PATH
PYTHONPATH=/opt/xpra/users/system/xpra-2.3.2/install/lib/python:/opt/xpra/users/system/xpra-2.3.2/install/lib64/python export PYTHONPATH
PORT=6007
OPDT=opdt199
ps -ef|grep xpra | grep :$PORT |grep -v grep || /opt/xpra/users/system/xpra-2.3.2/install/bin/xpra attach ssh:claeyje@opvmwstsx11:$PORT &
