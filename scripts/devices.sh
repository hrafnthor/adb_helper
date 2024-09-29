#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# This script contains functionality for direct device information retrieval
# and interaction.
#
# It's entry point is _select_device_actions()
# -----------------------------------------------------------------------------

_select_device_actions () {
	local operations
	operations=("Cancel" "List devices" "Name sources" "Source lock" "List Android version" "Battery status" "Open shell" "Control")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select device action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_get_serial_numbers
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_name_devices
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			_prompt_source_lock
		elif [ "$selected_operation" == "${operations[4]}" ]; then
			_get_device_android_version
		elif [ "$selected_operation" == "${operations[5]}" ]; then
			_get_device_battery_status
		elif [ "$selected_operation" == "${operations[6]}" ]; then
			_open_shell
		elif [ "$selected_operation" == "${operations[7]}" ]; then
			_select_control_action
		else
			_warning "Invalid choice. Please try again."
			continue
		fi
	done
}

_get_device_android_version () {
	if [[ ! -v ADBH_SOURCE_FLAG ]]; then
		_warning "No source currently selected!"

		local ADBH_SOURCE_FLAG=
		local ADBH_SERIAL_NUMBER=

		local result result_array result_code
		_prompt_source_select result
		result_code=$?

		IFS=' ' read -ra result_array <<< "$result"

		if [ $result_code -eq "$CODE_CANCEL" ]; then
			return "$CODE_CANCEL"
		elif [ $result_code -ne 0 ]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result_array[0]}"
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

	_adb "shell getprop ro.build.version.release"
}

_get_device_battery_status () {
	if [[ ! -v ADBH_SOURCE_FLAG ]]; then
		_warning "No source currently selected!"

		local ADBH_SOURCE_FLAG=
		local ADBH_SERIAL_NUMBER=

		local result result_array result_code
		_prompt_source_select result
		result_code=$?

		IFS=' ' read -ra result_array <<< "$result"

		if [ $result_code -eq "$CODE_CANCEL" ]; then
			return "$CODE_CANCEL"
		elif [ $result_code -ne 0 ]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result_array[0]}"
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

	_adb "shell dumpsys battery"
}

_get_serial_numbers () {
	local result result_code
	result=$(_adb_command "devices" | awk '$2 == "device" {print $1}' ORS=',')
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result_array[0]}"
		return $result_code
	fi

	local serial_numbers=
	IFS=',' read -ra serial_numbers <<< "$result"

	if [ ! ${serial_numbers[@]+_} ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: No devices were found!"
		return 1
	fi

	local adbh_mapping_file_path=
	if [[ -v ADBH_MAPPING_PATH ]]; then
		if [ -f "$ADBH_MAPPING_PATH" ]; then
			adbh_mapping_file_path="$ADBH_MAPPING_PATH"
		fi
	elif [[ -v ADBH_PATH ]]; then
		adbh_mapping_file_path="$ADBH_PATH/adbh_serial_mapping"
	fi

	local -A known_devices_array
	if [ -f "$adbh_mapping_file_path" ]; then
		while IFS='=' read -r key value; do
			known_devices_array[$key]="$value"
		done < "$adbh_mapping_file_path"
	fi

	local -A serial_name_mappings_array
	for number in "${serial_numbers[@]}"; do
		if [[ -v known_devices_array[$number] ]]; then
			serial_name_mappings_array[$number]="${known_devices_array[$number]}"
		else
			serial_name_mappings_array["$number"]="$number"
		fi
	done

	if [[ $# -eq 0 ]]; then
		_info "Following devices found:"

		for value in "${serial_name_mappings_array[@]}"; do
			_print "- $value"
		done
	else
		local -A indexed_serial_key_array
		local index=0
		for key in "${!serial_name_mappings_array[@]}"; do
			indexed_serial_key_array[$index]="$key"
			((index++))
		done

		local options=("Cancel" "${serial_name_mappings_array[@]}")
		result=$(_prompt_selection_index "Select the device to use: " "${options[@]}")
		result_code=$?

		if [[ "$result" -eq 0 ]] || [[ "$result_code" -eq 130 ]]; then
			return "$CODE_CANCEL"
		elif [[ $result_code -ne 0 ]]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result_array[0]}"
			return $result_code
		fi

		local adjusted_index=$(( result - 1 ))
		echo "${indexed_serial_key_array[$adjusted_index]}"
	fi
}

_name_devices () {
	local result result_code
	result=$(_get_serial_numbers "select trigger")
	result_code=$?

	if [[ "$result_code" -eq "$CODE_CANCEL" ]]; then
		_warning "- Cancelled operation!"
		return "$CODE_CANCEL"
	elif [[ $result_code -ne 0 ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	local selected_serial_number
	selected_serial_number="$result"

	local device_name
	read -e -r -p "Give a name for the selected device ($selected_serial_number): " device_name
	if [[ ! -v device_name ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: No name given!"
		exit 1
	fi

	if [[ -v ADBH_MAPPING_PATH ]]; then
		if [ -d "$ADBH_MAPPING_PATH" ]; then
			ADBH_MAPPING_PATH="$ADBH_MAPPING_PATH/adbh_serial_mapping"
		fi
	elif [[ -v ADBH_PATH ]]; then
		ADBH_MAPPING_PATH="$ADBH_PATH/adbh_serial_mapping"
	else
		ADBH_MAPPING_PATH=
		read -e -r -p "Select path to device mapping: " -i "$HOME/" ADBH_MAPPING_PATH
	fi

	local parent_dir=
	parent_dir=$(dirname "$ADBH_MAPPING_PATH")

	if [ ! -d "$parent_dir" ]; then
		mkdir --parents "$parent_dir"
	fi

	if [ ! -f "$ADBH_MAPPING_PATH" ]; then
		touch "$ADBH_MAPPING_PATH"
	fi

	if grep -q "^$selected_serial_number=" "$ADBH_MAPPING_PATH"; then
		# serial number mapping was found in mapping path. Replace device name with new one.
		sed -i "s/^\($selected_serial_number=\).*/\1$device_name/" "$ADBH_MAPPING_PATH"
	else
		# serial number mapping was not found in mapping path. Add a new one.
		echo "${selected_serial_number}=${device_name}" >> "$ADBH_MAPPING_PATH"
	fi
}

_prompt_source_lock () {
	local operations selected_operation
	operations=("Cancel" "Lock source selection" "Unlock source selection")

	_prompt_selection_menu "Choose action: " selected_operation "${operations[@]}"

	if [ "$selected_operation" == "${operations[0]}" ]; then
		return "$CODE_CANCEL"
	elif [ "$selected_operation" == "${operations[1]}" ]; then
		local result result_array result_code
		_prompt_source_select result
		result_code=$?

		IFS=' ' read -ra result_array <<< "$result"

		if [[ $result_code == "$CANCEL_CODE" ]]; then
			return "$CANCEL_CODE"
		fi

		ADBH_SOURCE_FLAG="${result_array[0]}"
		ADBH_SERIAL_NUMBER="${result_array[1]}"

		_warning "Device selection locked to: ${ADBH_SOURCE_FLAG} ${ADBH_SERIAL_NUMBER}"
	elif [ "$selected_operation" == "${operations[2]}" ]; then
		unset ADBH_SOURCE_FLAG
		unset ADBH_SERIAL_NUMBER

		_warning "Device selection lock removed"
	else
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Unknown action selection! Exiting."
		exit 1
	fi
}

_prompt_source_select () {
	if [[ $# -lt 1 ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Expects one input parameter to function!"
		return 1
	fi

	local options serial_number selected_option outvar
	outvar="$1"
	options=("Cancel" "Select device" "Only one device" "Only one emulator")

	_prompt_selection_menu "Select a source: " selected_option "${options[@]}"

	if [ "$selected_option" == "${options[0]}" ]; then
		return "$CODE_CANCEL"
	elif [ "$selected_option" == "${options[1]}" ]; then
		local result_code

		selected="-s"
		serial_number=$(_get_serial_numbers "select trigger")
		result_code=$?

		if [  $result_code -ne 0 ]; then
			return "$result_code"
		fi
	elif [ "$selected_option" == "${options[2]}" ]; then
		selected="-d"
	elif [ "$selected_option" == "${options[3]}" ]; then
		selected="-e"
	else
		_warning "Unknown input selection! Please try again."
	fi

	results=("$selected" "$serial_number")
	printf -v "$outvar" "%s " "${results[@]}"
}

_open_shell () {
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
	fi

	# shellcheck disable=SC2086
	adb $ADBH_SOURCE_FLAG $ADBH_SERIAL_NUMBER shell
}
