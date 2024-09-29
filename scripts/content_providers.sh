#!/usr/bin/env bash
# -----------------------------------------------------------------------------
#
# This script contains functionality specifically for interacting with
# content providers.
#
# It's entry point is '_select_content_provider_action()'
#
# -----------------------------------------------------------------------------

_select_content_provider_action () {
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

	local operations
	operations=("Cancel" "Package specific actions" "Query a content provider")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select action:" selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			local result result_code package package_with_uid
			package_with_uid=$(_select_package)
			result_code=$?

			if [[ $result_code -eq $CODE_CANCEL ]]; then
				continue;
			fi

			package=$(echo "$package_with_uid" | cut -f 2 -d ":" | cut -f 1 -d " ")

			_select_package_content_provider_action "$package"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_query_content_provider
		else
			error "${BASH_SOURCE[0]}, lineno: $LINENO: Unknown action selection! Exiting."
			exit 1
		fi
	done
}

_select_package_content_provider_action () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package="$1"

	local operations selected_operation
	operations=("Cancel" "List providers" "Analyze providers" "Query providers")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select content provider action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_list_package_content_providers "$package"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_analyze_package_content_providers "$package"
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			_query_package_content_provider "$package"
		else
			error "${BASH_SOURCE[0]}, lineno: $LINENO: Unknown action selection! Exiting."
			exit 1
		fi
	done
}

_get_package_content_providers () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code
	package="$1"

	result=$(_adb "shell dumpsys package ${package}" \
		| awk \
			-v start="ContentProvider Authorities:" \
			-v end="Key Set Manager:" '
			$0 ~ start {capture=1; next}
			$0 ~ end {capture=0}
			capture' \
		|  awk -F'[][]' '{if ($2) print $2}')
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	echo "${result[@]}"
}

_list_package_content_providers () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code
	package="$1"

	result=$(_get_package_content_providers "$package")
	result_code=$?

	local content_providers=()
	IFS=$'\n' read -r -d '' -a content_providers <<< "$result"

	if [  ${#content_providers[@]} -eq 0 ]; then
		_warning "There are no content providers defined for ${package}"
		return 0
	else
		_warning "- The following content providers were found for package '${package}'"

		for provider in "${content_providers[@]}"; do
			_print "- ${provider}"
		done
	fi
}

_analyze_package_content_providers () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code

	package="$1"
	result=$(_get_package_content_providers "$package")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local content_providers=()
	IFS=$'\n' read -r -d '' -a content_providers <<< "$result"

	if [  ${#content_providers[@]} -eq 0 ]; then
		_warning "There are no content providers defined for ${package}"
		return 0
	fi

	local content_provider export_status=()
	local row_number=0
	local percentage=0
	local number_of_providers=${#content_providers[@]}
	for index in "${!content_providers[@]}"; do
		content_provider="${content_providers[$index]}"

		(( row_number+=1 ))
		percentage=$(_percent "$row_number" "$number_of_providers")

		echo -ne " - Querying content providers (${row_number}/${number_of_providers}): ${percentage}% \r"

		local tmp_file
		tmp_file=$(mktemp)

		result=$(_adb "shell content query --uri content://${content_provider} > ${tmp_file}")
		result_code=$?

		if [ $result_code -ne 0 ]; then
			_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
			return $result_code
		fi

		if grep -q "Permission Denial" "$tmp_file"; then
			export_status+=("Private")
		else
			export_status+=("Exported")
		fi
	done

	_warning "The following content providers were found for package '${package}':"

	local status
	for index in "${!content_providers[@]}"; do
		content_provider="${content_providers[$index]}"
		status="${export_status[$index]}"

		if [ "$status" == "Exported" ]; then
			_warning " - ${content_provider}: [$status]"
		else
			_print " - ${content_provider}: [$status]"
		fi
	done
}

_query_package_content_providers () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code
	package="$1"

	result=$(_get_package_content_providers "$package" | fzf --prompt "Select provider to query (CTRL-C to cancel): ")
	result_code=$?

	if [ $result_code -eq 130 ]; then
		return "$CODE_CANCEL"
	elif [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local content_provider query

	content_provider="$result"

	trap 'trap - SIGINT; _print "\n"; return $CODE_CANCEL' SIGINT

	read -e -r -p "Write query: content://${content_provider}" query

	trap - SIGINT

	_warning "- Making query: content://${content_provider}${query}"

	result=$(_adb "shell content query --uri content://${content_provider}${query}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	else
		_print "$result"
	fi
}

_get_content_providers () {
	local  result result_code

	result=$(_adb "shell dumpsys package providers" \
		| awk \
			-v start="ContentProvider Authorities:" \
			-v end="Key Set Manager:" '
			$0 ~ start {capture=1; next}
			$0 ~ end {capture=0}
			capture' \
		|  awk -F'[][]' '{if ($2) print $2}')
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	echo "${result[@]}"
}

_query_content_provider () {
	local  result result_code

	result=$(_get_content_providers | fzf --prompt "Select provider to query (CTRL-C to cancel): ")
	result_code=$?

	if [ $result_code -eq 130 ]; then
		return "$CODE_CANCEL"
	elif [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local content_provider query

	content_provider="$result"

	trap 'trap - SIGINT; _print "\n"; return $CODE_CANCEL' SIGINT

	read -e -r -p "Write query: content://${content_provider}" query

	trap - SIGINT

	_warning "- Making query: content://${content_provider}${query}"

	result=$(_adb "shell content query --uri content://${content_provider}${query}" )
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	else
		echo "$result" | less -S -R -N
	fi
}
