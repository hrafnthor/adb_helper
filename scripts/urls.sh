#!/usr/bin/env bash
# -----------------------------------------------------------------------------
#
# This script contains functionality for listing and interacting with
# system registered url schema.
#
# -----------------------------------------------------------------------------

_select_url_action () {
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
	operations=("Cancel" "Query url owner" "Resolve uri" "Resolve activity for uri" "Package urls")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select intent action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_query_app_link_owners
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_resolve_uri
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			_resolve_uri_activity
		elif [ "$selected_operation" == "${operations[4]}" ]; then
			_package_urls
		else
			error "Unknown action selection! Exiting."
			exit 1
		fi
	done
}

_package_urls () {
	local package package_with_uid result_code
	package_with_uid=$(_select_package)
	result_code=$?

	if [[ $result_code -eq $CODE_CANCEL ]]; then
		return "$CODE_CANCEL"
	fi

	package=$(echo "$package_with_uid" | cut -f 2 -d ":" | cut -f 1 -d " ")

	_select_package_url_action "$package"
}

_resolve_uri () {
	local uri result result_code

	read -e -r -p "Input uri: " uri

	result=$(_adb "shell am start -W -a android.intent.action.VIEW -d ${uri}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_resolve_uri_activity () {
	local uri result result_code

	_warning "- Optional schema needs to end with '://', followed by optional domain information."

	read -e -r -p "Input uri (i.e https://android.com or file://): " uri

	result=$(_adb "shell cmd package resolve-activity ${uri}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	else
		echo "$result" | less
	fi
}

_query_app_link_owners () {
	local url result result_code

	read -r -e -p "Input url: " url

	result=$(_adb "shell pm get-app-link-owners --user cur ${url}" | awk '/VERIFIED\[4\]/ || /UNVERIFIED\[-1\]/ {getline; print $1}' | fzf --prompt "Select package to perform actions or CTRL-C to cancel: ")
	result_code=$?

	if [ $result_code -eq 130 ]; then
		return "$CODE_CANCEL"
	elif [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	else
		_select_package_url_action "$result"
	fi
}
