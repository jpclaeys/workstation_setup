function definecmdsaliases
{
# Define cmds aliases
if [ -d "$DOCDIR" ]; then
  for F in `ls -c1 $DOCDIR/*.cmds | sed "s:.*/::g"`; do
    ALIASNAME=`echo $F | sed 's/\./_/'`
    alias $ALIASNAME="cat $DOCDIR/$F"
  done
fi
}

function removespacesinfilename ()
{
[ $# -eq 0 ] && return 1
FILENAME="$@"
[ ! -f "$FILENAME" -a ! -d "$FILENAME" ] && errmsg "File \"$@\" is unknown" && return 1
NEWFILENAME=`echo "$FILENAME" | tr ' ' '_'| sed 's/(//g;s/)//g;s/_-_/_/g;s/__/_/g;s/,[-_]//g;s/&/and/g'|tr '-' '_'`
confirmexecution "Do you want to rename $FILENAME to $NEWFILENAME ?" || return 1
mv "$FILENAME" "$NEWFILENAME"
}

function opdtlist ()
{
aws1 w | sed '1,2d' | awk '{print $1,$3}' | cut -d"." -f1| sort -u
}

function strindex ()
{
# Position of a substring within a string
# $1: main string 
# $2: substring to find in the main string
# Return: substring position if found, or -1 if not
  x="${1%%$2*}"
  [[ "$x" = "$1" ]] && echo -1 || echo "${#x}"
}
