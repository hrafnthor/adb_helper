# ADB Helper

An interactive cli tool that streamlines common ADB usage cases.

---


# Table of Contents
- [Introduction](#introduction)
- [Setup](#setup)
	- [Dependencies](#dependencies)
	- [Environment variables](#environment-variables)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)


# Introduction

This project aims to simplify frequently done tasks that involve the use of Android Debug Bridge (`adb`), in the hopes of making it's daily use more convenient.

While `adb` offers extensive amount of features, it is not the goal of this project to to cover all of them.

# Setup

<details open>
	<summary>Click here to collapse or expand section</summary><br />

Just clone this repository to a location on your computer:

```bash
git clone git@github.com:hrafnthor/adb_helper.git <LOCATION>
```

Give the main entrypoint script execution permissions:

```bash
chmod +x <LOCATION>/scripts/adb_helper.sh
```

Now you should be able to run it and see this prompt:

![Top level prompt of adb_helper](assets/images/adb_helper_prompt.gif)

<gif of >

## Dependencies

<details open>
	<summary>Click here to collapse or expand section</summary><br />

The following command line tools and utilities are used in ADBH and it will prompt with a warning if they are not found on the path.

### adb

"Android Debug Bridge is a versatile command-line tool that lets you communicate with a device."

[docs](https://developer.android.com/tools/adb)

Installation instruction can be found in the docs linked above. 

### awk

"AWK is a command line tool for manipulating streams of textual data"

[docs](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/awk.html)

| Platform | Method |
|----------| --------|
| Linux | Comes standard installed, otherwise check distribution's package manager |
| MacOS | Comes standard installed, otherwise check package manager (e.g. [Homebrew](https://brew.sh/)) |
| Windows | Check a package manager (e.g. [Chocolatey](https://community.chocolatey.org))|

### fzf

"fzf is a general-purpose command-line fuzzy finder"

[source](https://github.com/junegunn/fzf)


| Platform | Method |
|----------| --------|
| Linux | Check distribution's package manager |
| MacOS | Check package manager (e.g. [Homebrew](https://brew.sh/)) |
| Windows | WSL plus  (e.g. [Chocolatey](https://community.chocolatey.org))|

### grep

"Command line utility for searching plaintext datasets with regular expressions"

[docs](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html)

| Platform | Method |
|----------| --------|
| Linux | Comes standard installed, otherwise check distribution's package manager |
| MacOS | Comes standard installed, otherwise check package manager (e.g. [Homebrew](https://brew.sh/)) |
| Windows | Check a package manager (e.g. [Chocolatey](https://community.chocolatey.org))|

### less

"Less is a free, open-source file pager"

[source](https://www.greenwoodsoftware.com/less/index.html)

Is used for paging through large quantities of command output. 

| Platform | Method |
|----------| --------|
| Linux | Comes standard installed, otherwise check distribution's package manager |
| MacOS | Comes standard installed, otherwise check package manager (e.g. [Homebrew](https://brew.sh/)) |
| Windows | WSL should contain it otherwise check a package manager (e.g. [Chocolatey](https://community.chocolatey.org))|

### sort

Standard cli sorting utility. 

| Platform | Method |
|----------| --------|
| Linux | Comes standard installed, otherwise check distribution's package manager |
| MacOS | Comes standard installed, otherwise check package manager (e.g. [Homebrew](https://brew.sh/)) |
| Windows | WSL should contain it otherwise check a package manager (e.g. [Chocolatey](https://community.chocolatey.org))|

### sed

"**S**tream **ed**itor is a utility for parsing and transforming streams of text"

[docs](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/sed.html)


| Platform | Method |
|----------| --------|
| Linux | Comes standard installed, otherwise check distribution's package manager |
| MacOS | Comes standard installed, otherwise check package manager (e.g. [Homebrew](https://brew.sh/)) |
| Windows | WSL should contain it otherwise check a package manager (e.g. [Chocolatey](https://community.chocolatey.org))|

### bc - OPTIONAL

_"An arbitrary precision arithmetic language"_

[docs](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/bc.html)

This tool is only optionally needed, when initiating interactive control options (see [control section](#control)).

| Platform | Method |
|----------| --------|
| Linux | Comes standard installed, otherwise check distribution's package manager |
| MacOS | Comes standard installed, otherwise check package manager (e.g. [Homebrew](https://brew.sh/)) |
| Windows | WSL should contain it otherwise check a package manager (e.g. [Chocolatey](https://community.chocolatey.org))|

### expect - OPTIONAL

_"Expect is a tool for automating interactive applications."_

[source](https://core.tcl-lang.org/expect/index)

This tool is only optionally needed, when initiating a interactive shell as a specific package (see [package section](#packages)).


| Platform | Method |
|----------| --------|
| Linux | Check distribution's package manager |
| MacOS | Check package manager (e.g. [Homebrew](https://brew.sh/)) |
| Windows | Check a package manager (e.g. [Chocolatey](https://community.chocolatey.org))|


### scrcpy - OPTIONAL

_"A tool for displaying a controlling Android devices."_

[source](https://github.com/Genymobile/scrcpy)

This tool is only optionally needed, and is only used when triggering the livestreaming.

Instructions to install `scrcpy` can be found in [their documentation](https://github.com/Genymobile/scrcpy?tab=readme-ov-file#get-the-app).

</details>


## Environment variables

<details open>
	<summary>Click here to collapse or expand section</summary><br />

The helper will utilize the following environment variables if they are found:

| Variable | Description |
| ---------| ------------|
| ADBH_PATH | Specifies the local directory path where any media capture or APK downloads from devices will automatically be stored (user is not prompted for destination), and to which device mapping names are stored if `ADBH_MAPPING_PATH` is not set. |
| ADBH_MAPPING_PATH | Specifies the path (either file name or directory) to which the file containing device id and given name mappings will be stored. If this path is not defined, `ADBH_PATH` will be used. If `ADBH_PATH` is not defined, user will be prompted for location when naming devices. If it points to a directory that exists then a file named `adbh_serial_mapping` will be created at the path. |
| ADBH_EDITOR | If a specific preferred editor, other than the currently set `editor`, should be used when doing document modifications use this variable. |
| ADBH_DEBUG | If set (contents does not matter) then any commands sent to `adb` will be printed out as they are executed |
| ADBH_SOURCE_FLAG | Defines the source flags to use with `adb` (e.g. `-d`, `-s`. `-e`). It is not necessary to set this variable as `adb_helper` will prompt for device selection if none is found. If set to `-s` then `ADBH_SERIAL_NUMBER` will need to be set too. |
| ADBH_SERIAL_NUMBER | Defines the serial number of the device that should be used. Is only used if `ADBH_SOURCE_FLAG` is set to `-s`. It is not necessary to set this variable as `adb_helper` will prompt for device selection if none is found. |
| ADBH_AUTO_DELETE | If set will automatically delete files that get created on devices through actions taken in ADBH. An example of this would be when capturing screenshots or video of a device. After successful capture and transfer, the on-device files would be deleted automatically.
 

</details>

</details>

# Usage

For full usage information see the [project wiki](https://github.com/hrafnthor/adb_helper/wiki/ADB-Helper-wiki).

# License

```
Copyright 2024 Hrafn Thorvaldsson

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
