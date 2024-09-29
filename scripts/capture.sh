#!/usr/bin/env bash
# -----------------------------------------------------------------------------
#
# This script contains functionality for capturing screenshots and videos
# from a selected device.
#
# It's entry point is '_select_capture_action ()'
#
# -----------------------------------------------------------------------------

_select_capture_action () {
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

	local operations selected_operation
	operations=("Cancel" "Screenshot" "Video capture" "Livestream")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select capture actions: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_capture_screenshot
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_capture_video
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			_live_stream
		else
			_warning "Invalid choice. Please try again"
			continue
		fi
	done
}

_capture_screenshot () {
	local source_path destination_path
	source_path="/sdcard/Pictures/Screenshots"

	if [[ -v ADBH_PATH ]]; then
		destination_path="$ADBH_PATH/pictures/screenshots"
	else
		read -e -r -p "Local path to store screenshot: " -i "$HOME/" destination_path
	fi

	local result result_code
	result=$(mkdir --parent "$destination_path")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	local filename file_source_path
	filename="screenshot_$(date +"%Y%m%d-%H%M%S").png"
	file_source_path="$source_path/$filename"


	result=$(_adb "shell mkdir --parent ${source_path}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	_warning "- Device directory destination exists ${source_path}"

	result=$(_adb "shell screencap ${file_source_path}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	_warning "- Screenshot taken and stored at ${file_source_path}"

	result=$(_pull_file "$file_source_path" "$destination_path")
	result_code=$?
	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	_warning "- File pulled to ${destination_path}/${filename}"

	local selection
	if [[ -v ADBH_AUTO_DELETE ]]; then
		selection="Yes"
	else
		local options=("Yes" "No")
		_prompt_selection_menu "Delete file on device?: " selection "${options[@]}"
		result_code=$?

		if [[ $result_code -ne 0 ]]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: Selection failed!"
			return $result_code
		fi
	fi

	if [[ "$selection" == "No" ]]; then
		return 0
	fi

	result=$(_delete_path "$file_source_path")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	_warning "- On device file removed"
}

_capture_video () {
	local source_path destination_path
	source_path="/sdcard/Movies"

	if [[ -v ADBH_PATH ]]; then
		destination_path="$ADBH_PATH/videos"
	else
		read -e -r -p "Local path to store video: " -i "$HOME/" destination_path
	fi

	local result result_code
	result=$(mkdir --parent "$destination_path")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "$result"
		return $result_code
	fi


	local show_touches
	while true; do
		read -e -r -p "Enable 'show screen touches'? (y/n): " show_touches
		if [[ "$show_touches" != "y" && "$show_touches" != "n" ]]; then
			_warning "Answer only y for 'yes' or n for 'no'"
		else
			break;
		fi
	done

	if [ "$show_touches" == "y" ]; then
		_warning "- Turning touch visualization on"

		result=$(_set_show_screen_touches "1")
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
			return $result_code
		fi
	else
		result=$(_set_show_screen_touches "0")
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
			return $result_code
		fi
	fi

	local filename file_source_path
	filename="video_capture_$(date +"%Y%m%d-%H%M%S").mp4"
	file_source_path="$source_path/$filename"

	result=$(_adb "shell mkdir --parent $source_path")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	_warning "- On-device directory created: ${source_path}."

	_prompt "- Capturing! End capture with 'CTRL+C'"

	trap '_warning "\n- Capture ended."' SIGINT

	result=$(_adb "shell screenrecord $file_source_path")
	result_code=$?

	trap - SIGINT

	if [ $result_code -ne 0 ] && [ $result_code -ne 130 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	_warning "- Sleeping until buffer to flush data."

	# Sleeping until the local file is found on the device. It can take the on device
	# buffer some time to finish writing to disk.
	while true; do
		sleep 1
		result=$(_adb "shell [ -e ${file_source_path} ] && echo 'YES' || echo 'NO'")
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
			return $result_code
		elif [[ "$result" == "YES" ]]; then
			break
		fi
	done

	_warning "- Video captured under: ${file_source_path}."

	if [ "$show_touches" == "y" ]; then
		_warning "- Turning touch visualization off."

		result=$(_set_show_screen_touches "0")
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
			return $result_code
		fi
	fi

	result=$(_pull_file "$file_source_path" "$destination_path")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	_warning "- File pulled to: ${destination_path}/${filename}."

	local selection
	if [[ -v ADBH_AUTO_DELETE ]]; then
		selection="Yes"
	else
		local options=("Yes" "No")
		_prompt_selection_menu "Delete file on device?: " selection "${options[@]}"
		result_code=$?

		if [[ $result_code -ne 0 ]]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: Selection failed!"
			return $result_code
		fi
	fi

	if [[ "$selection" == "No" ]]; then
		return 0
	fi

	result=$(_delete_path "$file_source_path")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

	_warning "- On device file removed"
}

_live_stream () {
	if ! command -v scrcpy &> /dev/null; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: 'scrcpy' was not found on path! Live streaming cancelled."
		return 0
	fi

	local temp_device=0
	if [[ ! -v ADBH_SERIAL_NUMBER || ! -v ADBH_SOURCE_FLAG || "$ADBH_SOURCE_FLAG" != "-s" ]]; then
		temp_device=1
		_warning "Using scrcpy in multi device environment requires selecting a serial number."

		local result result_code

		result=$(_get_serial_numbers "select trigger")
		result_code=$?

		if [  $result_code -ne 0 ]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
			return $result_code
		fi

		local ADBH_SERIAL_NUMBER="$result"
	fi

	_prompt "Streaming. End with CTRL+C"

	scrcpy -s "$ADBH_SERIAL_NUMBER"

	if [ $temp_device == 1 ]; then
		unset ADBH_SERIAL_NUMBER
	fi
}
