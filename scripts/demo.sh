#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Contains operations related to managing system ui demo mode on devices.
#
# See following url for official documentation:
#
# https://android.googlesource.com/platform/frameworks/base/+/master/packages/SystemUI/docs/demo_mode.md
# -----------------------------------------------------------------------------

_select_demo_action () {
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

	local option_demo_mode_on="Turn demo mode on"
	local option_demo_mode_off="Turn demo mode off"

	while true; do
		local result result_code
		result=$(_get_demo_mode_state)
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
			return $result_code
		fi

		local demo_option=
		if [[ "$result" == "1" ]]; then
			demo_option="$option_demo_mode_off"
		else
			demo_option="$option_demo_mode_on"
		fi

		local operations selected_operation
		operations=("Cancel" "$demo_option" "Configuration")

		_prompt_selection_menu "Select demo action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "$option_demo_mode_on" ]; then
			_trigger_demo_mode "1"
		elif [ "$selected_operation" == "$option_demo_mode_off" ]; then
			_trigger_demo_mode "0"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_select_demo_system_config_action
		else
			_warning "Invalid choice. Please try again."
			continue
		fi
	done
}

_get_demo_mode_state () {
	local result result_code
	result=$(_adb "shell settings get global sysui_demo_allowed")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	local demo_mode_allowed="$result"

	result=$(_adb "shell settings get global sysui_tuner_demo_on")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	local demo_mode_on="$result"

	if [[ "$demo_mode_allowed" == "1" && "$demo_mode_on" == "1" ]]; then
		echo "1"
	else
		echo "0"
	fi
}

_trigger_demo_mode () {
	if [[ ! $# -eq 1 ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Expects one input parameter to function!"
		exit 1
	elif [[ "$1" != "1" && "$1" != "0" ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Input can only be 1 or 0!"
		exit 1
	fi

	local result result_code input

	input="$1"
	result=$(_adb "shell settings put global sysui_demo_allowed ${input}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	result=$(_adb "shell settings put global sysui_tuner_demo_on ${input}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi
}

_select_demo_system_config_action () {
	local option_touch_on="Show touch events"
	local option_touch_off="Hide touch events"

	while true; do
		local result result_code
		result=$(_get_show_screen_touches_state)
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
			return $result_code
		fi

		local toggle_option toggle_value
		if [ "$result" == "1" ]; then
			toggle_option="$option_touch_off"
			toggle_value="0"
		else
			toggle_option="$option_touch_on"
			toggle_value="1"
		fi

		local operations selected_operation
		operations=("Cancel" "Battery" "Network" "System bars" "Status" "Clock" "$toggle_option")

		_prompt_selection_menu "Select category: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_warning "not implemented"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_warning "not implemented"
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			_configure_demo_systemui_bars
		elif [ "$selected_operation" == "${operations[4]}" ]; then
			_configure_demo_systemui_icons
		elif [ "$selected_operation" == "${operations[5]}" ]; then
			_configure_demo_clock
		elif [ "$selected_operation" == "${operations[6]}" ]; then
			_set_show_screen_touches "$toggle_value"
		else
			_error "Unknown action selection! Exiting."
			exit 1
		fi
	done
}

_configure_demo_systemui_icons () {
	local available_values=("location" "alarm" "sync" "tty" "mute" "speakerphone")
	local available_options

	for value in "${available_values[@]}"; do
		available_options+="$value;"
	done

	_prompt "Select which icons should be visible. Press 'c' to cancel:"

	local selected_status
	_multiselect selected_status "$available_options"

	local selected_values
	for index in "${!selected_status[@]}"; do
		if [ "${selected_status[$index]}" == "true" ]; then
			selected_values+=("${available_values[$index]}")
		fi
	done

	local unselected_values
	unselected_values=($(_diff available_values selected_values))

	for subcommand in "${unselected_values[@]}"; do
		_emit_demo_command " status -e ${subcommand} hide"
	done

	for subcommand in "${selected_values[@]}"; do
		_emit_demo_command " status -e ${subcommand} show"
	done
}

_configure_demo_clock () {
	local captured
	read -e -r -p "Set time as hhmm (i.e 0923 for 09:23): " captured

	_emit_demo_command "clock -e hhmm ${captured}"
}

_configure_demo_systemui_bars () {
	local operations selected_operation
	operations=("Cancel" "Opaque" "Translucent" "Semi-Transparent")

	while true; do
		_prompt_selection_menu "Select category: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_emit_demo_command "bars -e mode opaque"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_emit_demo_command "bars -e mode translucent"
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			_emit_demo_command "bars -e mode semi-transparent"
		else
			_warning "Invalid choice. Please try again."
			continue
		fi
	done
}

_emit_demo_command () {
	if [[ ! $# -eq 1 ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Expects one input parameter to function!"
		exit 1
	fi

	local result result_code command
	command="$1"

	result=$(_adb "shell am broadcast -a com.android.systemui.demo -e command '${command}'")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi
}


_set_show_screen_touches () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	elif [[ "$1" != "1" && "$1" != "0" ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Input can only be 1 or 0!"
		exit 1
	fi

	local toggle result result_code
	toggle="$1"
	result=$(_adb "shell settings put system show_touches '${toggle}'")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi
}

_get_show_screen_touches_state () {
	local result result_code
	result=$(_adb "shell settings get system show_touches")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	else
		echo "$result"
	fi
}
