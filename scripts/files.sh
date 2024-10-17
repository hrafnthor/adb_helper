#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# This script contains functionality related to file operations.
#
# It's entry point is '_select_file_operation ()'
# -----------------------------------------------------------------------------

_select_file_operation () {
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
	operations=("Cancel" "Open shell" "Pull file" "Pull directory" "Push file" "Push directory")

	while true; do

		local selected_operation
		_prompt_selection_menu "File operations: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_open_shell
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_prompt_file_pull
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			_prompt_dir_pull
		elif [ "$selected_operation" == "${operations[4]}" ]; then
			_prompt_push
		elif [ "$selected_operation" == "${operations[5]}" ]; then
			_prompt_push
		else
			error "Unknown action selection! Exiting."
			exit 1
		fi
	done
}

_pull_file () {
	if [ $# -ne 2 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects two input parameters!"
		exit 1
	fi

	local device_source_path local_destination_path result result_code
	device_source_path="$1"
	local_destination_path="$2"

	result=$(_adb "pull '${device_source_path}' '${local_destination_path}'")
	result_code=$?

	if [ ! $result_code -eq 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_push_file () {
	if [[ $# -ne 2 ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Expects two input parameters to function!"
		return 1
	fi

	local local_source_path device_destination_path result result_code
	local_source_path="$1"
	device_destination_path="$2"

	result=$(_adb "push '${local_source_path}' '${device_destination_path}'")
	result_code=$?

	if [ ! $result_code -eq 0 ]; then
		_error "$result"
		return $result_code
	fi
}

_prompt_file_pull () {
	local result result_code
	result=$(_adb "shell find /sdcard/ -type f" | fzf --query /sdcard/ --prompt="Select file to pull: ")
	result_code=$?

	if [ $result_code -eq 130 ]; then
		_warning "User cancelled!"
		return "$CODE_CANCEL"
	elif [ ! $result_code -eq 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	local device_file_path
	device_file_path="$result"
	device_file_name=$(basename "$device_file_path")

	local destination_path
	if [[ -v ADBH_PATH ]]; then
		destination_path="$ADBH_PATH/pulled"
	else
		read -e -r -p "Select local directory path: " -i "$HOME/" destination_path
	fi

	local local_file_path
	local_file_path="${destination_path}/${device_file_name}"

	if [ ! -d "$destination_path" ]; then
		mkdir --parents "$destination_path"
		_warning "- created local path: ${destination_path}"
	fi

	_warning "- Pulling: '${device_file_path}' to '${local_file_path}'"

	result=$(_pull_file "$device_file_path" "$local_file_path")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	local options=("Yes" "No")
	local selection result_code
	_prompt_selection_menu "Delete file on device?: " selection "${options[@]}"
	result_code=$?

	if [[ $result_code -ne 0 ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Selection failed!"
		return $result_code
	elif [[ "$selection" == "Yes" ]]; then
		_delete_path "$device_file_path"
	fi
}

_prompt_dir_pull () {
	local result result_code
	result=$(_adb "shell find /sdcard/ -type d" | fzf --query /sdcard/ --prompt="Select directory to pull: ")
	result_code=$?

	if [ $result_code -eq 130 ]; then
		_warning "User cancelled!"
		return "$CODE_CANCEL"
	elif [ ! $result_code -eq 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local device_dir_path device_dir_name
	device_dir_path="$result"
	device_dir_name=$(basename "$device_dir_path")

	local destination_path
	if [[ -v ADBH_PATH ]]; then
		destination_path="$ADBH_PATH/pulled"
	else
		read -e -r -p "Select local dir path: " -i "$HOME" destination_path
	fi

	_warning "- Pulling '${device_dir_path}' to '${destination_path}/${device_dir_name}'"

	if [ ! -d "$destination_path" ]; then
		mkdir --parents "$destination_path"
	fi

	result=$(_pull_file "$device_dir_path" "$destination_path")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local options=("Yes" "No")
	local selection result_code
	_prompt_selection_menu "Delete directory on device?: " selection "${options[@]}"
	result_code=$?

	if [[ $result_code -ne 0 ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Selection failed!"
		return $result_code
	elif [[ "$selection" == "Yes" ]]; then
		_delete_path "$device_file_path"
	fi
}

_prompt_push () {
	local local_dir_path
	read -e -r -p "Select path to push: " -i "$HOME" local_dir_path

	local result result_code
	result=$(_adb "shell find /sdcard/ -type d" | fzf --query /sdcard/ --prompt="Select destination path: ")
	result_code=$?

	if [ $result_code -eq 130 ]; then
		_warning "User cancelled!"
		return "$CODE_CANCEL"
	elif [ ! $result_code -eq 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local device_path
	device_path="$result"

	if [ -f "$local_dir_path" ]; then
		local file_name
		file_name=$(basename "$local_dir_path")
		device_path="${device_path}/${file_name}"
	fi

	_warning "- Pushing '$local_dir_path' to '$device_path'"

	result=$(_push_file "$local_dir_path" "$device_path")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_delete_path () {
	if [[ $# -ne 1 ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Expects one input parameter to function!"
		return 1
	fi

	local file_path result result_code

	file_path="$1"

	_warning "- Deleting path ${file_path}"

	result=$(_adb "shell rm -r ${file_path}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}
