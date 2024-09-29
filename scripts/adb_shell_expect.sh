#!/usr/bin/env expect
# -----------------------------------------------------------------------------
# Spawns a new adb shell and executes the incoming arguments
# leaving the user in the shell afterwards.
#
# Expects to receive at least 2 inputs: 
#
#	<device source flag>	-d, -e or -s depending on device
#
#	<device serial number>	If device source flag is -s this variable 
#								is required to contain the serial number.
#
#	<command>				The command to run.
# -----------------------------------------------------------------------------
set ADBH_SOURCE_FLAG [lindex $argv 0]
set ADBH_SERIAL_NUMBER [lindex $argv 1]
set COMMAND [join [lrange $argv 2 end]  " "]

spawn adb $ADBH_SOURCE_FLAG $ADBH_SERIAL_NUMBER shell
expect -re {\$}
send $COMMAND
send "\r"
interact
