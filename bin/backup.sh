#!/bin/bash
cd $HOME
BACKUPTYPE=daily

SHORTFILESLIST='.bash_aliases .bash_profile .bashrc jpscreen.ksh .jpscreenrc_* .screenrc .gitrc .gitconfig .vimrc .ssh bin fedora_setup wiki doc tpl .config/google-chrome/Profile*/Bookmarks bak/Bookmarks_opdt Desktop/*.desktop Pictures/*.*g'
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
find ${BACKUPDIR} -iname "*daily*.tar.gz"   -ctime +7   -exec rm {} \;
find ${BACKUPDIR} -iname "*weekly*.tar.gz"  -ctime +30  -exec rm {} \;
find ${BACKUPDIR} -iname "*monthly*.tar.gz" -ctime +365 -exec rm {} \;

