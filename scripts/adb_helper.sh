#!/usr/bin/env bash
# -----------------------------------------------------------------------------
#
# Main entry point script for adbh. Validates the presence of required third
# party tools and the correctness of environment, before prompting for action.
#
# -----------------------------------------------------------------------------

function _assert_dependencies {
	if ! command -v adb &> /dev/null; then
		_error "'adb' was not found on path! Exiting."
		exit 1
	fi

	if ! command -v awk &> /dev/null; then
		_error "'awk' was not found on path! Exiting."
		exit 1
	fi

	if ! command -v bc &> /dev/null; then
		_error "'bc' was not found on path! Exiting."
		exit 1
	fi

	if ! command -v expect &> /dev/null; then
		_error "'expect' was not found on path! Exiting."
		exit 1
	fi

	if ! command -v fzf &> /dev/null; then
		_error "'fzf' was not found on path! Exiting."
		exit 1
	fi

	if ! command -v grep &> /dev/null; then
		_error "'grep' was not found on path! Exiting."
		exit 1
	fi

	if ! command -v less &> /dev/null; then
		_error "'less' was not found on path! Exiting."
		exit 1
	fi

	if ! command -v sort &> /dev/null; then
		_error "'sort' was not found on path! Exiting."
		exit 1
	fi

	if ! command -v sed &> /dev/null; then
		_error "'sed' was not found on path! Exiting."
		exit 1
	fi

	if [[ -v ADBH_USE_PIDCAT ]]; then
		if ! command -v pidcat &> /dev/null; then
			_error "'ADBH_USE_PIDCAT' is set but 'pidcat' was not found on path! Exiting."
			exit 1
		fi
	fi
}

function _start_server {
	local result result_code
	result=$(adb start-server)
	result_code=$?

	if [ ! $result_code -eq 0 ]; then
		_error "$result"
		exit $result_code
	fi
}

function _validate_environment {
	if [[ -v ADBH_SOURCE ]]; then
		_validate_variable_value "ADBH_SOURCE" "$ADBH_SOURCE" "emulator" "device" "serial"

		if [[ "$ADBH_SOURCE" == "serial" && ! -v ADBH_SERIAL_NUMBER ]]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: When ADBH_SOURCE is set to 'serial' the variable ADBH_SERIAL_NUMBER must be set as well!"
			exit 1
		fi

		if [[ "$ADBH_SOURCE" == "emulator" ]]; then
			export ADBH_SOURCE_FLAG="-e"
		elif [[ "$ADBH_SOURCE" == "device" ]]; then
			export ADBH_SOURCE_FLAG="-d"
		elif [[ "$ADBH_SOURCE" == "serial" ]]; then
			export ADBH_SOURCE_FLAG="-s"
		fi
	fi

	if [[ -v ADBH_PATH ]]; then
		if [ -d "$ADBH_PATH" ] && [ ! -w "$ADBH_PATH" ]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: Configured ADBH_PATH ('${ADBH_PATH}') isn't writable!"
			exit 1
		else
			mkdir --parents "$ADBH_PATH"
		fi
	fi

	if [[ ! -v ADBH_EDITOR ]]; then
		if [[ $OSTYPE == 'darwin'* ]]; then
			export ADBH_EDITOR="open"
		else
			export ADBH_EDITOR="editor"
		fi
	fi
}

function _select_category {
	local operations selected_operation
	operations=("Exit" "Devices" "Capture" "Content providers" "Notifications" "Files" "Demo" "Packages" "Accessibility" "Urls" "Permissions" "Window manager")

	while true; do
		local selected_operation
		_prompt_selection_menu "Available categories: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "Exit" ]; then
			exit 0
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_select_device_actions
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_select_capture_action
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			_select_content_provider_action
		elif [ "$selected_operation" == "${operations[4]}" ]; then
			_select_notification_action
		elif [ "$selected_operation" == "${operations[5]}" ]; then
			_select_file_operation
		elif [ "$selected_operation" == "${operations[6]}" ]; then
			_select_demo_action
		elif [ "$selected_operation" == "${operations[7]}" ]; then
			_select_global_package_action
		elif [ "$selected_operation" == "${operations[8]}" ]; then
			_select_accessibility_action
		elif [ "$selected_operation" == "${operations[9]}" ]; then
			_select_url_action
		elif [ "$selected_operation" == "${operations[10]}" ]; then
			_select_permission_action
		elif [ "$selected_operation" == "${operations[11]}" ]; then
			_select_window_manager_action
		else
			error "${BASH_SOURCE[0]}, lineno: $LINENO: Unknown action selection! Exiting."
			exit 1
		fi
	done
}

function _execute {
	local SCRIPT_DIR=$(dirname "$(readlink -f "$0")" )

	source "${SCRIPT_DIR}/runner.sh"
	source "${SCRIPT_DIR}/accessibility.sh"
	source "${SCRIPT_DIR}/capture.sh"
	source "${SCRIPT_DIR}/content_providers.sh"
	source "${SCRIPT_DIR}/control.sh"
	source "${SCRIPT_DIR}/demo.sh"
	source "${SCRIPT_DIR}/devices.sh"
	source "${SCRIPT_DIR}/files.sh"
	source "${SCRIPT_DIR}/notifications.sh"
	source "${SCRIPT_DIR}/packages.sh"
	source "${SCRIPT_DIR}/permissions.sh"
	source "${SCRIPT_DIR}/urls.sh"
	source "${SCRIPT_DIR}/utils.sh"
	source "${SCRIPT_DIR}/window_manager.sh"

	export CODE_CANCEL=10

	_assert_dependencies
	_validate_environment
	_start_server

	_select_category
}

_execute
