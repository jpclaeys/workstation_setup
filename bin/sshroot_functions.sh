function sr ()
{
[ $# -eq 0 ] && srlocal && return 0
# getOS use check_input and validatehost
getOS $1 || return 1

case $myOS in 
  Linux*)
	  if [ $# -gt 1 ]
	  then
		  ssh_root_linux_exec $@
	  else 
		  ssh_root_linux $1 
	  fi
	  ;;
	
  SunOS*)
	  if [ $# -gt 1 ]
	  then
		  ssh_root_solaris_exec_filtered $@
	  else 
		  ssh_root_solaris $1 
	  fi
	  ;;

  *)
	  echo "Function was not set for this OS" && return 1
	  ;;
esac
}

function sre ()
{
# getOS use check_input and validatehost
getOS $1 || return 1

case $myOS in
  Linux*)
          ssh_root_linux_exec $@
          ;;

  SunOS*)
          ssh_root_solaris_exec_filtered $@
          ;;

  *)
          echo "Function was not set for this OS" && return 1
          ;;
esac
}

function srlocal ()
{
myOS=$(uname)
    case $myOS in
        Linux*)
            sudo -i
        ;;
        SunOS*)
            su_opsys_ux.ex
        ;;
        *)
            echo "Function was not set for this OS" && return 1
        ;;
    esac
}

function ssh_root_solaris ()
{
# connect to remote host as root
validatehost $1 || return 1
ssh_opsys_ux.ex $@ 
}

function ssh_root_solaris_exec ()
{
# execute cmd on remote host as root
validatehost $1 || return 1
ssh_opsys_ux_exit.ex $@
}

function ssh_root_solaris_exec_filtered ()
{
# execute sre cmd and remove first 5 lines as well as the last 2 lines of the output
validatehost $1 || return 1
ssh_root_solaris_exec $@ | sed '1,5d;$d'|sed '$d'
}

function ssh_root_linux ()
{
[ -z "$mypasswd" ] && definemypasswd
# connect to remote host as root
validatehost $1 || return 1
ssh_sudo_i.ex $@
}

function ssh_root_linux_exec ()
{
[ -z "$mypasswd" ] && definemypasswd
# execute cmd on remote host as root
validatehost $1 || return 1
ssh_sudo_i_exec_cmd.ex $@ | sed '1d;$d' | sed '$d'
}

function console ()
{
local HOST PWD
check_input $@ || return 1
# HOST=$1
HOST=`echo $1  | sed 's/-sc$//;s/$/-sc/'`
PWD=`echo $1 | awk '{print substr(toupper($0),0,3)}'`4ILOM
ssh_console.ex $HOST $PWD
}

