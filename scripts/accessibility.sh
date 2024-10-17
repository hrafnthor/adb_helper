#!/usr/bin/env bash
# -----------------------------------------------------------------------------
#
# This script contains functionality for managing accessibility features on
# a selected devices.
#
# It's entry point is '_select_accessibility_action'
#
# -----------------------------------------------------------------------------

_select_accessibility_action () {
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

	local option_talkback_on="Turn talkback on"
	local option_talkback_off="Turn talkback off"

	while true; do
		local result result_code
		result=$(_get_talkback_mode_status)
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "$result"
			return $result_code
		fi

		local option_talkback=
		if [[ "$result" == "1" ]]; then
			option_talkback="$option_talkback_off"
		else
			option_talkback="$option_talkback_on"
		fi

		local operations
		operations=("Cancel" "Reset" "Colors" "Text" "Screen magnification" "Screen density" "$option_talkback")

		local selected_operation
		_prompt_selection_menu "Select accessibility action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_reset_accessibility
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_select_color_action
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			_select_font_action
		elif [ "$selected_operation" == "${operations[4]}" ]; then
			_select_magnification_action
		elif [ "$selected_operation" == "${operations[5]}" ]; then
			_select_density_action
		elif [ "$selected_operation" == "$option_talkback_on" ]; then
			_toggle_talkback_mode "1"
		elif [ "$selected_operation" == "$option_talkback_off" ]; then
			_toggle_talkback_mode "0"
		else
			_warning "Invalid choice. Please try again"
			continue
		fi
	done
}

_reset_accessibility () {
	_warning "- Resetting accessibility options to defaults"

	_adb 'shell settings put system font_scale "1.0"'
	_info "- Font scaling reset"

	_reset_density
	_info "- Screen density reset"

	_toggle_high_contrast_mode "0"
	_info "- High contrast mode off"

	_toggle_magnification "0"
	_info "- Magnification mode off"

	_toggle_color_correction "0"
	_info "- Color correction off"

	_toggle_color_inversion "0"
	_info "- Color inversion off"

	_toggle_talkback_mode "0"
	_info "- Talkback mode off"
}

_select_font_action () {
	local option_hcm_on="Turn high contrast mode on"
	local option_hcm_off="Turn high contrast mode off"

	while true; do
		local result result_code
		result=$(_get_high_contrast_mode_state)
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "$result"
			return $result_code
		fi

		local option_hcm=
		if [ "$result" == "1" ]; then
			option_hcm="$option_hcm_off"
		else
			option_hcm="$option_hcm_on"
		fi

		local operations
		operations=("Cancel" "Configure font size" "$option_hcm")

		local selected_operation
		_prompt_selection_menu "Select accessibility action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_select_font_size
		elif [ "$selected_operation" == "$option_hcm_on" ]; then
			_toggle_high_contrast_mode "1"
		elif [ "$selected_operation" == "$option_hcm_off" ]; then
			_toggle_high_contrast_mode "0"
		else
			_warning "Invalid choice. Please try again"
			continue
		fi

		result_code=$?

		if [ $result_code -ne 0 ]; then
			return $result_code
		fi
	done
}

_select_font_size () {
	local operations
	operations=("Cancel" "Small" "Default" "Large" "Larger")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select font size: " selected_operation "${operations[@]}"

		local font_size
		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			font_size="0.85"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			font_size="1.0"
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			font_size="1.15"
		elif [ "$selected_operation" == "${operations[4]}" ]; then
			font_size="1.30"
		else
			_warning "Invalid choice. Please try again"
			continue
		fi

		local result result_code
		result=$(_adb "shell settings put system font_scale ${font_size}")
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "$result"
			return $result_code
		fi
	done
}

_get_high_contrast_mode_state () {
	local result result_code

	result=$(_adb "shell settings get secure high_text_contrast_enabled")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "$result"
		return $result_code
	else
		echo "$result"
	fi
}

_toggle_high_contrast_mode () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	elif [[ "$1" != "1" && "$1" != "0" ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Input can only be 1 or 0!"
		exit 1
	fi

	local input result result_code
	input="$1"
	result=$(_adb "shell settings put secure high_text_contrast_enabled ${input}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "$result"
		return $result_code
	fi
}

_select_density_action () {
	local operations
	operations=("Cancel" "Current density" "Change density")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select density action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_current_density
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_set_density
		else
			_warning "Invalid choice. Please try again"
			continue
		fi

		local result_code
		result_code=$?

		if [ $result_code -ne 0 ]; then
			return $result_code
		fi
	done
}

_get_default_density () {
	local result result_code

	result=$(_adb 'shell wm density' | awk -F"Physical density: " '{print $2}')
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "$result"
		return $result_code
	else
		echo "$result"
	fi
}

_get_override_density () {
	local result result_code

	result=$(_adb "shell wm density" | awk -F"Override density: " '{print $2}')
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "$result"
		return $result_code
	else
		echo "$result"
	fi
}

_current_density () {
	local result result_code

	result=$(_adb "shell wm density")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "$result"
		return $result_code
	fi

	if echo "$result" | grep -q "Override"; then
		result=$(echo "$result" | awk -F"Override density: " '{print $2}')
	else
		result=$(echo "$result" | awk -F"Physical density: " '{print $2}')
	fi

	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "$result"
		return $result_code
	else
		echo "Current density is: $result"
	fi
}

_set_density () {
	_warning "Not all devices support support every size bucket"

	local operations
	operations=("Cancel" "Small" "Default" "Large" "Larger" "Largest")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select density size: " selected_operation "${operations[@]}"

		local density_scale
		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			density_scale="0.85"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			density_scale="1.0"
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			density_scale="1.1"
		elif [ "$selected_operation" == "${operations[4]}" ]; then
			density_scale="1.12"
		elif [ "$selected_operation" == "${operations[5]}" ]; then
			density_scale="1.3"
		else
			_warning "Invalid choice. Please try again"
			continue
		fi

		local result result_code
		result=$(_get_default_density)
		result_code=$?

		if [ $result_code -ne 0 ]; then
			return $result_code
		fi

		local density
		density=$(awk -v n1="$result" -v n2="$density_scale" 'BEGIN {print n1 * n2}')

		result=$(_adb "shell wm density ${density}")
		result_code=$?

		if [ $result_code -ne 0 ]; then
			return $result_code
		fi
	done
}

_reset_density () {
	local result result_code

	result=$(_adb "shell wm density reset")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "$result"
		return $result_code
	fi
}

_select_magnification_action () {
	local option_magnification_on="Enable"
	local option_magnification_off="Disable"

	while true; do
		local magnification_state
		magnification_state=$(_get_magnification_status)

		local magnification_option=
		if [[ "$magnification_state" == "1" ]]; then
			magnification_option="$option_magnification_off"
			_warning "Magnification is on. Tap 3x times to trigger, 2 finger swipes to move"
		else
			magnification_option="$option_magnification_on"
		fi

		local operations
		operations=("Cancel" "$magnification_option" "Set magnification")

		local selected_operation result_code
		_prompt_selection_menu "Select magnification operation: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "$option_magnification_on" ]; then
			_toggle_magnification "1"
		elif [ "$selected_operation" == "$option_magnification_off" ]; then
			_toggle_magnification "0"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_set_magnification
		else
			_warning "Invalid choice. Please try again"
			continue
		fi

		result_code=$?

		if [ $result_code -ne 0 ]; then
			return $result_code
		fi
	done
}

_get_magnification_status () {
	local result result_code

	result=$(_adb "shell settings get secure accessibility_display_magnification_enabled")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "$result"
		return $result_code
	else
		echo "$result"
	fi
}

_toggle_magnification () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	elif [[ "$1" != "1" && "$1" != "0" ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Input can only be 1 or 0!"
		exit 1
	fi

	local result result_code input

	input="$1"
	result=$(_adb "shell settings put secure accessibility_display_magnification_enabled ${input}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "$result"
		return $result_code
	fi
}

_set_magnification () {
	local magnification
	read -e -p "Give magnification as a number (x or x.y): " -r magnification

	if  [[ $magnification =~ ^[0-9]+$ ]] || [[ $magnification =~ ^[0-9]+\.?[0-9]*$ ]]; then
		local result result_code

		result=$(_adb "shell settings put secure accessibility_display_magnification_scale ${magnification}")
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "$result"
			return $result_code
		fi
	else
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Input is not valid!"
	fi
}

_select_color_action () {
	local option_inversion_on="Turn color inversion on"
	local option_inversion_off="Turn color inversion off"

	while true; do
		local result result_code
		result=$(_get_color_inversion_state)
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "$result"
			return $result_code
		fi

		local inversion_option=
		if [[ "$result" == "1" ]]; then
			inversion_option="$option_inversion_off"
		else
			inversion_option="$option_inversion_on"
		fi

		local operations
		operations=("Cancel" "Color correction" "$inversion_option")


		local selected_operation result_code
		_prompt_selection_menu "Select color operation: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_select_color_correction_action
		elif [ "$selected_operation" == "$option_inversion_on" ]; then
			_toggle_color_inversion "1"
		elif [ "$selected_operation" == "$option_inversion_off" ]; then
			_toggle_color_inversion "0"
		else
			_warning "Invalid choice. Please try again"
			continue
		fi

		result_code=$?

		if [ $result_code -ne 0 ]; then
			return $result_code
		fi
	done
}

_select_color_correction_action () {
	local option_correction_on="Enable correction"
	local option_correction_off="Disable correction"

	while true; do
		local result result_code
		result=$(_get_color_correction_state)
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "$result"
			return $result_code
		fi

		local correction_option=
		if [[ "$result" == "1" ]]; then
			correction_option="$option_correction_off"
		else
			correction_option="$option_correction_on"
		fi

		local operations
		operations=("Cancel" "$correction_option" "Select correction")

		local selected_operation result_code
		_prompt_selection_menu "Select color correction action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "$option_correction_on" ]; then
			_toggle_color_correction "1"
		elif [ "$selected_operation" == "$option_correction_off" ]; then
			_toggle_color_correction "0"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_select_color_correction_type
		else
			_warning "Invalid choice. Please try again"
			continue
		fi

		result_code=$?

		if [ $result_code -ne 0 ]; then
			return $result_code
		fi
	done
}

_get_color_correction_state () {
	local result result_code

	result=$(_adb "shell settings get secure accessibility_display_daltonizer_enabled")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	else
		echo "$result"
	fi
}

_toggle_color_correction () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	elif [[ "$1" != "1" && "$1" != "0" ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Input can only be 1 or 0!"
		exit 1
	fi

	local result result_code input

	input="$1"
	result=$(_adb "shell settings put secure accessibility_display_daltonizer_enabled ${input}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi
}

_select_color_correction_type () {
	local operations
	operations=("Cancel" "Monochromatic" "Protanomaly" "Deuteranomaly" "Tritanomaly")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select color correction type: " selected_operation "${operations[@]}"

		local correction_code
		if [ "$selected_operation" == "${operations[0]}" ]; then
			return 0
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			correction_code="0"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			correction_code="11"
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			correction_code="12"
		elif [ "$selected_operation" == "${operations[4]}" ]; then
			correction_code="13"
		else
			_warning "Invalid choice. Please try again"
			continue
		fi

		local result result_code
		result=$(_adb "shell settings put secure accessibility_display_daltonizer ${correction_code}")
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
			return $result_code
		fi
	done
}

_get_color_inversion_state () {
	local result result_code
	result=$(_adb "shell settings get secure accessibility_display_inversion_enabled")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	else
		echo "$result"
	fi
}

_toggle_color_inversion () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	elif [[ "$1" != "1" && "$1" != "0" ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Input can only be 1 or 0!"
		exit 1
	fi

	local result result_code input

	input="$1"
	result=$(_adb "shell settings put secure accessibility_display_inversion_enabled ${input}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi
}

_get_talkback_mode_status () {
	local result result_code
	result=$(_adb "shell settings get secure enabled_accessibility_services")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	elif [[ "$result" == "null" ]]; then
		echo "0"
	else
		echo "1"
	fi
}

_toggle_talkback_mode () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	elif [[ "$1" != "1" && "$1" != "0" ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Input can only be 1 or 0!"
		exit 1
	fi

	local result result_code input

	if [[ "$1" == "1" ]]; then
		input="com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService"
	else
		input="com.android.talkback/com.google.android.marvin.talkback.TalkBackService"
	fi

	result=$(_adb "shell settings put secure enabled_accessibility_services ${input}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi
}
