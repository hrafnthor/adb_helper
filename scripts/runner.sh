#!/usr/bin/env bash

# Executes the input command on the selected device.
_adb () {
	if [[ ! -v ADBH_SOURCE_FLAG ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Required variable 'ADBH_SOURCE_FLAG' is not set!"
		exit 1
	elif [[ "$ADBH_SOURCE_FLAG" == "-s" && ! -v ADBH_SERIAL_NUMBER ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Variable 'ADBH_SOURCE_FLAG' indicates a source (-s) but variable 'ADBH_SERIAL_NUMBER' is unset!"
		exit 1
	fi

	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: A single input parameter containing the adb command inputs was not given!"
		exit 1
	fi

	local result result_code command_input

	command_input="$1"
	result=$(_adb_command "${ADBH_SOURCE_FLAG} ${ADBH_SERIAL_NUMBER} ${command_input}")
	result_code=$?

	echo "$result"
	return $result_code
}

# Executes a adb command directly without any additions.
#
# If variable ADBH_DEBUG is set, the resulting command is logged to stdout.
_adb_command () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: A single input parameter containing the adb command inputs was not given!"
		exit 1
	fi

	local result result_code command_input xargs_verbose

	command_input="$1"

	if [[ -v ADBH_DEBUG ]]; then
		xargs_verbose="-t"
	fi

	result=$(echo "$command_input" | xargs $xargs_verbose -I {} sh -c "adb {} 2>&1")
	result_code=$?

	echo "$result"
	return $result_code
}
