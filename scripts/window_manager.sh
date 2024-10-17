#!/usr/bin/env bash
# -----------------------------------------------------------------------------
#
# This file contains actions related to the window manager.
#
# It's entry point is the `_select_window_manager_action` function.
#
# -----------------------------------------------------------------------------


_select_window_manager_action () {
	if [[ ! -v ADBH_SOURCE_FLAG ]]; then

		local result_array result_code
		_prompt_source_select result
		result_code=$?

		IFS=' ' read -ra result_array <<< "$result"

		if [  $result_code -eq "$CODE_CANCEL" ]; then
			return "$result_code"
		elif [ $result_code -ne 0 ]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result_array[0]}"
			return $result_code
		fi

		local ADBH_SOURCE_FLAG ADBH_SERIAL_NUMBER
		ADBH_SOURCE_FLAG="${result_array[0]}"
		ADBH_SERIAL_NUMBER="${result_array[1]}"
	else
		local device_in_use=
		if [ "$ADBH_SOURCE_FLAG" == "-s" ]; then
			device_in_use="Using specific device: ${ADBH_SERIAL_NUMBER}"
		elif [ "$ADBH_SOURCE_FLAG" == "-d" ]; then
			device_in_use="Using the only attached device (physical)"
		elif [ "$ADBH_SOURCE_FLAG" == "-e" ]; then
			device_in_use="Using the only attached device (emulator)"
		fi
		_warning "$device_in_use"
	fi

	local operations
	operations=("Cancel" "Reset screen size" "Select standard size" "Set custom size")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select device action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_reset_window_manager_size
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_select_window_manager_size
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			_set_custom_window_manager_size
		else
			_warning "Invalid choice. Please try again."
			continue
		fi
	done

	local result result_code
	result=$(_adb )
}

_reset_window_manager_size () {
	local result result_code
	result=$(_adb "shell wm size reset")
	result_code=$?

	if [ ! $result_code -eq 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_select_window_manager_size () {
	local operations
	operations=("Cancel""320x240" "480x320" "640x480" "800x480" "800x600" "1024x600" "1280x720" "1280x960" "1440x900" "1600x900" "1920x1080" "2560x1440" "3440x1440")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select device action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		else
			_set_window_manager_size "$selected_operation"
			break;
		fi
	done
}

_set_custom_window_manager_size () {
	local width height input

	read -e -r -p "Input desired width: "  input

	if [[ "$input" =~ ^-?[0-9]+$ ]]; then
		width="$input"
	else
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Input was not a valid integer!"
		exit 1
	fi

	read -e -r -p "Input desired height: "  input

	if [[ "$input" =~ ^-?[0-9]+$ ]]; then
		height="$input"
	else
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Input was not a valid integer!"
		exit 1
	fi

	_set_window_manager_size "${width}x${height}"
}

_set_window_manager_size () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local resolution result result_code

	resolution="$1"
	result=$(_adb "shell wm size ${resolution}")
	result_code=$?

	if [ ! $result_code -eq 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}
