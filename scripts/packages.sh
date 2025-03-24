#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# This script contains functionality for interacting with the packages
# installed on devices.
#
# It's entry point is '_select_global_package_action()'
# -----------------------------------------------------------------------------

_select_global_package_action () {
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
	operations=("Cancel" "Select specific package" "Trim global cache")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select action:" selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_select_package_action
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_clear_global_package_cache
		else
			error "${BASH_SOURCE[0]}, lineno: $LINENO: Unknown action selection! Exiting."
			exit 1
		fi
	done
}

_clear_global_package_cache () {
	_info "- This action will clear a LRU sorted list of cache files accross all applications"

	local answer

	read -e -r -p "Select size to free up (e.g 12G or 200M): " answer

	if [[ ! "$answer" =~ ^-?[0-9]+[MG]$ ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Input is not a integer followed by a G or M (e.g 12G or 200M)!"
		return 1
	fi

	local result result_code
	result=$(_adb "shell pm trim-caches ${answer}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_select_package_action () {
	local result result_code package package_with_uid package_uid
	package_with_uid=$(_select_package)
	result_code=$?

	if [[ $result_code -eq $CODE_CANCEL ]]; then
		return "$CODE_CANCEL"
	fi

	package=$(echo "$package_with_uid" | cut -f 2 -d ":" | cut -f 1 -d " ")
	package_uid=$(echo "$package_with_uid" | cut -f 3 -d ":")

	local option_package_enable="Enable package"
	local option_package_disable="Disable package"

	while true; do
		_warning "Selected package: ${package}"

		local package_is_disabled
		package_is_disabled=$(_is_package_disabled "$package")

		local disable_option
		if [ "$package_is_disabled" == "true" ]; then
			disable_option="$option_package_enable"
		else
			disable_option="$option_package_disable"
		fi

		local operations
		operations=("Cancel" "Select a different package" "Open package settings" "Info" "Version" "Logcat" "Run As" "Start main launcher" "Force stop" "Storage managment" "$disable_option" "Uninstall" "Pull APK" "Permissions"  "Databases" "Shared Preferences" "Content Providers" "Urls" "Oh look! A three-headed monkey")

		local selected_operation
		_prompt_selection_menu "Select package action:" selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			package_with_uid=$(_select_package)
			result_code=$?

			if [[ $result_code -eq $CODE_CANCEL ]]; then
				return "$CODE_CANCEL"
			fi

			package=$(echo "$package_with_uid" | cut -f 2 -d ":" | cut -f 1 -d " ")
			package_uid=$(echo "$package_with_uid" | cut -f 3 -d ":")
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_open_package_settings "$package"
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			_get_package_info "$package"
        elif [ "$selected_operation" == "${operations[4]}" ]; then
            _get_package_version "$package"
		elif [ "$selected_operation" == "${operations[5]}" ]; then
			_logcat_package "$package" "$package_uid"
		elif [ "$selected_operation" == "${operations[6]}" ]; then
			_run_as_package "$package"
		elif [ "$selected_operation" == "${operations[7]}" ]; then
			_launch_package "$package"
		elif [ "$selected_operation" == "${operations[8]}" ]; then
			_force_stop_package "$package"
		elif [ "$selected_operation" == "${operations[9]}" ]; then
			_select_package_storage_action "$package"
		elif [ "$selected_operation" == "$option_package_enable" ]; then
			_enable_package "$package"
		elif [ "$selected_operation" == "$option_package_disable" ]; then
			_disable_package "$package"
		elif [ "$selected_operation" == "${operations[11]}" ]; then
			_uninstall_package "$package"
		elif [ "$selected_operation" == "${operations[12]}" ]; then
			_pull_package_apk "$package"
		elif [ "$selected_operation" == "${operations[13]}" ]; then
			_select_package_permission_action "$package"
		elif [ "$selected_operation" == "${operations[14]}" ]; then
			_select_package_database_action "$package"
		elif [ "$selected_operation" == "${operations[15]}" ]; then
			_select_package_shared_preference_action "$package"
		elif [ "$selected_operation" == "${operations[16]}" ]; then
			_select_package_content_provider_action "$package"
		elif [ "$selected_operation" == "${operations[17]}" ]; then
			_select_package_url_action "$package"
		elif [ "$selected_operation" == "${operations[18]}" ]; then
			_release_monkey "$package"
		else
			error "${BASH_SOURCE[0]}, lineno: $LINENO: Unknown action selection! Exiting."
			exit 1
		fi

		RESULT_CODE=$?

		if [ $RESULT_CODE -eq 130 ]; then
			return "$CODE_CANCEL"
		fi
	done
}

_select_package () {
	local packages
	packages=$(_list_packages)

	local selected_package result_code
	selected_package=$(echo "${packages[@]}" | fzf --prompt="Please select a package: ")
	result_code=$?

	if [ $result_code -eq 130 ]; then
		return "$CODE_CANCEL"
	fi

	echo "${selected_package}"
}

_list_packages () {
	local result result_code
	result=$(_adb "shell pm list packages -U")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	else
		echo "${result[@]}"
	fi
}

_open_package_settings () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code
	package="$1"
	result=$(_adb "shell am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d 'package:${package}'")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_logcat_package () {
	if [ $# -ne 2 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects two input parameters!"
		exit 1
	fi

	local package package_uid result result_code
	package="$1"
	package_uid="$2"

	if [[ -v ADBH_USE_PIDCAT ]]; then
		pidcat package "$package"
	else
		_info "- Running Logcat in 2 seconds! Exit with 'CTRL+C'"

		# So info doesn't get lost
		sleep 2

		# Override default handler to allow for ctr-c
		trap 'echo -e "\n"; _warning "- Logging terminated"' SIGINT

		# shellcheck disable=SC2086
		adb $ADBH_SOURCE_FLAG $ADBH_SERIAL_NUMBER logcat --format=color --format=time --uid="${package_uid}"

		# Enable default handler again
		trap SIGINT
	fi
}

_get_package_info () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code

	package="$1"
	result=$(_adb "shell dumpsys package ${package}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	else
		echo "$result" | less
	fi
}

_get_package_version () {
    if [ $# -ne 1 ]; then
        _error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
        exit 1
    fi

    local package result result_code
    package="$1"
    result=$(_adb "shell dumpsys package ${package}" | grep versionName | cut -d'=' -f2)
    result_code=$?

    if [ $result_code -ne 0 ]; then
        _error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
        return $result_code
    else
        echo "$result"
    fi
}

_run_as_package () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package
	package="$1"

	local operations
	operations=("Cancel" "Shell as package" "Command as package")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select action:" selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_shell_as_package "$package"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_command_as_package "$package"
		else
			error "${BASH_SOURCE[0]}, lineno: $LINENO: Unknown action selection! Exiting."
			exit 1
		fi

		result_code=$?

		if [ $result_code -eq "$CODE_CANCEL" ]; then
			return "$CODE_CANCEL"
		fi
	done
}

_command_as_package () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package command result result_code
	package="$1"

	read -e -r -p "Input command: " command

	_adb "shell run-as ${package} ${command}"
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_shell_as_package () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package
	package="$1"

	_warning "Requires package to be in debug mode!"

	./adb_shell_expect.sh "${ADBH_SOURCE_FLAG}" "${ADBH_SERIAL_NUMBER}" "run-as $package"
}

_force_stop_package () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	_prompt "Force stopping package!"

	local package result result_code
	package="$1"
	result=$(_adb "shell am force-stop ${package}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_launch_package () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	_prompt "Launching package!"

	local package result result_code

	package="$1"
	result=$(_adb "shell cmd package resolve-activity ${package}" | awk -F= '/name=/{print $2;exit}')
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local activity_intent="${package}/${result}"
	result=$(_adb "shell am start -n ${activity_intent}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_select_package_storage_action () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package
	package="$1"

	local operations
	operations=("Cancel" "Clear all" "Clear cache")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select action:" selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_clear_package_storage "$package"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_clear_package_cache "$package"
		else
			error "${BASH_SOURCE[0]}, lineno: $LINENO: Unknown action selection! Exiting."
			exit 1
		fi

		result_code=$?

		if [ $result_code -eq "$CODE_CANCEL" ]; then
			return "$CODE_CANCEL"
		fi
	done
}

_clear_package_cache () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package answer
	package="$1"

	_warning "- Clearing cache for package: ${package}"

	local result result_code
	result=$(_adb "shell pm clear --cache-only ${package}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_clear_package_storage () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package answer
	package="$1"

	local options=("Yes" "No")
	local answer

	_prompt_selection_menu "Clear all application data for ${package}?: " answer "${options[@]}"
	result_code=$?

	if [[ $result_code -ne 0 ]]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Selection failed!"
		return $result_code
	elif [[ "$answer" == "No" ]]; then
		return "$CODE_CANCEL"
	fi

	_warning "- Clearing application data for package: ${package}"

	local result result_code
	result=$(_adb "shell pm clear ${package}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_disable_package () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	_warning "- Disabling package"

	local package result result_code
	package="$1"

	result=$(_adb "shell pm disable-user --user cur ${package}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "$result"
		return $result_code
	fi
}

_enable_package () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	_warning "- Enabling package"

	local package result result_code

	package="$1"
	result=$(_adb "shell pm enable --user cur ${package}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_is_package_disabled () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code

	package="$1"
	result=$(_adb "shell pm list packages -d" | grep "$package")
	result_code=$?

	if [ "$result" == "package:${package}" ]; then
		echo "true"
	else
		echo "false"
	fi
}

_uninstall_package () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package answer keep_flag

	package="$1"

	while true; do
		read -e -r -p "Would you like to keep application data for ${package}? (y/n): " answer

		if [[ "$answer" != "y" && "$answer" != "n" ]]; then
			_warning "Answer only 'y' for 'yes' or 'n' for 'no'"
		elif [[ "$answer" == "y" ]]; then
			break;
		elif [[ "$answer" == "n" ]]; then
			keep_flag="-k"
			break;
		fi
	done

	_warning "Uninstalling package ${package}!"

	local result result_code
	result=$(_adb "shell pm uninstall ${keep_flag} ${package}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_select_package_permission_action () {
	local operations
	operations=("Cancel" "List permissions" "Revoke all permissions" "Modify runtime permissions")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select permission action:" selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_list_package_permissions "$package"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_reset_package_permissions "$package"
		elif [ "$selected_operation" == "${operations[3]}" ]; then
			_modify_runtime_permissions "$package"
		else
			error "${BASH_SOURCE[0]}, lineno: $LINENO: Unknown action selection! Exiting."
			exit 1
		fi

		result_code=$?

		if [ $result_code -eq "$CODE_CANCEL" ]; then
			return "$CODE_CANCEL"
		fi
	done
}

_list_package_permissions () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code

	package="$1"
	result=$(_adb "shell dumpsys package ${package}" \
		| awk \
			-v start="declared permissions:" \
			-v end="User 0:" '
			$0 ~ start {capture=1; next}
			$0 ~ end {capture=0}
			capture' \
		| sed \
			-e 's/: granted=true//g' \
			-e 's/: granted=false//g' \
			-e 's/install permissions://g' \
			-e 's/requested permissions://g' \
			-e 's/: prot=signature, INSTALLED//g' \
		| grep -v '^[[:space:]]*$' \
		| sort -u \
		| fzf --prompt "Filter package permissions: "
		)

	result_code=$?

	if [ $result_code -ne 0 ] && [ $result_code -ne 130 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_reset_package_permissions () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package answer result result_code

	package="$1"

	while true; do
		read -e -r -p "Revoking all permissions for package: '${package}'? (y/n): " answer

		if [[ "$answer" != "y" && "$answer" != "n" ]]; then
			_warning "Answer only 'y' for 'yes' or 'n' for 'no'"
		elif [[ "$answer" == "y" ]]; then
			break;
		elif [[ "$answer" == "n" ]]; then
			return "$CODE_CANCEL"
		fi
	done

	_warning "Revoking all permissions for package: '$package'"

	result=$(_adb "shell pm reset-permissions -p ${package}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_modify_runtime_permissions () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code

	package="$1"

	result=$(_adb "shell dumpsys package ${package}" \
		| awk \
			-v start="runtime permissions:" \
			-v end="Queries:" '
			$0 ~ start {capture=1; next}
			$0 ~ end {capture=0}
			capture'
		)

	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local results_array=()
	IFS=$'\n' read -r -d '' -a results_array <<< "$result"

	local permission granted permissions_grant_status permissions_options permissions_array=()

	for item in "${results_array[@]}"; do
		permission=$(echo "$item" | grep -o 'android.permission.[^:]*')

		if [ -n "$permission" ]; then
			granted=$(echo "$item" | grep -o 'granted=[^,]*' | awk -F= '{print $2}')

			permissions_array+=("$permission")
			permissions_options+="$permission;"
			permissions_grant_status+="$granted;"
		fi
	done

	_prompt "Select permissions to grant. Unselected ones will be revoked. Press 'c' to cancel."
	_warning "- Alreayd granted permissions are pre-selected"

	local selected_indexes
	_multiselect selected_indexes "$permissions_options" "$permissions_grant_status"
	result_code=$?

	_print ""

	if [ $result_code -eq "$CODE_CANCEL" ]; then
		_warning "- Cancelling permissions modification"
		return "$CODE_CANCEL"
	elif [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local selected_options unselected_options
	for index in "${!selected_indexes[@]}"; do
		permission="${permissions_array[$index]}"

		if [ "${selected_indexes[$index]}" == "true" ]; then
			selected_options+=("$permission")
		else
			unselected_options+=("$permission")
		fi
	done

	if [ ${#selected_options[@]} -ne 0 ]; then
		_info "- Granting permissions:"

		for item in "${selected_options[@]}"; do
			_warning "- Granting ${item}"

			result=$(_adb "shell pm grant ${package} ${item}")

			if [ $result_code -ne 0 ]; then
				_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
				return $result_code
			fi

			sleep 0.3
		done

		_print ""
	fi

	if [ ${#unselected_options[@]} -ne 0 ]; then
		_info "- Revoking permissions:"

		for item in "${unselected_options[@]}"; do
			_warning "- Revoking ${item}"

			result=$(_adb "shell pm revoke ${package} ${item}")

			if [ $result_code -ne 0 ]; then
				_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
				return $result_code
			fi

			sleep 0.3
		done

		_print ""
	fi
}

_pull_package_apk () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

    local package destination_path
	package="$1"

	if [[ -v ADBH_PATH ]]; then
		destination_path="$ADBH_PATH/packages/${package}/apks"
	else
		read -e -r -p "Select where to store APK: " -i "$HOME/" destination_path
	fi

    local result result_code
	result=$(mkdir --parent "$destination_path")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
		return $result_code
	fi

    local package_version
    result=$(_get_package_version "${package}")
    result_code=$?

    if [ $result_code -ne 0 ]; then
        _error "${BASH_SOURCE[0]}, lineno: $LINENO: ${result}"
        return $result_code
    else
        package_version=$result
    fi

	destination_path="${destination_path}/${package}.${package_version}.apk"

	result=$(_adb "shell pm list package -f ${package}" )
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local filtered_result
	if [ "$(echo "$result" | wc -l)" -gt 1 ]; then
		# More than one line was returned matching the selected package name
		local result_array=()
		IFS=' ' read -ra result_array <<< "$result"

		for item in "${result_array[@]}"; do
			local package_name
			package_name=$(echo "$item" | awk -F"base.apk=" '{print $2}')

			if [[ "$package_name" == "$package" ]]; then
				filtered_result="$item"
				break
			fi
		done
	else
		filtered_result="$result"
	fi

	local parsed_result
	parsed_result=$(echo "$filtered_result" | awk -F"package:" '{print $2}' | awk -F"=$package" '{print $1}')
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $parsed_result"
		return $result_code
	fi

	local package_apk_path
	package_apk_path="$parsed_result"

	_warning "- Pulling base.apk for '${package}' to '${destination_path}'"

	result=$(_adb "pull ${package_apk_path} ${destination_path}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_select_package_database_action () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package="$1"

	_warning "These actions requires the selected package to be in debug mode!"

	local operations selected_operation
	operations=("Cancel" "Pull database" "Push database")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select database action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_pull_package_database "$package"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_push_package_database "$package"
		else
			error "Unknown action selection! Exiting."
			exit 1
		fi
	done
}

_pull_package_database () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code
	package="$1"

	result=$(_adb "shell run-as ${package} ls './databases'")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"

		if [[ "$result" == "ls: ./databases: No such file or directory" ]]; then
			_warning "Has application been cleared or never run?"
		fi

		return $result_code
	fi

	result=$(echo "$result" | fzf --prompt="Select a database file: ")
	result_code=$?

	if [ $result_code -eq 130 ]; then
		return "$CODE_CANCEL"
	elif [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local destination_path database_file_path
	database_file_path="/data/data/${package}/databases/${result}"

	if [[ -v ADBH_PATH ]]; then
		destination_path="$ADBH_PATH/packages/${package}/databases/${result}"
	else
		read -e -r -p "Select where to store the database: " -i "$HOME/" destination_path
	fi

	if [ ! -d "$destination_path" ]; then
		mkdir --parent "$destination_path"
	fi

	destination_path="${destination_path}/${result}"

	_info "Pulling '${database_file_path}' to '${destination_path}'"

	result=$(_adb "shell run-as ${package} cat ${database_file_path} > ${destination_path}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_push_package_database () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package database_file_path
	package="$1"

	read -e -r -p "Select database file to push: " -i "$HOME/" database_file_path

	local file_name
	file_name=$(basename "$database_file_path")

	_info "Pushing '${database_file_path}' to '/data/data/${package}/databases/${file_name}'"

	local result result_code
	result=$(_adb "push '${database_file_path}' '/data/local/tmp/${file_name}'")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	result=$(_adb "shell run-as ${package} cp '/data/local/tmp/${file_name}' databases")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_select_package_shared_preference_action () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package
	package="$1"

	_warning "These actions requires the selected package to be in debug mode!"

	local operations selected_operation
	operations=("Cancel" "Pull preferences" "Modify preferences")

	while true; do
		local selected_operation
		_prompt_selection_menu "Select preference action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_pull_package_shared_preference "$package"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_modify_package_shared_preference "$package"
		else
			error "${BASH_SOURCE[0]}, lineno: $LINENO: Unknown action selection! Exiting."
			exit 1
		fi
	done
}

_select_package_shared_preference () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code
	package="$1"

	result=$(_adb "shell run-as ${package} ls './shared_prefs'")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	elif [[ -z "$result" ]]; then
		_warning "No shared preferences were found for package ${package}"
		return "$CODE_CANCEL"
	fi

	result=$(echo "$result" | fzf --prompt="Select a preference file: ")

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	echo "$result"
}

_pull_package_shared_preference () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code
	package="$1"

	result=$(_select_package_shared_preference "$package")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		return $result_code
	fi

	local destination_path preference_file_path
	preference_file_path="/data/data/${package}/shared_prefs/${result}"

	if [[ -v ADBH_PATH ]]; then
		destination_path="$ADBH_PATH/packages/${package}/shared_prefs/${result}"
	else
		read -e -r -p "Select where to store the preferences: " -i "$HOME/" destination_path
	fi

	if [ ! -d "$destination_path" ]; then
		mkdir --parent "$destination_path"
	fi

	destination_path="${destination_path}/${result}"

	_info "Pulling '${preference_file_path}' to '${destination_path}'"

	result=$(_adb "shell run-as ${package} cat '${preference_file_path}' > '${destination_path}'" )
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	echo "$destination_path"
}

_modify_package_shared_preference () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code
	package="$1"

	result=$(_pull_package_shared_preference "$package")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local preference_file_path="$result"

	command $ADBH_EDITOR "$preference_file_path"
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	else
		_warning "Local copy of shared preference file was modified!"
	fi

	local file_name
	file_name=$(basename "$preference_file_path")

	_info "Pushing '${preference_file_path}' to '/data/data/${package}/shared_prefs/${file_name}'"

	result=$(_adb "push '$preference_file_path' '/data/local/tmp'")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	result=$(_adb "shell run-as '${package}' cp '/data/local/tmp/${file_name}' shared_prefs")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local answer

	while true; do
		read -e -r -p "Delete local file? (y/n): " answer

		if [[ "$answer" != "y" && "$answer" != "n" ]]; then
			_warning "Answer only 'y' for 'yes' or 'n' for 'no'"
		elif [[ "$answer" == "y" ]]; then
			rm "$preference_file_path"
			_warning "Local copy of shared preference file was deleted!"
			break;
		elif [[ "$answer" == "n" ]]; then
			break;
		fi
	done
}

_select_package_url_action () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package="$1"

	local option_default_on="Enable 'Open by default'"
	local option_default_off="Disable 'Open by default'"

	while true; do
		local default_open_allowed=
		default_open_allowed=$(_get_package_allowed_default_url_opening "$package")

		local toggle_option=
		if [ "$default_open_allowed" == "false" ]; then
			toggle_option="$option_default_on"
		else
			toggle_option="$option_default_off"
		fi

		local operations=("Cancel" "List package url" "List package verified urls" "$toggle_option")

		local selected_operation=
		_prompt_selection_menu "Select url action: " selected_operation "${operations[@]}"

		if [ "$selected_operation" == "${operations[0]}" ]; then
			return "$CODE_CANCEL"
		elif [ "$selected_operation" == "${operations[1]}" ]; then
			_open_package_url "$package"
		elif [ "$selected_operation" == "${operations[2]}" ]; then
			_list_package_urls "$package"
		elif [ "$selected_operation" == "$option_default_on" ]; then
			_toggle_package_default_url_opening "$package" "true"
		elif [ "$selected_operation" == "$option_default_off" ]; then
			_toggle_package_default_url_opening "$package" "false"
		else
			error "Unknown action selection! Exiting."
			exit 1
		fi
	done
}

_open_package_url () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code

	package="$1"
	result=$(_adb "shell dumpsys package ${package}" \
		| awk \
		-v start="Schemes" \
		-v end="Non-Data Actions:" \
		'
		$0 ~ start {capture=1; next}
		$0 ~ end {capture=0}
		capture
		' \
		| awk \
		'{
			# The following code is run on every input line.
			#
			# It determines where url scheme sections are, captures
			# the scheme and authority information and prints out
			# combinations of the two.
			#
			# It will not print the last captured scheme, but the
			# END block below takes care of that.

			line_number = NR
			indent_level = 0
			is_scheme = index($0, "Scheme:") > 0
			is_authority = index($0, "Authority:") > 0

			# Figure out the indentation level
			while (substr($0, indent_level + 1, 1) == " ") {
				indent_level++
			}

			is_start_of_section = indent_level == 6

			if (is_start_of_section && line_number != 0) {
				# This is the start of a section.
				# The section is not the first one.

				# Print combinations of schemes and authorities
				# from the previous section.
				for (i = 1; i <= scheme_items_count; i++) {
					scheme = scheme_items[i]

					if (authority_items_count != 0) {
						for (j = 1; j <= authority_items_count; j++) {
							print scheme "://" authority_items[j]
						}
					} else {
						print scheme "://"
					}
				}

				# Reset variables for the new section
				scheme_items_count = 0
				authority_items_count = 0
				delete scheme_items
				delete authority_items

			} else if (is_scheme || is_authority) {

				# Extract the text after the colon
				split($0, parts, ":")
				text_after_colon = (length(parts) > 1) ? parts[2] : ""

				# Remove all spaces from extracted text
				gsub(/ /, "", text_after_colon)

				# Remove extra quotes from extracted text
				gsub(/"/, "", text_after_colon)

				if (is_scheme) {
					# Line contains scheme information

					scheme_items_count++
					scheme_items[scheme_items_count] = text_after_colon
				} else if (is_authority) {
					# Line contains authority information

					authority_items_count++
					authority_items[authority_items_count] = text_after_colon
				}
			}
		}

		END {
			# Runs only once and at the end of processing all input.
			# Executes the same block of code as above when the start of a
			# new non first section is detected.

			# Print combinations of schemes and authorities
			# from the last captured section.
			for (i = 1; i <= scheme_items_count; i++) {
				scheme = scheme_items[i]

				if (authority_items_count != 0) {
					for (j = 1; j <= authority_items_count; j++) {
						print scheme "://" authority_items[j]
					}
				}
				else {
					print scheme "://"
				}
			}
		}' \
		| sort -u
		)

	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi

	local urls=()
	IFS=$'\n' read -r -d '' -a urls <<< "$result"

	if [ ${#urls[@]} -eq 0 ]; then
		_warning "- No defined urls were found for ${package}"
		return 0
	fi

	result=$(printf "%s\n" "${urls[@]}" | fzf --prompt="Select a url: ")
	result_code=$?

	if [ $result_code -eq 130 ]; then
		return "$CODE_CANCEL"
	elif [ $result_code -ne 0 ]; then
		_error "$result"
		return $result_code
	else
		_warning "- Broadcasting: ${result}"
	fi

	result=$(_adb "shell am start -W -a android.intent.action.VIEW -d ${result}")
	if [ $result_code -ne 0 ]; then
		_error "$result"
		return $result_code
	fi
}

_list_package_urls () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code
	package="$1"

	result=$(_adb "shell pm get-app-links --user cur ${package}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	else
		echo "$result" | less
	fi
}

_get_package_allowed_default_url_opening () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package result result_code
	package="$1"

	result=$(_adb "shell pm get-app-links --user cur ${package}" \
		| awk -F" Verification link handling allowed:" '{print $2}' \
		| tr '\n' ' ' \
		| awk -F, '//{gsub(/ /, "", $0); print}')
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	else
		echo "$result"
	fi
}

_toggle_package_default_url_opening () {
	if [ $# -ne 2 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects two input parameters!"
		exit 1
	fi

	local package toggle result result_code
	package="$1"
	toggle="$2"

	result=$(_adb "shell pm set-app-links-allowed --user cur --package ${package} ${toggle}")
	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}

_release_monkey () {
	if [ $# -ne 1 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: Function expects a single input parameter!"
		exit 1
	fi

	local package
	package="$1"

	local event_count
	while true; do
		read -e -r -p "Select event count (or c to cancel): " -i "1000" event_count

		if [[ "$event_count" == "c" ]]; then
			_warning "- Cancelling monkey run"
			return "$CODE_CANCEL"
		elif ! [[ $event_count =~ ^[0-9]+$ ]]; then
			_error "- Only whole integer numbers are allowed!"
		else
			break;
		fi
	done

	local throttle
	while true; do
		read -e -r -p "Set throttle in milliseconds (or c to cancel): " -i "300" throttle

		if [[ "$event_count" == "c" ]]; then
			_warning "- Cancelling monkey run"
			return "$CODE_CANCEL"
		elif ! [[ $event_count =~ ^[0-9]+$ ]]; then
			_error "- Only whole integer numbers are allowed!"
		else
			break;
		fi
	done

	local use_random_seed random_seed
	while true; do
		read -e -r -p "Use random seed (or c to cancel)? (y/n): " use_random_seed

		if [[ "$use_random_seed" == "c" ]]; then
			_warning "- Cancelling monkey run"
			return "$CODE_CANCEL"
		elif [[ "$use_random_seed" != "y" && "$use_random_seed" != "n" ]]; then
			_warning "Answer only y for 'yes' or n for 'no'"
		elif [[ "$use_random_seed" == "y" ]]; then
			read -e -r -p "Input random seed to use: " random_seed
			break
		else
			break
		fi
	done

	_warning "- Monkey will run amok for package: '$package'"

	local execute
	while true; do
		read -e -r -p "Press enter to execute (or c to cancel): " execute

		if [[ "$execute" == "c" ]]; then
			_warning "- Cancelling monkey run"
			return "$CODE_CANCEL"
		elif [[ -z $execute ]]; then
			_warning "- Running monkey!"
			break;
		else
			_error "Unknown input!"
		fi
	done

	local result result_code
	if [[ -v $random_seed ]]; then
		result=$(_adb "shell monkey -p ${package} -v ${event_count} -s ${random_seed} --throttle ${throttle}")
	else
		result=$(_adb "shell monkey -p ${package} -v ${event_count} --throttle ${throttle}")
	fi

	result_code=$?

	if [ $result_code -ne 0 ]; then
		_error "${BASH_SOURCE[0]}, lineno: $LINENO: $result"
		return $result_code
	fi
}
