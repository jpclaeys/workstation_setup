#!/usr/bin/bash
export MYHOMES=opvmwstsx11:/home/claeyje/
rsync -aP $MYHOMES/.bashrc ~
rsync -aP $MYHOMES/.bash_profile ~
rsync -aP $MYHOMES/.bash_aliases ~
rsync -aP $MYHOMES/jpscreen.ksh ~
DIRLIST="wiki bin tpl log doc Documents Downloads Documentation perso rhel7 doc_oasis2 .config/terminator"
for DIR in $DIRLIST; do rsync -aP $MYHOMES/$DIR/ ~/$DIR; done
# copy xpra dir to opvmwstsx11
rsync -aP ~/bin/xpra/ opvmwstsx11:/home/claeyje/bin/xpra
