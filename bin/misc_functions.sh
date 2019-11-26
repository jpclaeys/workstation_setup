function define_cmds_aliases
{
# Define cmds aliases
if [ -d "$DOCDIR" ]; then
  for F in `ls -c1 $DOCDIR/*.cmds | sed "s:.*/::g"`; do
    ALIASNAME=`echo $F | sed 's/\./_/'`
    alias $ALIASNAME="cat $DOCDIR/$F"
  done
fi
}

function remove_spaces_in_file_name ()
{
[ $# -eq 0 ] && return 1
FILENAME="$@"
[ ! -f "$FILENAME" -a ! -d "$FILENAME" ] && errmsg "File \"$@\" is unknown" && return 1
NEWFILENAME=`echo "$FILENAME" | tr ' ' '_'| sed 's/(//g;s/)//g;s/_-_/_/g;s/__/_/g;s/,[-_]//g;s/&/and/g'|tr '-' '_'`
confirmexecution "Do you want to rename $FILENAME to $NEWFILENAME ?" || return 1
mv "$FILENAME" "$NEWFILENAME"
}


