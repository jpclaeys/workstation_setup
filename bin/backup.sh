#!/bin/bash
cd $HOME
BACKUPTYPE=daily

SHORTFILESLIST='.bash_aliases .bash_profile .bashrc jpscreen.ksh .jpscreenrc_* .screenrc .gitrc .gitconfig .vimrc .ssh /home/claeyje/git/workstation_setup/bin fedora_setup wiki /home/claeyje/git/workstation_setup/doc /home/claeyje/git/workstation_setup/tpl .config/google-chrome/Default/Bookmarks bak/bookmarks* Desktop/*.desktop Pictures/*.*g /home/claeyje/git/workstation/config /home/claeyje/setup'
FULLFILESLIST="$SHORTFILESLIST doc_Oracle doc_IBM doc_RedHat Packages Documents log"

ME=`basename $0 .sh`
if [ "$ME" == "backup_full" ]; then
    BACKUPNAME="jpc_full"
    FILESLIST=$FULLFILESLIST
  else
    BACKUPNAME="jpc"
    FILESLIST=$SHORTFILESLIST
fi

if [ `date "+%d"` -eq 1 ]; then
  BACKUPTYPE=monthly
  elif
    [ `date "+%a"` = "Sun" ]; then
  BACKUPTYPE=weekly
fi

TIMESTAMP=`date "+%Y%m%d"`
BACKUPDIR=$HOME/bak
BACKUPFILE=${BACKUPDIR}/${BACKUPNAME}_${BACKUPTYPE}_${TIMESTAMP}.tgz

# echo "tar -zcf ${BACKUPFILE} ${FILESLIST}"

tar -zcf ${BACKUPFILE} ${FILESLIST} --exclude='*.iso'

# Tidy up
find ${BACKUPDIR} -iname "*daily*.tgz"   -ctime +7   -exec rm {} \;
find ${BACKUPDIR} -iname "*weekly*.tgz"  -ctime +30  -exec rm {} \;
find ${BACKUPDIR} -iname "*monthly*.tgz" -ctime +365 -exec rm {} \;

