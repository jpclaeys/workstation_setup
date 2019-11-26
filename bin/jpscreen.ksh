#!/bin/bash

CURDIR=` dirname $0`;# echo "Dirname:= $CURDIR"
FILENAME=`basename $0` ;# echo "Filename: $FILENAME"
CTYPE=`echo ${FILENAME#*_}| cut -d'.' -f1`;# echo "CTYPE:= $CTYPE"
SESSPREFIX="JPC_"
THISHOST=`uname -n | cut -d'-' -f2`
TSESS=`screen -ls | grep ${SESSPREFIX} | wc -l`
#if [[( "${CTYPE}" == "" ) || (( "${CTYPE}" != "putty" ) && ( "${CTYPE}" != "mobaxterm" ))]] 
#then 
#   echo "usage: [jpcscreen_putty.ksh|jpcscreen_mobaxterm]"
#   exit 1
#fi
#SCREENPROFILE=$CURDIR/.jpscreenrc_${CTYPE}
SCREENPROFILE=$CURDIR/.screenrc
if [ ! -f "$SCREENPROFILE" ]; then
  echo "mising file \"$SCREENPROFILE\", exiting ..."
  exit 1
  else
    echo "Using Screen resource file: $SCREENPROFILE"
fi

function validatesessionname ()
{
local NTOKEN=1
while [ $NTOKEN -eq 1 ]
do
        echo "What name do you want to give your session? [${SESSPREFIX}]"
        read SESSNAME
        echo ""
        if [ -z ${SESSNAME} ]; then
                echo "Please provide a session name"
        else
                SESSNAME=${SESSPREFIX}${SESSNAME#$SESSPREFIX}
                if [ `screen -ls | awk '/[0-9]\./ {print $1}'  | grep -c "\.$SESSNAME"` -ne 0 ]; then
                        echo "Name '$SESSNAME' already in use, please choose another one"
                else
                        NTOKEN=0
                fi
        fi
done
}

# create the screen resource file including the initial hosts connections
function createsessionrc ()
{
[ $# -eq 0 ] && return 1
CUSTOMSCRDIR=${CURDIR}/.screenrc
[ ! -d ${CUSTOMSCRDIR} ] && mkdir ${CUSTOMSCRDIR}
CUSTOMSCREENFILE=${CUSTOMSCRDIR}/${SESSNAME}.src
cp ${SCREENPROFILE} ${CUSTOMSCREENFILE}
CONNECTCMD=ssh
if [ $# -gt 0 ]; then
(echo screen -t $THISHOST 0
for H in $@;do
   echo screen -t "$H" $CONNECTCMD "root@$H"
done
echo "select 0") >> ${CUSTOMSCREENFILE}
SCREENPROFILE=${CUSTOMSCREENFILE}
fi
}

function createsession ()
{
#screen -dmS "${SESSNAME}" -c ${SCREENPROFILE} -fn -L
#sleep 1
#screen -S "${SESSNAME}"  -p 0 -X stuff "bash$(printf \\r)"
#sleep 1
#screen -S "${SESSNAME}"  -p 0 -X title "$THISHOST"
#sleep 1
#screen -r "${SESSNAME}"
screen -S "${SESSNAME}" -c ${SCREENPROFILE} -fn -L
}

if [ ${TSESS} -ne 0 ]; then
   NSESS=1
   for SESS in `screen -ls | grep ${SESSPREFIX} | awk '{print $1}' | sort -t . `
   do
      STATE=`screen -ls | grep ${SESS} | awk '{print $2}' | sed -e "s/(//g" -e "s/)//g"`
      echo "${NSESS}. $SESS   ${STATE}"  
      ASESS[${NSESS}]="${SESS}"
      let NSESS+=1
   done
   TOKEN=1
   while [ ${TOKEN} -eq 1 ]
   do
	if [ $TSESS -ne 1 ]; then
		echo "Select a session, or create a new one? (s)elect/(c)reate/(q)uit"
	else
		echo "Attach the session, or create a new one? (a)ttach/(c)reate/(q)uit"
	fi	
	read ANSWER
	case $ANSWER in
		c)
			validatesessionname
            # create initial hosts connections
            createsessionrc $@
			createsession
			TOKEN=0
            		;;
		s)
			TTOKEN=1
			while [ $TTOKEN -eq 1 ]
			do
			echo "Which session do you want to select?"
			read SELECTION
			echo ""
			if [ -z ${ASESS[${SELECTION}]} ]; then
				echo "Wrong session"
				INDEX=1
				while [ ! ${INDEX} -gt ${TSESS} ]
				do
					CSTATE=`screen -ls | grep ${ASESS[${INDEX}]} | awk '{print $2}' | sed -e "s/(//g" -e "s/)//g"`
					echo "${INDEX}. ${ASESS[${INDEX}]}   ${CSTATE}"
					let INDEX+=1
				done
			else
				CSESS="${ASESS[${SELECTION}]}"
				KCESS=`screen -ls | grep ${CSESS} | awk '{print $1}'`
				TTOKEN=0
			fi
			done
			screen -x -r ${CSESS}   # allows multiple attach to the same session
			TOKEN=0
			;;
		a)
			CSESS="${ASESS[${TSESS}]}"
			screen -d -r ${CSESS}
			TOKEN=0
			;;
		q)
			echo "Exiting ..."
			exit
            		;;
      esac
   done
else
	validatesessionname
        # create initial hosts connections
        createsessionrc $@
	createsession
	TOKEN=0
fi
