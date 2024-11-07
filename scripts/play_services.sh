#!/usr/bin/env bash
# -----------------------------------------------------------------------------
#
# Contains functionality related to Google Play Services.
#
# Entry point is 'select_play_action()'
#
# -----------------------------------------------------------------------------

_select_play_action () {
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
	operations=("Cancel" "Instant apps")

	while true; do

		local selected_operation
		_prompt_selection_menu "Play Services action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_select_instant_apps_action
		else
			error "Unknown action selection! Exiting."
			exit 1
		fi
	done
}

_select_instant_apps_action () {
	local operations selected_operation
	operations=("Cancel" "Open instant apps toggle view")

	while true; do

		local selected_operation
		_prompt_selection_menu "Instant app action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_open_instant_app_view
		else
			error "Unknown action selection! Exiting."
			exit 1
		fi
	done
}

_open_instant_app_view () {
	local result result_code
	result=$(_adb "shell am start -n com.google.android.gms/.instantapps.settings.SettingsActivity")
	result_code=$?

	if [ ! $result_code -eq 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}
