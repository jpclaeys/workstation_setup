#!/usr/bin/bash
#--------------------------------------------------------------------------
# print functions
#==========================================================================

function prline ()
{
# $1: line lenght
# $2: line prefix/suffix (ex: +, =, !, or empty)
# $3: text position [l]eft or [c]enter
# $4...$n: message to print
  if [ $# -lt 4 ]; then
    errmsg "Usage: $FUNCNAME <width> <pre/suffix> <l|c> <message> "
    return
  fi
  local width width1 ws1 ws2 prefix pre_len pre post message position
  width=${1:-80}
  shift
  prefix=$1
  shift
  position=${1:-l}
  shift
  message="$@"
  if [ ${#prefix} -gt 0 ]; then
    pre_len=3
    pre=`printf "%*s>" $pre_len ''| tr ' ' $prefix`
    post=`printf "<%*s" $pre_len ''| tr ' ' $prefix`
    else
    pre="";post=""
  fi
  width1=$(($width-${#pre}-${#post}))
  if [ ${#message} -ge $width1 ]; then
    ws1=1
    ws2=1
  else
    if [ "$position" = "l" ]; then
        ws1=1
      else
        ws1=$((($width1-${#message})/2))
    fi
    ws2=$(($width1-${#message}-$ws1))
  fi
  printf "$pre%*s%s%*s$post\n" $ws1 ' ' "$message"  $ws2 ' '
}

separator()
{
# This one uses the printf command to print an empty field with a minimum field width of 20 characters. 
# The text is padded with spaces, since there is no text, you get 20 spaces. The spaces are then converted to - by the tr command.
# example: printf '%20s\n' | tr ' ' -

  local len char
  len=${1:-80}
  char=${2:-"+"}
  printf '%*s\n' $len ' ' | tr ' ' $char
}

function title ()
{
  local width=80
  separator $width
  prline $width "" c $@
  separator $width
}

function titlegreen ()
{
  setcolorgreen
  title "$@"
  resetcolor
}

function msg ()
{
  prline "" = l "$@"
}

function msgsep ()
{
separator 132
msg "$@"
}

function errmsg ()
{
  setcolorredinverted
  msg "$@"
  resetcolor
}

function green ()
{
  echo -e "\e[1;32m$@\e[0m"
}

function red ()
{
  echo -e "\e[1;31m$@\e[0m"
}

function bold ()
{
  echo -e "\e[1m$@\e[0m"
}

function msgred ()
{
  setcolorred
  msg "$@"
  resetcolor
}

function msggreen ()
{
  setcolorgreen
  msg "$@"
  resetcolor
}

function msgbold ()
{
  setbold
  msg "$@"
  resetcolor
}

function setcolorred ()
{
  echo -e "\e[1;31m"
}

function setcolorwhiteonredbg ()
{
  echo -e "\e[1;37;41m"     #  fg: white bg: red
}

function setcolorredinverted ()
{
  echo -e "\e[1;31;7m"      #  fg: red inverted
}

function setcolorgreen ()
{
  echo -e "\e[1;32m"
}

function setbold ()
{
  echo -e "\e[1m"
}

function resetcolor ()
{
  echo -e "\e[0m"
}

# A more flexible approach, and also using modal terminal line-drawing characters instead of hyphens:
hr() {
  local start=$'\e(0' end=$'\e(B' line='qqqqqqqqqqqqqqqq'
  local cols=${COLUMNS:-$(tput cols)}
  while ((${#line} < cols)); do line+="$line"; done
  printf '%s%s%s\n' "$start" "${line:0:cols}" "$end"
}

set_title() { printf '\e]2;%s\a' "$*"; }


#==========================================================================
