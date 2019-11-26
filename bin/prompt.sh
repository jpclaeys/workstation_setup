#Make git is outputting the state characters (*,#)
export GIT_PS1_SHOWDIRTYSTATE=0

# Function to assemble the Git part of our prompt.
git_prompt ()
{
	if ! git rev-parse --git-dir > /dev/null 2>&1; then
		return 0
	fi

	local dirty="$(git_check_status '*')"
	local staged="$(git_check_status '+')"

	if [ $staged -eq 1 ] && [ $dirty -eq 1 ]; then
		git_color="$Purple"
	elif [ $dirty -eq 1 ]; then
		git_color="$Red"
	elif [ $staged -eq 1 ]; then
		git_color="$Blue"
	else
		git_color="$Green"
	fi

	echo "$git_color$(__git_ps1)${Color_Off}"
}

function git_check_status() {
    echo `__git_ps1 | grep -c "$1"`
}

# The holy prompt.
#PROMPT_COMMAND='PS1="[${BGreen}\u@\h${Color_Off} ${BBlue}\W${Color_Off}$(git_prompt)]# "'
PROMPT_COMMAND='PS1="[${BGreen}\u@\h${Color_Off} ${BBlue}\W${Color_Off}]# "'

