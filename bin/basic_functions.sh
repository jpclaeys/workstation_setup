# Basic functions

function executeCMDs () 
{
    local CMDS i
    CMDS=("$@")
    echo "[-] Commands that will be executed:"
    i=0
    while [ $i -lt ${#CMDS[@]} ]
    do 
        echo "[$i] ${CMDS[$i]}"
        i=$((i+1))
    done
#   c=$(ckkeywd -Q -p "[?] Confirm execution on host `hostname`" yes no skip )
    printf "[?] Confirm execution on host `hostname` [yes no skip]: "; read ans
    c=`echo $ans | awk '{print substr(tolower($0),0,1)}'`;
    case "$c" in 
        'y')
            i=0
            while [ $i -lt ${#CMDS[@]} ]
            do 
                echo "[$i] Execute: ${CMDS[$i]}"
                eval ${CMDS[$i]}
                rc=$?;
                if [ $rc -ne 0 ]; then
#                   c=$(ckkeywd -Q -p "  [$i] non zero return code ($rc), continue anyway ?" yes no)
                    printf "[$i] non zero return code ($rc), continue anyway  [yes no]: "; read ans
                    c=`echo $ans | awk '{print substr(tolower($0),0,1)}'`;
                    if [ "$c" = "n" ]; then
                        break;
                    fi
                fi
                i=$((i+1))
            done
            return 0
        ;;
        'n')
            return 2
        ;;
        's')
            return 3
        ;;
        *)
            return 1
        ;;
    esac
}

function check_input ()
{
if [ $# -eq 0 ]; then
  errmsg "Please provide hostname"
  return 1
fi
}

function check_root ()
{
if [ `whoami` != "root" ]; then 
  errmsg "Need to be root"
  return 1
fi
}

function lower ()
{
echo $@ | tr '[:upper:]' '[:lower:]'
}

function upper ()
{
echo $@ | tr '[:lower:]' '[:upper:]'
}

function check_file ()
{
if [ ! -f "$1" ]; then
   errmsg "File "$1" not found, exiting"
   return 1
fi
}

function validatehost ()
{
    local MYHOST
    check_input $@ || return 1
    MYHOST=`echo "$1" | tr '[:upper:]' '[:lower:]'`
    GETENTINFO=`getent hosts $MYHOST`
    if [ "$?" -eq 0 ]; then
        GETENTHOST=`echo $GETENTINFO | awk '{print $2}'| cut -d. -f1`
        if [ "$2" == "-v" ]; then
            if [ "$MYHOST" != "$GETENTHOST" ]; then
                msg "$MYHOST is an alias for $GETENTHOST"
            fi
            echo $GETENTHOST
        fi
        if [ "`uname -s`" == "SunOS" ]; then
           :; # ping -c1  $MYHOST 1  > /dev/null # ping not allowed anymore since switch from leased line to vpn
        else
            ping -c1 $MYHOST -w1 > /dev/null
        fi
        if [ $? -ne 0 ]; then
          [ "$2" != "-q" ] && errmsg "Host \"$MYHOST\" is not responding" && return 1
        fi
    else
        [ "$2" != "-q" ] && errmsg "Host \"$MYHOST\" is unknown" && return 1
    fi
}

function confirmexecution ()
{
  local MSG
  MSG=${@:-"Confirm execution"}
  read -p "[?] ${MSG} [yes no]: " ans
  c=`echo $ans | awk '{print substr(tolower($0),0,1)}'`
  if [ "$c" != "y" ]; then
      msg "Execution cancelled"
      return 1
  fi
}

function istargetwkshowald ()
{
#SOLARISWKSHOWALD=iceman:leech:phoenix:brother:beast
SOLARISWKSHOWALD=`wkshowald | sed 's/ /:/g'`
check_input $1 || return 1
case ":$SOLARISWKSHOWALD:" in
*:"$1":*)
if [ `uname -s` == "Linux" ]; then
  errmsg "You need to be on a workstation at Howald to connect on this system"
  return 1
fi
;;
esac
}

function s ()
{
#validatehost $1 || return 1
validatehost ${1##*@} || return 1
ssh -q $@
}

function definemypasswd ()
{
if [ -z "$mypasswd" -o "$1" == "-f" ]; then
  echo -n "password for `whoami`: "; stty -echo; read mypasswd; export mypasswd; stty echo; echo
fi
}

function defineproxy ()
{
#proxy_server=158.169.131.13:8012
proxy_server="psbru.ec.europa.eu"
proxy_port=8012
proxy_username=xopl262
proxy_password=hueRDv7
export {http,https,ftp}_proxy=http://$proxy_username:$proxy_password@$proxy_server:$proxy_port
}

[ "`uname -n`" != "satellite-pk" ] && defineproxy

function no_more_than_one ()
{
        if [ $# -gt 1 ];
        then
                echo "Please, Only One Argument"
                return 1
        fi
}

#Usefull for the function sr to check which OS before
function getOS ()
{
        no_more_than_one $@ || return 1
        validatehost $@ || return 1
        myOS=$(ssh $@ "uname")
#        echo $myOS
}

function myterminator ()
{
local TITLE
TITLE= && [ ! -z "$1" ] && TITLE="$@"
nohup terminator --geometry=1280x800 -T "$TITLE" &
}

function myterminator2 ()
{
local TITLE
TITLE= && [ ! -z "$1" ] && TITLE="$@"
nohup terminator --geometry=1280x800 -l 2terminals -T "$TITLE" &
}

function myterminator4 ()
{
local TITLE
TITLE= && [ ! -z "$1" ] && TITLE="$@"
nohup terminator --geometry=1280x800 -l 4terminals -T "$TITLE" &
}

function mychrome ()
{
nohup /usr/bin/google-chrome &
}

function screen_session_name ()
{
screen -ls | grep JPC | sed 's/\./ /' | awk '/'`ps -o ppid -p $$ --no-headers | xargs`'/{print $2}'
}

function screen_title ()
{
set_title `screen_session_name`
}

function cmdb_items ()
{
OPTS=`cmdb | cut -d"[" -f2 | sed "s:]::;s:|::g"|xargs`
for OPT in $OPTS
do
   echo -n "$OPT: " && cmdb $OPT | sed 1d | wc -l
done
}

function zone-where ()
{
if [ $# -eq 0 ]; then
   /usr/sbin/eeprom | /usr/bin/awk -F"=" '/banner=/ {print $NF}'
   else
   validatehost $@ || return 1
   s $1 /usr/sbin/eeprom | /usr/bin/awk -F"=" '/banner=/ {print $NF}'
fi
}

function sshkeypermissions ()
{
chmod 700 ~/.ssh
chmod 644 ~/.ssh/authorized_keys
chmod 644 ~/.ssh/known_hosts
chmod 644 ~/.ssh/config
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_dsa
chmod 644 ~/.ssh/id_dsa.pub
}
