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
    c=$(ckkeywd -Q -p "[?] Confirm execution on host `hostname`" yes no skip )
    case "$c" in 
        'yes')
            i=0
            while [ $i -lt ${#CMDS[@]} ]
            do 
                echo "[$i] Execute: ${CMDS[$i]}"
                eval ${CMDS[$i]}
                rc=$?;
                if [ $rc -ne 0 ]; then
                    c=$(ckkeywd -Q -p "  [$i] non zero return code ($rc), continue anyway ?" yes no)
                    if [ "$c" = "no" ]; then
                        break;
                    fi
                fi
                i=$((i+1))
            done
            return 0
        ;;
        'no')
            return 2
        ;;
        'skip')
            return 1
        ;;
        *)
            return 1
        ;;
    esac
}
