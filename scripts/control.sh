#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# This script contains functionality related to direct device control.
#
# It's entry point is the '_select_control_action ()'
# -----------------------------------------------------------------------------

_select_control_action () {
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
	operations=("Cancel" "tank commands" "Brightness" "Wake up" "Sleep")

	while true; do
		local selected_operation
		_prompt_selection_menu "Control options: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_tank_commands
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_select_brightness_action
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			_device_wake_up
		elif [ "$selected_operation" == "${operations[4]}" ]; then
			_device_sleep
		else
			error "Unknown action selection! Exiting."
			exit 1
		fi
	done
}

_select_brightness_action () {
	local usage=
	usage=$(cat << END
		Screen brightness controls enabled. Use CTRL-c to exit.

		w: increase brightness

		a: turn screen off

		s: decrease brightness

		d: turn screen on
END
		)

	_prompt "$usage"

	local result result_code

	result=$(_adb "shell wm size")
	result_code=$?

	if [ ! $result_code -eq 0 ]; then
		_error "$result"
		return $result_code
	fi

	trap 'trap - SIGINT; return $CODE_CANCEL' SIGINT

	local key_input=
	while true; do
		read -rsn1 key_input

		local adb_input_command=
		if [ "$key_input" == "w" ]; then
			# simuate increasing brightness
			adb_input_command="keyevent 221"
		elif [ "$key_input" == "a" ]; then
			# simulate turning screen off
			adb_input_command="keyevent 223"
		elif [ "$key_input" == "s" ]; then
			# simulate lowering brightness
			adb_input_command="keyevent 220"
		elif [ "$key_input" == "d" ]; then
			# simulate turning screen on
			adb_input_command="keyevent 224"
		else
			continue
		fi

		result=$(_adb "shell input '${adb_input_command}'")
		result_code=$?

		if [ ! $result_code -eq 0 ]; then
			break
		fi
	done

	trap - SIGINT

	if [ ! $result_code -eq 0 ]; then
		_error "$result"
		return $result_code
	fi
}

_tank_commands () {
	local usage=
	usage=$(cat << END
		Tank controls are enabled. Use CTRL-c to exit.

		w: scrolls up

		a: swipes to the left

		s: scrolls down

		d: swipes to the right

		q: Toggle 'Back' action

		e: Taps screen center (selecting a screen during activity overview)

		z: Toggles wake state

		x: Toggle 'home' button

		TAB: Toggle 'app overview'
END
	)

	_prompt "$usage"

	local result result_code

	result=$(_adb "shell wm size")
	result_code=$?

	if [ ! $result_code -eq 0 ]; then
		_error "$result"
		return $result_code
	fi

	local size height half_height width half_width
	size=$(echo "$result" | awk '//{gsub(/ /, "", $0); print}'  | awk -F':' '{print $2}')
	width=$(echo "$size" | awk -F 'x' '{print $1}')
	height=$(echo "$size" | awk -F 'x' '{print $2}')

	half_width=$(echo "scale=2; $width/2" | bc)
	half_height=$(echo "scale=2; $height/2" | bc)

	trap 'trap - SIGINT; return $CODE_CANCEL' SIGINT

	local key_input=
	while true; do
		IFS= read -rsn1 key_input

		local adb_input_command=
		if [ "$key_input" == "w" ]; then
			# simuate upward scroll
			adb_input_command="touchscreen swipe $half_width $half_height $half_width 0"
		elif [ "$key_input" == "a" ]; then
			# simulate swipe to the left
			adb_input_command="touchscreen swipe 0 $half_height $half_width $half_height"
		elif [ "$key_input" == "s" ]; then
			# simulate downward scroll
			adb_input_command="touchscreen swipe $half_width $half_height $half_width $height"
		elif [ "$key_input" == "d" ]; then
			# simulate swipe to the right
			adb_input_command="touchscreen swipe $half_width $half_height 0 $half_height"
		elif [ "$key_input" == "q" ]; then
			# simulate back button click
			adb_input_command="keyevent 4"
		elif [ "$key_input" == "e" ]; then
			# simulate tapping on center of screen
			adb_input_command="touchscreen tap ${half_width} ${half_height}"
		elif [ "$key_input" == "z" ]; then
			adb_input_command="keyevent 26"
		elif [ "$key_input" == "x" ]; then
			adb_input_command="keyevent 3"
		elif [[ $key_input == $'\t' ]]; then
			# simulate application switch
			adb_input_command="keyevent 187"
		else
			continue
		fi

		result=$(_adb "shell input ${adb_input_command}")
		result_code=$?

		if [ ! $result_code -eq 0 ]; then
			break
		fi
	done

	trap - SIGINT

	if [ ! $result_code -eq 0 ]; then
		_error "$result"
		return $result_code
	fi
}

_device_wake_up () {
	_adb "shell input keyevent KEYCODE_WAKEUP"
}

_device_sleep () {
	_adb "shell input keyevent KEYCODE_SOFT_SLEEP"
}
