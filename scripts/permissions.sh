#!/usr/bin/env bash
# -----------------------------------------------------------------------------
#
# This script contains functionality for listing and manipulating permissions
# on a device level.
#
# It's entry point is '_select_permission_action()'
#
# -----------------------------------------------------------------------------

_select_permission_action () {
	if [[ ! -v ADBH_SOURCE_FLAG ]]; then
		_warning "No source currently selected!"

		local ADBH_SOURCE_FLAG=
		local ADBH_SERIAL_NUMBER=

		local result result_array result_code
		_prompt_source_select result
		result_code=$?

		IFS=' ' read -ra result_array <<< "$result"

		if [  $result_code -eq "$CODE_CANCEL" ]; then
			return "$CODE_CANCEL"
		elif [ $result_code -ne 0 ]; then
			_error "${result_array[0]}"
			return $result_code
		fi

		ADBH_SOURCE_FLAG="${result_array[0]}"
		ADBH_SERIAL_NUMBER="${result_array[1]}"

		unset result_array result_code
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

	local operations selected_operation
	operations=("Cancel" "List all permissions")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_list_permissions
		else
			error "${BASH_SOURCE[0]}, lineno: $LINENO: Unknown action selection! Exiting."
			exit 1
		fi
	done
}

_list_permissions () {
	local result result_code
	result=$(_adb "shell pm list permissions -g" | fzf --filter="^permission:" | fzf --prompt "Filter permissions (ctrl+c to cancel): ")
	result_code=$?

	if [ $result_code -eq 130 ]; then
		return "$CODE_CANCEL"
	elif [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	else
		local permission
		permission=$(echo "$result" | awk -F"permission:" '{print $2}')
		_select_specific_permission_action "$permission"
	fi
}

_select_specific_permission_action () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local permission
	permission="$1"

	local operations
	operations=("Cancel" "List applications declaring permission")

	while true; do
		_warning "- Permission selected: ${permission}"

		local selected_operation
		_prompt_selection_menu "Select action:" selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_list_apps_with_runtime_permission "$permission"
		else
			error "Unknown action selection! Exiting."
			exit 1
		fi

		result_code=$?

		if [ $result_code -eq "$CODE_CANCEL" ]; then
			return "$CODE_CANCEL"
		fi
	done
}

_list_apps_with_runtime_permission () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects two input parameters!"
		exit 1
	fi

	local permission permission_tail
	permission="$1"
	permission_tail="${permission##*.}"

	local result result_code
	result=$(_adb "shell appops query-op ${permission_tail} allow")
	result_code=$?

	if [ "$result_code" -ne 0 ]; then
		if [[ "$result" == *"Unknown operation string"* ]]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: This permission can't be queried"
		else
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		fi
		return $result_code
	fi

	local result_array=()
	IFS=$'\n' read -r -d '' -a result_array <<< "$result"

	result=$(printf "%s\n" "${result_array[@]}" | fzf --prompt="Select to modify (ctrl+c to cancel): ")
	result_code=$?

	if [ $result_code -eq 130 ]; then
		return "$CODE_CANCEL"
	elif [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	else
		_warning "- Modifying permissions for ${result}"
		_modify_runtime_permissions "$result"
	fi
}
