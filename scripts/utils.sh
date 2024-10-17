#!/usr/bin/env bash
# -------------------------------------------------------------
#
# This script contains various utility functions used in other
# scripts.
#
# -------------------------------------------------------------

function _print {
	echo -e "$1" >&2
}

# Logs a purple colored message to STDERR
function _prompt {
	local purple='\033[35m'
	local nc='\033[0m' # No Color
	echo -e "${purple}$1${nc}" >&2
}

# Log a blue colored message to STDERR
function _info {
	local blue='\033[0;34m'
	local nc='\033[0m' # No Color
	echo -e "${blue}$1${nc}" >&2
}

# Log yellow colored message to STDERR
function _warning {
	local yellow='\033[0;33m'
	local nc='\033[0m' # No Color
	echo -e "${yellow}$1${nc}" >&2
}

# Log red colored message to STDERR
function _error {
	local red='\033[0;31m'
	local nc='\033[0m' # No Color
	echo -e "${red}$1${nc}" >&2
}


# Allows for multiselecting from multiple options. Expects at least two inputs,
# and an optiona third.
#
# First should be a the name of the variable receiving the result of the
# selection.
#
# Second should be a string input with the labels that should be shown, split
# with an ';'.
#
# The third input can be a string indicating the automatic selection of the
# fields, as indicated by a 'true' separated with a ';'. False values can be
# omitted (i.e 'true;;true' will set the first and last checked, leaving the
# second unchecked).
#
# Example usage:
#
# RESULT=
# multiselect RESULT "Option 1;Option 2;Option 3" "true;;true"
#
# source: https://stackoverflow.com/a/54261882
function _multiselect {

	# little helpers for terminal print control and key input
	ESC=$( printf "\033")
	cursor_blink_on()	{ printf "$ESC[?25h"; }
	cursor_blink_off()	{ printf "$ESC[?25l"; }
	cursor_to()			{ printf "$ESC[$1;${2:-1}H"; }
	print_inactive()	{ printf "$2   $1 "; }
	print_active()		{ printf "$2  $ESC[7m $1 $ESC[27m"; }
	get_cursor_row()	{ IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
	key_input()	{
		local key
		IFS= read -rsn1 key 2>/dev/null >&2
		if [[ $key = "" ]]; then echo enter; fi;
		if [[ $key = $'\x20' ]]; then echo space; fi;
		if [[ $key = "c" ]]; then echo cancel; fi;
		if [[ $key = $'\x1b' ]]; then
			read -rsn2 key
			if [[ $key = [A ]]; then echo up;    fi;
			if [[ $key = [B ]]; then echo down;  fi;
		fi
	}
	toggle_option()	{
		local arr_name=$1
		eval "local arr=(\"\${${arr_name}[@]}\")"
		local option=$2
		if [[ ${arr[option]} == true ]]; then
			arr[option]=
		else
			arr[option]=true
		fi
		eval $arr_name='("${arr[@]}")'
	}

	local retval=$1
	local options
	local defaults

	IFS=';' read -r -a options <<< "$2"
	if [[ -z $3 ]]; then
		defaults=()
	else
		IFS=';' read -r -a defaults <<< "$3"
	fi
	local selected=()

	for ((i=0; i<${#options[@]}; i++)); do
		selected+=("${defaults[i]}")
		printf "\n"
	done

	# determine current screen position for overwriting the options
	local lastrow=`get_cursor_row`
	local startrow=$(($lastrow - ${#options[@]}))

	# ensure cursor and input echoing back on upon a ctrl+c during read -s
	trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
	cursor_blink_off

	local active=0
	while true; do
		# print options by overwriting the last lines
		local idx=0
		for option in "${options[@]}"; do
			local prefix="[ ]"
			if [[ ${selected[idx]} == true ]]; then
				prefix="[x]"
			fi

			cursor_to $(($startrow + $idx))
			if [ $idx -eq $active ]; then
				print_active "$option" "$prefix"
			else
				print_inactive "$option" "$prefix"
			fi
			((idx++))
		done

		# user key control
		case `key_input` in
			cancel)	return "$CODE_CANCEL";;
			space)	toggle_option selected $active;;
			enter)	break;;
			up)		((active--));
					if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
			down)	((active++));
					if [ $active -ge ${#options[@]} ]; then active=0; fi;;
		esac
	done

	# cursor position back to normal
	cursor_to $lastrow
	printf "\n"
	cursor_blink_on

	eval $retval='("${selected[@]}")'
}

# Attempts to diff two arrays and return the resulting diff.
#
# Expects to be given the names of the two arrays that should be diffed,
# with the differences from the first against the second being returned.
#
# Usage:
#
# local array1 array2
# array1=("apple" "banana" "pineapple")
# array2=("banana")
# _diff array1 array2
#
# results: "apple" "pineapple"
#
_diff () {
	if [[ ! $# -eq 2 ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Expects exactly two input parameters to function!"
		return 1
	fi

	local array_one_name array_two_name
	array_one_name="$1"
	array_two_name="$2"

	eval "local -a array_one=(\"\${${array_one_name}[@]}\")"
	eval "local -a array_two=(\"\${${array_two_name}[@]}\")"

	local array_one_file array_two_file
	array_one_file=$(mktemp)
	array_two_file=$(mktemp)

	# Add values in a sorted order to temp files
	printf "%s\n" "${array_one[@]}" | sort > "$array_one_file"
	printf "%s\n" "${array_two[@]}" | sort > "$array_two_file"

	# Get values that are in list1 but not in list2
	local result
	result=$(comm -23 "$array_one_file" "$array_two_file")

	rm "$array_one_file" "$array_two_file"

	echo "${result[@]}"
}

# Prompts the user to select one option out of an arbitraty length.
# First input is considered to be the prompt title with the rest being options.
#
# Usage: _prompt_selection "Select one: " "${options[@]}"
# Usage: _prompt_selection "Select one: " "First" "Second" .... "Nth"
#
_prompt_selection () {
	if [[ $# -lt 2 ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Expects at least two input parameters to function!"
		return 1
	fi

	local prompt options
	prompt="$1"
	shift
	options=("$@")

	_prompt "$prompt"

	# Automatically used by Bash select for prompt
	PS3=$'\e[01;34mSelection: \e[0m'

	# To list values vertically rather than horizontally
	export COLUMNS=1

	select selected in "${options[@]}" ; do
		if [[ -n $selected ]]; then
			echo "$selected"
			break
		else
			_warning "Invalid choice. Please try again."
		fi
	done

	unset COLUMNS
	unset PS3
}

# Prompts the user to select one option out of an arbitraty length.
# First input is considered to be the prompt title with the rest being options.
#
# Returns the index of the selection
#
# Usage: _prompt_selection "Select one: " "${options[@]}"
# Usage: _prompt_selection "Select one: " "First" "Second" .... "Nth"
#
_prompt_selection_index () {
	if [[ $# -lt 2 ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Expects at least two input parameters to function!"
		return 1
	fi

	local prompt options
	prompt="$1"
	shift
	options=("$@")

	local result result_code
	result=$(printf "%s\n" "${options[@]}" | paste -d" " <(seq 0 $((${#options[@]} - 1))) - | fzf --with-nth 2.. --prompt "$prompt" | awk '{print $1}')
	result_code=$?

	if [ $result_code -eq 130 ]; then
		return "$CODE_CANCEL"
	elif [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	echo "$result"
}

# Prompts a selection menu where items can be navigated between using
# the arrow keys.
#
# Expects the first input to be the prompt, and the second input to
# be the output variable. Any further input is considered to be
# the selectable options.
#
# source: https://askubuntu.com/a/1386907
_prompt_selection_menu () {
	if [[ $# -lt 3 ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Expects at least three input parameters to function!"
		return 1
	fi

	local prompt="$1" outvar="$2"
	shift
	shift
	local options=("$@") cur=0 count=${#options[@]} index=0
	local esc
	# cache ESC as test doesn't allow esc codes
	esc=$(echo -en "\e")

	_prompt "$prompt"

	while true; do
		# list all options (option list is zero-based)
		index=0
		for option in "${options[@]}"
		do
			if [ "$index" == "$cur" ]
			then echo -e " >\e[7m$option\e[0m" # mark & highlight the current option
			else echo "  $option"
			fi
			(( index++ ))
		done

		read -s -r -n3 key # wait for user to key in arrows or ENTER

		if [[ $key == $esc[A ]] # up arrow
		then (( cur-- )); (( cur < 0 )) && (( cur = 0 ))
		elif [[ $key == $esc[B ]] # down arrow
		then (( cur++ )); (( cur >= count )) && (( cur = count - 1 ))
		elif [[ $key == "" ]] # nothing, i.e the read delimiter - ENTER
		then break
		fi
		echo -en "\e[${count}A" # go up to the beginning to re-render
	done
	# export the selection to the requested output variable
	printf -v "$outvar" "%s" "${options[$cur]}"
}


# Calculates the ratio of two numbers relative to 100 (i.e percentage).
#
# Expects two numbers, the first being the numerator and the other
# being the denominator.
#
# Usage: _percent "50" "60"
# Result: 83
#
# source: https://github.com/sromku/adb-export
_percent () {
  printf '%i %i' "$1" "$2" | awk '{ pc=100*$1/$2; i=int(pc); print (pc-i<0.5)?i:i+1 }'
}

# Prints a "spinner" to stdout
_spinner () {
	local pid=$!
	local delay=0.05
	local spinstr='|/-\'
	while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
		local temp=${spinstr#?}
		toPrint=$(printf "[%c]  " "$spinstr")
		echo -ne " - $1: $toPrint \r"

		local spinstr=$temp${spinstr%"$temp"}
		sleep $delay
	done
	echo -ne " - $1: Done"
	echo ""
}


# Validates a single variable if it is set.
#
# Expects at least 3 inputs:
#
# 1. Name of the variable to test
#
# 2. The value contained in the variable
#
# All further inputs are treated as an arbitrary number of inputs,
# with each being a valid value that can be taken.
#
_validate_variable_value () {
	if [ $# -lt 3 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects at least 3 input arguments!"
		exit 1
	fi

	local variable_name="$1"
	local variable_value="$2"

	valid_values_array=("${@:3}")

	local valid_values_string=""
	local regex_string="^("
	for (( i=0; i<${#valid_values_array[@]}; i++ )); do
		if [[ $i != 0 ]]; then
			regex_string+="|"
			valid_values_string+=", "
		fi

		local value="${valid_values_array[$i]}"
		regex_string+="$value"
		valid_values_string+="$value"
	done

	regex_string+=")$"

	if [[ -v $1 ]]; then
		if [[ ! "$variable_value" =~ $regex_string ]]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: Environment variable '${variable_name}' is set to '${variable_value}'!. Valid values are: [${valid_values_string}]"
			exit 1
		fi
	fi
}
