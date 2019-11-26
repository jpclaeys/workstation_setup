function rsbash () 
{ 
    export MYHOMES=opvmwstsx11:/home/claeyje/
    rsync -aP $MYHOMES/.bashrc ~
    rsync -aP $MYHOMES/.bash_profile ~
    rsync -aP $MYHOMES/.bash_aliases ~
    rsync -aP $MYHOMES/jpscreen.ksh ~
    DIRLIST="wiki bin tpl log doc Documents Downloads rhel7 doc_oasis2 .config/terminator"
    for DIR in $DIRLIST; do rsync -aP $MYHOMES/$DIR/ ~/$DIR; done
    . ~/.bashrc
}

function sshwks ()
{
check_input $@ || return 1
sshnokey -t $1 "bash --norc --noprofile"
}

