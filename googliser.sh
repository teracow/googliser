#!/bin/bash

# Copyright (C) 2016 Teracow Software

# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

# If you find this code useful, please let me know. :) teracow@gmail.com

# The latest copy can be found here [https://github.com/teracow/googliser]

# return values ($?):
#	0	completed successfully
#	1	required program unavailable (wget, montage)
#	2	required parameter unspecified or wrong
#	3	could not create subdirectory for 'search phrase'
#	4	could not get a list of search results from Google
#	5	image download aborted as failure limit was reached or ran out of images
#	6	thumbnail gallery build failed
#	7	unable to create a temporary build directory

# debug log first character notation:
#	>	script entry
#	<	script exit
#	\	function entry
#	/	function exit
#	?	variable value
#	=	evaluation
#	~	variable had boundary issues so was set within bounds
#	$	success
#	!	failure
#	T	elapsed time

function Init
	{

	local script_version="1.22"
	local script_date="2016-08-19"
	script_file="googliser.sh"

	script_name="${script_file%.*}"
	local script_details="$(ColourTextBrightWhite "${script_file}") - v${script_version} (${script_date}) PID:[$$]"

	BuildEnviron

	if [ "$?" -gt "0" ] ; then
		echo "! Unable to create a temporary build directory! Exiting."

		exitcode=7
		return 1
	fi

	server="www.google.com.au"

	# http://whatsmyuseragent.com
	useragent='Mozilla/5.0 (X11; Linux x86_64; rv:46.0) Gecko/20100101 Firefox/46.0'

	# parameter defaults
	images_required_default=25
	parallel_limit_default=8
	fail_limit_default=40
	upper_size_limit_default=0
	lower_size_limit_default=1000
	timeout_default=15
	retries_default=3

	# internals
	script_starttime=$(date)
	script_startseconds=$(date +%s)
	target_path_created=false
	helpme=false
	show_version_only=false
	show_help_only=false
	google_max=1000
	parallel_max=40
	timeout_max=600
	retries_max=100
	max_results_required=$images_required_default

	# user changable parameters
	user_query=""
	images_required=$images_required_default
	fail_limit=$fail_limit_default
	parallel_limit=$parallel_limit_default
	timeout=$timeout_default
	retries=$retries_default
	upper_size_limit=$upper_size_limit_default
	lower_size_limit=$lower_size_limit_default
	create_gallery=true
	gallery_title=""
	links=false
	colour=false
	verbose=true
	remove_after=false
	debug=false
	skip_no_size=false

	WhatAreMyOptions

	exitcode=$?

	# display start
	if [ "$show_version_only" == "true" ] ; then
		echo "v${script_version} (${script_date})"
		verbose=false
	fi

	if [ "$create_gallery" == "false" ] && [ "$remove_after" == "true" ] ; then
		echo "Huh?"
		exit 2
	fi

	if [ "$verbose" == "true" ] ; then
		if [ "$colour" == "true" ] ; then
			echo " ${script_details}"
		else
			echo " $(RemoveColourCodes "${script_details}")"
		fi

		echo
	fi

	[ "$show_help_only" == "true" ] && DisplayHelp

	DebugThis "> started" "$script_starttime"
	DebugThis "? \$script_details" "$(RemoveColourCodes "${script_details}")"
	DebugThis "? \$user_parameters_raw" "$user_parameters_raw"
	DebugThis "= environment" "*** decoded user parameters ***"
	DebugThis "? \$user_query" "$user_query"
	DebugThis "? \$images_required" "$images_required"
	DebugThis "? \$fail_limit" "$fail_limit"
	DebugThis "? \$parallel_limit" "$parallel_limit"
	DebugThis "? \$timeout" "$timeout"
	DebugThis "? \$retries" "$retries"
	DebugThis "? \$upper_size_limit" "$upper_size_limit"
	DebugThis "? \$lower_size_limit" "$lower_size_limit"
	DebugThis "? \$create_gallery" "$create_gallery"
	DebugThis "? \$gallery_title" "$gallery_title"
	DebugThis "? \$links" "$links"
	DebugThis "? \$colour" "$colour"
	DebugThis "? \$verbose" "$verbose"
	DebugThis "? \$debug" "$debug"
	DebugThis "? \$skip_no_size" "$skip_no_size"
	DebugThis "? \$remove_after" "$remove_after"
	DebugThis "= environment" "*** internal parameters ***"
	DebugThis "? \$google_max" "$google_max"
	DebugThis "? \$temp_path" "$temp_path"

	IsReqProgAvail "wget" || exitcode=1

	if [ "$create_gallery" == "true" ] ; then
		IsReqProgAvail "montage" || exitcode=1
		IsReqProgAvail "convert" || exitcode=1
	fi

	IsOptProgAvail "identify" && ident=true || ident=false

	# 'nfpr=1' seems to perform exact string search - does not show most likely match results or suggested search.
	search_match_type="&nfpr=1"

	# 'tbm=isch' seems to search for images
	search_type="&tbm=isch"

	# 'q=' is the user supplied search query
	search_phrase="&q=$(echo $user_query | tr ' ' '+')"	# replace whitepace with '+' to suit curl/wget

	# 'hl=en' seems to be language
	search_language="&hl=en"

	# 'site=imghp' seems to be result layout style
	search_style="&site=imghp"

	trap CTRL_C_Captured INT

	}

function BuildEnviron
	{

	image_file="google-image"
	test_file="test-image"			# this is used during size testing
	imagelinks_file="download.links.list"
	debug_file="debug.log"
	gallery_name="googliser-gallery"
	current_path="$PWD"

	local temp_root="/dev/shm"
	temp_path=$(mktemp -p "${temp_root}" -d "$script_name.$$.XXX")
	[ "$?" -gt "0" ] && return 1

	results_run_count_path="${temp_path}/results.running.count"
	mkdir -p "${results_run_count_path}"
	[ "$?" -gt "0" ] && return 1

	results_success_count_path="${temp_path}/results.success.count"
	mkdir -p "${results_success_count_path}"
	[ "$?" -gt "0" ] && return 1

	results_fail_count_path="${temp_path}/results.fail.count"
	mkdir -p "${results_fail_count_path}"
	[ "$?" -gt "0" ] && return 1

	download_run_count_path="${temp_path}/download.running.count"
	mkdir -p "${download_run_count_path}"
	[ "$?" -gt "0" ] && return 1

	download_success_count_path="${temp_path}/download.success.count"
	mkdir -p "${download_success_count_path}"
	[ "$?" -gt "0" ] && return 1

	download_fail_count_path="${temp_path}/download.fail.count"
	mkdir -p "${download_fail_count_path}"
	[ "$?" -gt "0" ] && return 1

	testimage_pathfile="${temp_path}/${test_file}"
	results_pathfile="${temp_path}/results.page.html"
	gallery_title_pathfile="${temp_path}/gallery.title.png"
	gallery_thumbnails_pathfile="${temp_path}/gallery.thumbnails.png"
	gallery_background_pathfile="${temp_path}/gallery.background.png"
	imagelinks_pathfile="${temp_path}/${imagelinks_file}"
	debug_pathfile="${temp_path}/${debug_file}"

	return 0

	}

function DisplayHelp
	{

	DebugThis "\ [${FUNCNAME[0]}]" "entry"

	local sample_user_query="cows"
	local message=" - search '"

	if [ "$colour" == "true" ] ; then
		message+="$(ShowGoogle) $(ColourTextBrightBlue "images")"
	else
		message+="Google images"
	fi

	echo "${message}', download from each of the image URLs, then create a gallery image using ImageMagick."
	echo
	echo " - This is an expansion upon a solution provided by ShellFish on:"
	echo " [https://stackoverflow.com/questions/27909521/download-images-from-google-with-command-line]"
	echo
	echo " - Requirements: Wget"
	echo " - Optional: identify, montage & convert (from ImageMagick)"
	echo
	echo " - Questions or comments? teracow@gmail.com"
	echo

	if [ "$colour" == "true" ] ; then
		echo " - Usage: $(ColourTextBrightWhite "./$script_file") [PARAMETERS] ..."
	else
		echo " - Usage: ./$script_file [PARAMETERS] ..."
	fi

	echo
	echo " Mandatory arguments for long options are mandatory for short options too. Defaults values are shown in <>"
	echo

	if [ "$colour" == "true" ] ; then
		echo " $(ColourTextBrightOrange "* Required *")"
	else
		echo " * Required *"
	fi

	HelpParameterFormat "p" "phrase [STRING]" "Search phrase. A sub-directory will be created with this name."
	echo
	echo " Optional"
	HelpParameterFormat "a" "parallel [INTEGER] <$parallel_limit_default>" "How many parallel image downloads? Maximum of $parallel_max. Use wisely!"
	HelpParameterFormat "c" "colour" "Output with ANSI coloured text."
	HelpParameterFormat "d" "debug" "Save debug log to file [$debug_file] in target directory."
	HelpParameterFormat "e" "delete-after" "Remove all downloaded images afterwards."
	HelpParameterFormat "f" "failures [INTEGER] <$fail_limit_default>" "How many download failures before exiting? Use 0 for unlimited ($google_max)."
	HelpParameterFormat "g" "no-gallery" "Don't create thumbnail gallery."
	HelpParameterFormat "h" "help" "Display this help then exit."
	HelpParameterFormat "i" "title [STRING] <phrase>" "Custom title for thumbnail gallery. Enclose whitespace in quotes."
	HelpParameterFormat "k" "skip-no-size" "Don't download any image if its size cannot be determined."
	HelpParameterFormat "l" "lower-size [INTEGER] <$lower_size_limit_default>" "Only download images that are larger than this many bytes."
	HelpParameterFormat "n" "number [INTEGER] <$images_required_default>" "Number of images to download. Maximum of $google_max."
	HelpParameterFormat "q" "quiet" "Suppress standard message output. Error messages are still shown."
	HelpParameterFormat "r" "retries [INTEGER] <$retries_default>" "Retry image download this many times. Maximum of $retries_max."
	HelpParameterFormat "s" "save-links" "Save URL list to file [$imagelinks_file] in target directory."
	HelpParameterFormat "t" "timeout [INTEGER] <$timeout_default>" "Number of seconds before aborting each attempt. Maximum of $timeout_max."
	HelpParameterFormat "u" "upper-size [INTEGER] <$upper_size_limit_default>" "Only download images that are smaller than this many bytes. Use 0 for unlimited."
	HelpParameterFormat "v" "version " "Show script version then exit."
	echo
	echo " - Example:"

	if [ "$colour" == "true" ] ; then
		echo "$(ColourTextBrightWhite " $ ./$script_file -p \"${sample_user_query}\"")"
	else
		echo " $ ./$script_file -p \"${sample_user_query}\""
	fi

	echo
	echo " This will download the first $images_required_default available images for the search phrase \"${sample_user_query}\" and build them into a gallery image."

	DebugThis "/ [${FUNCNAME[0]}]" "exit"

	}

function WhatAreMyOptions
	{

	# if getopt exited with an error then show help to user
	[ "$user_parameters_result" != "0" ] && echo && show_help_only=true && return 2

	eval set -- "$user_parameters"

	while true ; do
		case "$1" in
			-n | --number )
				images_required="$2"
				shift 2		# shift to next parameter in $1
				;;
			-f | --failures )
				fail_limit="$2"
				shift 2		# shift to next parameter in $1
				;;
			-p | --phrase )
				user_query="$2"
				shift 2		# shift to next parameter in $1
				;;
			-a | --parallel )
				parallel_limit="$2"
				shift 2		# shift to next parameter in $1
				;;
			-t | --timeout )
				timeout="$2"
				shift 2		# shift to next parameter in $1
				;;
			-r | --retries )
				retries="$2"
				shift 2		# shift to next parameter in $1
				;;
			-u | --upper-size )
				upper_size_limit="$2"
				shift 2		# shift to next parameter in $1
				;;
			-l | --lower-size )
				lower_size_limit="$2"
				shift 2		# shift to next parameter in $1
				;;
			-i | --title )
				gallery_title="$2"
				shift 2		# shift to next parameter in $1
				;;
			-k | --skip-no-size )
				skip_no_size=true
				shift
				;;
			-s | --save-links )
				links=true
				shift
				;;
			-e | --delete-after )
				remove_after=true
				shift
				;;
			-h | --help )
				show_help_only=true
				return 7
				;;
			-c | --colour )
				colour=true
				shift
				;;
			-g | --no-gallery )
				create_gallery=false
				shift
				;;
			-q | --quiet )
				verbose=false
				shift
				;;
			-d | --debug )
				debug=true
				shift
				;;
			-v | --version )
				show_version_only=true
				return 7
				;;
			-- )
				shift		# shift to next parameter in $1
				break
				;;
			* )
				break		# there are no more matching parameters
				;;
		esac
	done

	}

function DownloadResultGroup_auto
	{

	# *** This function runs as a background process ***
	# $1 = page group to load:		(0, 1, 2, 3, etc...)
	# $2 = pointer starts at result:	(0, 100, 200, 300, etc...)
	# $3 = debug index identifier e.g. "02"

	local result=0
	local search_group="&ijn=$1"
	local search_start="&start=$2"
	local response=""
	local link_index="$3"

	local run_pathfile="$results_run_count_path/$link_index"
	local success_pathfile="$results_success_count_path/$link_index"
	local fail_pathfile="$results_fail_count_path/$link_index"

	DebugThis "- result group ($link_index) download" "start"

	local wget_list_cmd="wget --quiet 'https://${server}/search?${search_type}${search_match_type}${search_phrase}${search_language}${search_style}${search_group}${search_start}' --user-agent '$useragent' --output-document \"${results_pathfile}.$1\""
	DebugThis "? result group ($link_index) \$wget_list_cmd" "$wget_list_cmd"

	response=$(eval "$wget_list_cmd")
	result=$?

	if [ "$result" -eq "0" ] ; then
		DebugThis "$ result group ($link_index) download" "success!"
		mv "$run_pathfile" "$success_pathfile"
	else
		DebugThis "! result group ($link_index) download" "failed! Wget returned: ($result - $(WgetReturnCodes "$result"))"
		mv "$run_pathfile" "$fail_pathfile"
	fi

	return 0

	}

function RefreshResultsCounts
	{

	parallel_count=$(ls -I . -I .. "$results_run_count_path" | wc -l)
	success_count=$(ls -I . -I .. "$results_success_count_path" | wc -l)
	fail_count=$(ls -I . -I .. "$results_fail_count_path" | wc -l)

	}

function ShowResultDownloadProgress
	{

	if [ "$verbose" == "true" ] ; then
		if [ "$colour" == "true" ] ; then
			if [ "$success_count" -eq "$groups_max" ] ; then
				progress_message="$(ColourTextBrightGreen "${success_count}/${groups_max}")"
			else
				progress_message="$(ColourTextBrightOrange "${success_count}/${groups_max}")"
			fi
		else
			progress_message="${success_count}/${groups_max}"
		fi

		progress_message+=" result groups downloaded."

		ProgressUpdater "${progress_message}"
	fi

	}

function DownloadResultGroups
	{

	DebugThis "\ [${FUNCNAME[0]}]" "entry"

	local func_startseconds=$(date +%s)
	local groups_max=$(($google_max/100))
	local pointer=0
	local parallel_count=0
	local success_count=0
	local fail_count=0

	InitProgress

	if [ "$verbose" == "true" ] ; then
		if [ "$colour" == "true" ] ; then
			echo -n " -> searching $(ShowGoogle): "
		else
			echo -n " -> searching Google: "
		fi
	fi

	for ((group=1; group<=$groups_max; group++)) ; do
		# wait here until a download slot becomes available
		while [ "$parallel_count" -eq "$parallel_limit" ] ; do
			sleep 0.5

			RefreshResultsCounts
			ShowResultDownloadProgress
		done

		pointer=$((($group-1)*100))
		link_index=$(printf "%02d" $(($group-1)))

		# create run file here as it takes too long to happen in background function
		touch "$results_run_count_path/$link_index"
		{ DownloadResultGroup_auto "$(($group-1))" "$pointer" "$link_index" & } 2>/dev/null

		RefreshResultsCounts
		ShowResultDownloadProgress

		[ "$(($group*100))" -gt "$max_results_required" ] && break
	done

	# wait here while all running downloads finish
	wait 2>/dev/null

	RefreshResultsCounts
	ShowResultDownloadProgress

	# build all groups into a single file
	cat "${results_pathfile}".* > "${results_pathfile}"

	ParseResults

	[ "$fail_count" -gt "0" ] && result=1 || result=0

	DebugThis "T [${FUNCNAME[0]}] elapsed time" "$(ConvertSecs "$(($(date +%s)-$func_startseconds))")"
	DebugThis "/ [${FUNCNAME[0]}]" "exit"

	return $result

	}

function DownloadImage_auto
	{

	# *** This function runs as a background process ***
	# $1 = URL to download
	# $2 = debug index identifier e.g. "0026"

	local result=0
	local size_ok=true
	local get_download=true
	local response=""
	local link_index="$2"

	local run_pathfile="$download_run_count_path/$link_index"
	local success_pathfile="$download_success_count_path/$link_index"
	local fail_pathfile="$download_fail_count_path/$link_index"

	DebugThis "- link ($link_index) download" "start"

	# extract file extension by checking only last 5 characters of URL (to handle .jpeg as worst case)
	local ext=$(echo ${1:(-5)} | sed "s/.*\(\.[^\.]*\)$/\1/")

	[[ ! "$ext" =~ "." ]] && ext=".jpg"	# if URL did not have a file extension then choose jpg as default

	testimage_pathfileext="${testimage_pathfile}($link_index)${ext}"
	targetimage_pathfileext="${targetimage_pathfile}($link_index)${ext}"

	# are file size limits going to be applied before download?
	if [ "$upper_size_limit" -gt "0" ] || [ "$lower_size_limit" -gt "0" ] ; then
		# try to get file size from server
		local wget_server_response_cmd="wget --spider --server-response --max-redirect 0 --timeout=${timeout} --tries=${retries} --user-agent \"$useragent\" --output-document \"${testimage_pathfileext}\" \"$1\" 2>&1"
		DebugThis "? link ($link_index) \$wget_server_response_cmd" "$wget_server_response_cmd"

		response=$(eval "$wget_server_response_cmd")
		result=$?

		if [ "$result" -eq "0" ] ; then
			estimated_size=$(grep "Content-Length:" <<< "$response" | sed 's|^.*: ||' )

			if [ -z "$estimated_size" ] || [ "$estimated_size" == "unspecified" ] ; then
				estimated_size="unknown"
			fi

			DebugThis "? link ($link_index) \$estimated_size" "$estimated_size bytes"

			if [ "$estimated_size" != "unknown" ] ; then
				if [ "$estimated_size" -lt "$lower_size_limit" ] ; then
					DebugThis "! link ($link_index) (before download) is too small!" "$estimated_size bytes < $lower_size_limit bytes"
					size_ok=false
					get_download=false
				fi

				if [ "$upper_size_limit" -gt "0" ] && [ "$estimated_size" -gt "$upper_size_limit" ] ; then
					DebugThis "! link ($link_index) (before download) is too large!" "$estimated_size bytes > $upper_size_limit bytes"
					size_ok=false
					get_download=false
				fi
			else
				if [ "$skip_no_size" == "true" ] ; then
					DebugThis "! link ($link_index) unknown image size so" "failed!"
					get_download=false
				fi
			fi
		else
			DebugThis "! link ($link_index) (before download) server-response" "failed!"
			estimated_size="unknown"
		fi
	fi

	# perform actual image download
	if [ "$get_download" == "true" ] ; then
		local wget_download_cmd="wget --max-redirect 0 --timeout=${timeout} --tries=${retries} --user-agent \"$useragent\" --output-document \"${targetimage_pathfileext}\" \"$1\" 2>&1"
		DebugThis "? link ($link_index) \$wget_download_cmd" "$wget_download_cmd"

		response=$(eval "$wget_download_cmd")
		result=$?

		if [ "$result" -eq "0" ] ; then
			# http://stackoverflow.com/questions/36249714/parse-download-speed-from-wget-output-in-terminal
			download_speed=$(grep -o '\([0-9.]\+ [KM]B/s\)' <<< "$response")

			if [ -e "${targetimage_pathfileext}" ] ; then
				actual_size=$(wc -c < "$targetimage_pathfileext")

				if [ "$actual_size" == "$estimated_size" ] ; then
					DebugThis "? link ($link_index) \$actual_size" "$actual_size bytes (estimate was correct)"
				else
					DebugThis "? link ($link_index) \$actual_size" "$actual_size bytes (estimate of $estimated_size bytes was incorrect)"
				fi

				if [ "$actual_size" -lt "$lower_size_limit" ] ; then
					DebugThis "! link ($link_index) \$actual_size (after download) is too small!" "$actual_size bytes < $lower_size_limit bytes"
					rm -f "$targetimage_pathfileext"
					size_ok=false
				fi

				if [ "$upper_size_limit" -gt "0" ] && [ "$actual_size" -gt "$upper_size_limit" ] ; then
					DebugThis "! link ($link_index) \$actual_size (after download) is too large!" "$actual_size bytes > $upper_size_limit bytes"
					rm -f "$targetimage_pathfileext"
					size_ok=false
				fi
			else
				# file does not exist
				size_ok=false
			fi

			if [ "$size_ok" == "true" ] ; then
				RenameExtAsType "$targetimage_pathfileext"

				if [ "$?" -eq "0" ] ; then
					mv "$run_pathfile" "$success_pathfile"
					DebugThis "$ link ($link_index) image type validation" "success!"
					DebugThis "$ link ($link_index) download" "success!"
					DebugThis "? link ($link_index) \$download_speed" "$download_speed"
				else
					DebugThis "! link ($link_index) image type validation" "failed!"
				fi
			else
				# files that were outside size limits still count as failures
				mv "$run_pathfile" "$fail_pathfile"
			fi
		else
			mv "$run_pathfile" "$fail_pathfile"
			DebugThis "! link ($link_index) download" "failed! Wget returned $result ($(WgetReturnCodes "$result"))"

			# delete temp file if one was created
			[ -e "${targetimage_pathfileext}" ] && rm -f "${targetimage_pathfileext}"
		fi
	else
		mv "$run_pathfile" "$fail_pathfile"
	fi

	return 0

	}

function RefreshDownloadCounts
	{

	parallel_count=$(ls -I . -I .. "$download_run_count_path" | wc -l)
	success_count=$(ls -I . -I .. "$download_success_count_path" | wc -l)
	fail_count=$(ls -I . -I .. "$download_fail_count_path" | wc -l)

	}

function ShowImageDownloadProgress
	{

	if [ "$verbose" == "true" ] ; then
		# number of image downloads that are OK
		if [ "$colour" == "true" ] ; then
			progress_message="$(ColourTextBrightGreen "${success_count}/${images_required}")"
		else
			progress_message="${success_count}/${images_required}"
		fi

		progress_message+=" downloaded"

		# show the number of files currently downloading (if any)
		if [ "$parallel_count" -gt "0" ] ; then
			progress_message+=", "

			if [ "$colour" == "true" ] ; then
				progress_message+="$(ColourTextBrightOrange "${parallel_count}/${parallel_limit}")"
			else
				progress_message+="${parallel_count}/${parallel_limit}"
			fi

			progress_message+=" are in progress"
		fi

		# include failures (if any)
		if [ "$fail_count" -gt "0" ] ; then
			progress_message+=" and "

			if [ "$colour" == "true" ] ; then
				progress_message+="$(ColourTextBrightRed "${fail_count}/${fail_limit}")"
			else
				progress_message+="${fail_count}/${fail_limit}"
			fi

			progress_message+=" failed"
		fi

 		progress_message+="."

		ProgressUpdater "${progress_message}"
	fi

	}

function DownloadImages
	{

	DebugThis "\ [${FUNCNAME[0]}]" "entry"

	local func_startseconds=$(date +%s)
	local result_index=0
	local message=""
	local result=0
	local parallel_count=0
	local success_count=0
	local fail_count=0
	local imagelink=""

	[ "$verbose" == "true" ] && echo -n " -> acquiring images: "

	InitProgress

	while read imagelink ; do
		while true ; do
			RefreshDownloadCounts
			ShowImageDownloadProgress

			# abort downloading if too many failures
			if [ "$fail_count" -ge "$fail_limit" ] ; then
				DebugThis "! failure limit reached" "$fail_count/$fail_limit"

				result=1

				wait 2>/dev/null

				break 2
			fi

			# wait here until a download slot becomes available
			while [ "$parallel_count" -eq "$parallel_limit" ] ; do
				sleep 0.5

				RefreshDownloadCounts
			done

			# have enough images now so exit loop
			[ "$success_count" -eq "$images_required" ] &&	break 2

			if [ "$(($success_count+$parallel_count))" -lt "$images_required" ] ; then
				((result_index++))
				local link_index=$(printf "%04d" $result_index)

				# create run file here as it takes too long to happen in background function
				touch "$download_run_count_path/$link_index"
				{ DownloadImage_auto "$imagelink" "$link_index" & } 2>/dev/null

				break
			fi
		done
	done < "${imagelinks_pathfile}"

	wait 2>/dev/null

	RefreshDownloadCounts
	ShowImageDownloadProgress

	if [ "$fail_count" -gt "0" ] ; then
		# derived from: http://stackoverflow.com/questions/24284460/calculating-rounded-percentage-in-shell-script-without-using-bc
		percent="$((200*($fail_count)/($success_count+$fail_count) % 2 + 100*($fail_count)/($success_count+$fail_count)))%"

		if [ "$colour" == "true" ] ; then
			echo -n "($(ColourTextBrightRed "$percent")) "
		else
			echo -n "($percent) "
		fi
	fi

	if [ "$result" -eq "1" ] ; then
		if [ "$colour" == "true" ] ; then
			echo "$(ColourTextBrightRed "Too many failures!")"
		else
			echo "Too many failures!"
		fi
	else
		if [ "$result_index" -eq "$result_count" ] ; then
			DebugThis "! ran out of images to download!" "$result_index/$result_count"

			if [ "$colour" == "true" ] ; then
				echo "$(ColourTextBrightRed "Ran out of images to download!")"
			else
				echo "Ran out of images to download!"
			fi

			result=1
		else
			[ "$verbose" == "true" ] && echo
		fi
	fi

	if [ ! "$result" -eq "1" ] ; then
		download_bytes="$(du "${target_path}/${image_file}"* -cb | tail -n1 | cut -f1)"
		DebugThis "= downloaded bytes" "$(DisplayThousands "$download_bytes")"

		download_seconds="$(($(date +%s )-$func_startseconds))"
		DebugThis "= download seconds" "$(DisplayThousands "$download_seconds")"

		avg_download_speed="$(DisplayISO "$(($download_bytes/$download_seconds))")"
		DebugThis "= average download speed" "${avg_download_speed}B/s"
	fi

	DebugThis "? \$success_count" "$success_count"
	DebugThis "? \$fail_count" "$fail_count"
	DebugThis "T [${FUNCNAME[0]}] elapsed time" "$(ConvertSecs "$(($(date +%s )-$func_startseconds))")"
	DebugThis "/ [${FUNCNAME[0]}]" "exit"

	return $result

	}

function BuildGallery
	{

	local title_colour="goldenrod1"
	local thumbnail_dimensions="400x400"

	DebugThis "\ [${FUNCNAME[0]}]" "entry"

	local func_startseconds=$(date +%s)

	InitProgress

	if [ "$verbose" == "true" ] ; then
		echo -n " -> building gallery: "

		if [ "$colour" == "true" ] ; then
			progress_message="$(ColourTextBrightOrange "stage 1/4")"
		else
			progress_message="stage 1/4"
		fi

		progress_message+=" (construct thumbnails)"

		ProgressUpdater "${progress_message}"
	fi

	# build gallery
	build_foreground_cmd="montage \"${target_path}/*[0]\" -background none -shadow -geometry $thumbnail_dimensions miff:- | convert - -background none -gravity north -splice 0x140 -bordercolor none -border 30 \"${gallery_thumbnails_pathfile}\""

	DebugThis "? \$build_foreground_cmd" "$build_foreground_cmd"

	eval $build_foreground_cmd 2> /dev/null
	result=$?

	if [ "$result" -eq "0" ] ; then
		DebugThis "$ \$build_foreground_cmd" "success!"
	else
		DebugThis "! \$build_foreground_cmd" "failed! montage returned: ($result)"
	fi

	if [ "$result" -eq "0" ] ; then
		if [ "$verbose" == "true" ] ; then
			if [ "$colour" == "true" ] ; then
				progress_message="$(ColourTextBrightOrange "stage 2/4")"
			else
				progress_message="stage 2/4"
			fi

			progress_message+=" (draw background pattern)"

			ProgressUpdater "${progress_message}"
		fi

		# get image dimensions
		read -r width height <<< $(convert -ping "${gallery_thumbnails_pathfile}" -format "%w %h" info:)

		# create a dark image with light sphere in centre
		build_background_cmd="convert -size ${width}x${height} radial-gradient:WhiteSmoke-gray10 \"${gallery_background_pathfile}\""

		DebugThis "? \$build_background_cmd" "$build_background_cmd"

		eval $build_background_cmd 2> /dev/null
		result=$?

		if [ "$result" -eq "0" ] ; then
			DebugThis "$ \$build_background_cmd" "success!"
		else
			DebugThis "! \$build_background_cmd" "failed! convert returned: ($result)"
		fi
	fi

	if [ "$result" -eq "0" ] ; then
		if [ "$verbose" == "true" ] ; then
			if [ "$colour" == "true" ] ; then
				progress_message="$(ColourTextBrightOrange "stage 3/4")"
			else
				progress_message="stage 3/4"
			fi

			progress_message+=" (draw title text image)"

			ProgressUpdater "${progress_message}"
		fi

		# create title image
		# let's try a fixed height of 100 pixels
		build_title_cmd="convert -size x100 -font $(FirstPreferredFont) -background none -stroke black -strokewidth 10 label:\"${gallery_title}\" -blur 0x5 -fill $title_colour -stroke none label:\"${gallery_title}\" -flatten \"${gallery_title_pathfile}\""

		DebugThis "? \$build_title_cmd" "$build_title_cmd"

		eval $build_title_cmd 2> /dev/null
		result=$?

		if [ "$result" -eq "0" ] ; then
			DebugThis "$ \$build_title_cmd" "success!"
		else
			DebugThis "! \$build_title_cmd" "failed! convert returned: ($result)"
		fi
	fi

	if [ "$result" -eq "0" ] ; then
		if [ "$verbose" == "true" ] ; then
			if [ "$colour" == "true" ] ; then
				progress_message="$(ColourTextBrightOrange "stage 4/4")"
			else
				progress_message="stage 4/4"
			fi

			progress_message+=" (compile all images)"

			ProgressUpdater "${progress_message}"
		fi

		# compose thumbnails image on background image, then title image on top
		build_compose_cmd="convert \"${gallery_background_pathfile}\" \"${gallery_thumbnails_pathfile}\" -gravity center -composite \"${gallery_title_pathfile}\" -gravity north -geometry +0+25 -composite \"${target_path}/${gallery_name}-($safe_query).png\""

		DebugThis "? \$build_compose_cmd" "$build_compose_cmd"

		eval $build_compose_cmd 2> /dev/null
		result=$?

		if [ "$result" -eq "0" ] ; then
			DebugThis "$ \$build_compose_cmd" "success!"
		else
			DebugThis "! \$build_compose_cmd" "failed! convert returned: ($result)"
		fi
	fi

	[ -e "${gallery_title_pathfile}" ] && rm -f "${gallery_title_pathfile}"
	[ -e "${gallery_thumbnails_pathfile}" ] && rm -f "${gallery_thumbnails_pathfile}"
	[ -e "${gallery_background_pathfile}" ] && rm -f "${gallery_background_pathfile}"

	if [ "$result" -eq "0" ] ; then
		DebugThis "$ [${FUNCNAME[0]}]" "success!"
		if [ "$verbose" == "true" ] ; then
			if [ "$colour" == "true" ] ; then
				ProgressUpdater "$(ColourTextBrightGreen "done!")"
			else
				ProgressUpdater "done!"
			fi
		fi
	else
		DebugThis "! [${FUNCNAME[0]}]" "failed! See previous!"

		if [ "$colour" == "true" ] ; then
			ProgressUpdater "$(ColourTextBrightRed "failed!")"
		else
			ProgressUpdater "failed!"
		fi
	fi

	[ "$verbose" == "true" ] && echo

	DebugThis "T [${FUNCNAME[0]}] elapsed time" "$(ConvertSecs "$(($(date +%s)-$func_startseconds))")"
	DebugThis "/ [${FUNCNAME[0]}]" "exit"

	return $result

	}

function ParseResults
	{

	DebugThis "\ [${FUNCNAME[0]}]" "entry"

	result_count=0

	PageScraper

	if [ -e "$imagelinks_pathfile" ] ; then
		# check against allowable file types
		while read imagelink ; do
			AllowableFileType "$imagelink"
			[ "$?" -eq "0" ] && echo "$imagelink" >> "$imagelinks_pathfile".tmp
		done < "${imagelinks_pathfile}"

		[ -e "$imagelinks_pathfile".tmp ] && mv "$imagelinks_pathfile".tmp "$imagelinks_pathfile"

		# get link count
		result_count=$(wc -l < "${imagelinks_pathfile}")

		# if too many results then trim
		if [ "$result_count" -gt "$max_results_required" ] ; then
			DebugThis "! received more results than required" "$result_count/$max_results_required"

			head --lines "$max_results_required" --quiet "$imagelinks_pathfile" > "$imagelinks_pathfile".tmp
			mv "$imagelinks_pathfile".tmp "$imagelinks_pathfile"
			result_count=$max_results_required

			DebugThis "~ trimmed results back to \$max_results_required" "$max_results_required"
		fi
	fi

	if [ "$verbose" == "true" ] ; then
		if [ "$result_count" -gt "0" ] ; then
			if [ "$colour" == "true" ] ; then
				if [ "$result_count" -ge "$(($max_results_required))" ] ; then
					echo "$(ColourTextBrightGreen "${result_count}") results!"
				fi

				if [ "$result_count" -ge "$images_required" ] && [ "$result_count" -lt "$(($max_results_required))" ] ; then
					echo "$(ColourTextBrightOrange "${result_count}") results!"
				fi

				if [ "$result_count" -lt "$images_required" ] ; then
					echo "$(ColourTextBrightRed "${result_count}") results!"
				fi
			else
				echo "${result_count} results!"
			fi
		else
			if [ "$colour" == "true" ] ; then
				echo "$(ColourTextBrightRed "No results!")"
			else
				echo "No results!"
			fi
		fi
	fi

	DebugThis "? \$result_count" "$result_count"
	DebugThis "/ [${FUNCNAME[0]}]" "exit"

	}

function InitProgress
	{

	# needs to be called prior to first call of ProgressUpdater

	progress_message=""
	previous_length=0
	previous_msg=""

	}

function ProgressUpdater
	{

	# $1 = message to display

	if [ "$1" != "$previous_msg" ] ; then
		temp=$(RemoveColourCodes "$1")
		current_length=$((${#temp}+1))

		if [ "$current_length" -lt "$previous_length" ] ; then
			appended_length=$(($current_length-$previous_length))
			# backspace to start of previous msg, print new msg, add additional spaces, then backspace to end of msg
			printf "%${previous_length}s" | tr ' ' '\b' ; echo -n "$1 " ; printf "%${appended_length}s" ; printf "%${appended_length}s" | tr ' ' '\b'
		else
			# backspace to start of previous msg, print new msg
			printf "%${previous_length}s" | tr ' ' '\b' ; echo -n "$1 "
		fi

		previous_length=$current_length
		previous_msg="$1"
	fi

	}

function IsReqProgAvail
	{

	# $1 = name of program to search for with 'which'
	# $? = 0 if 'which' found it, 1 if not

	which "$1" > /dev/null 2>&1

	local result=$?

	if [ "$result" -eq "0" ] ; then
		DebugThis "$ required program is available" "$1"
	else
		echo " !! required program [$1] is unavailable ... unable to continue."
		echo
		DebugThis "! required program is unavailable" "$1"
		DisplayHelp
	fi

	return $result

	}

function IsOptProgAvail
	{

	# $1 = name of program to search for with 'which'
	# $? = 0 if 'which' found it, 1 if not

	which "$1" > /dev/null 2>&1

	local result=$?

	if [ "$result" -eq "0" ] ; then
		DebugThis "$ optional program is available" "$1"
	else
		DebugThis "! optional program is unavailable" "$1"
	fi

	return $result

	}

function ShowGoogle
	{

	echo -n "$(ColourTextBrightBlue "G")$(ColourTextBrightRed "o")$(ColourTextBrightOrange "o")$(ColourTextBrightBlue "g")$(ColourTextBrightGreen "l")$(ColourTextBrightRed "e")"

	}

function HelpParameterFormat
	{

	# $1 = short parameter
	# $2 = long parameter
	# $3 = description

	printf "  -%-1s   --%-28s %s\n" "$1" "$2" "$3"

	}

function RenameExtAsType
	{

	# checks output of 'identify -format "%m"' and ensures provided file extension matches
	# $1 = image filename. Is it actually a valid image?
	# $? = 0 if it IS an image, 1 if not an image

	local returncode=0

	if [ "$ident" == "true" ] ; then
		[ -z "$1" ] && returncode=1
		[ ! -e "$1" ] && returncode=1

		if [ "$returncode" -eq "0" ] ; then
			rawtype=$(identify -format "%m" "$1")
			returncode=$?
		fi

		if [ "$returncode" -eq "0" ] ; then
			# only want first 4 chars
			imagetype="${rawtype:0:4}"

			# have to add exception here to handle identify's output for animated gifs i.e. "GIFGIFGIFGIFGIF"
			[ "$imagetype" == "GIFG" ] && imagetype="GIF"

			case "$imagetype" in
				PNG | JPEG | GIF )
					# move file into temp file
					mv "$1" "$1".tmp

					# then back but with new extension created from $imagetype
					mv "$1".tmp "${1%.*}.$(Lowercase "$imagetype")"
					;;
				* )
					# not a valid image
					returncode=1
					;;
			esac
		fi
	fi

	return $returncode

	}

function AllowableFileType
	{

	# only these image types are considered acceptable
	# $1 = string to check
	# $? = 0 if OK, 1 if not

	local lcase=$(Lowercase "$1")
	local ext=$(echo ${lcase:(-5)} | sed "s/.*\(\.[^\.]*\)$/\1/")

	# if string does not have a '.' then assume no extension present
	[[ ! "$ext" =~ "." ]] && ext=""

	case "$ext" in
		.png | .jpg | .jpeg | .gif | .php )
			# valid image type
			return 0
			;;
		* )
			# not a valid image
			return 1
			;;
	esac

	}

function PageScraper
	{

	#------------- when Google change their web-code again, these regexes will need to be changed too --------------
	#
	# sed   1. add 2 x newline chars before each occurence of '<div',
	#
	# grep  2. only list lines with '<div class="rg_meta">' and eventually followed by 'http',
	#
	# sed   3. remove lines with 'YouTube' (case insensitive),
	#       4. remove lines with 'Vimeo' (case insensitive),
	#       5. add newline char before first occurence of 'http',
	#       6. remove from '<div' to newline,
	#       7. remove from '","ow"' to end of line,
	#       8. remove from '?' to end of line.
	#
	#---------------------------------------------------------------------------------------------------------------

	cat "${results_pathfile}" \
	| sed 's|<div|\n\n&|g' \
	| grep '<div class=\"rg_meta\">.*http' \
	| sed '/youtube/Id;/vimeo/Id;s|http|\n&|;s|<div.*\n||;s|","ow".*||;s|\?.*||' \
	> "${imagelinks_pathfile}"

	}

function CTRL_C_Captured
	{

	DebugThis "! [SIGINT]" "detected"

	echo

	if [ "$colour" == "true" ] ; then
		echo " -> $(ColourTextBrightRed "[SIGINT]") - let's cleanup now ..."
	else
		echo " -> [SIGINT] - let's cleanup now ..."
	fi

	# http://stackoverflow.com/questions/81520/how-to-suppress-terminated-message-after-killing-in-bash
	kill $(jobs -p) 2>/dev/null
	wait $(jobs -p) 2>/dev/null

	# only want to remove partial downloads if they exist
	RefreshDownloadCounts

	if [ "$parallel_count" -gt "0" ] ; then
		# remove any image files where processing by [DownloadImage_auto] was incomplete
		for currentfile in `ls -I . -I .. $download_run_count_path` ; do
			DebugThis "= link ($currentfile) was partially processed" "deleted!"

 			rm -f "${target_path}/${image_file}($currentfile)".*
		done
	fi

	DebugThis "< finished" "$(date)"

	echo
	echo " -> And ... we're done."

	exit

	}

function DebugThis
	{

	# $1 = item
	# $2 = value

	echo "$1: '$2'" >> "${debug_pathfile}"

	}

function WgetReturnCodes
	{

	# converts a return code from wget into a text string explanation of the code
	# https://gist.github.com/cosimo/5747881#file-wget-exit-codes-txt

	# $1 = wget return code
	# echo = text string

	case "$1" in
		0 )
			echo "No problems occurred"
			;;
		2 )
			echo "Parse error — for instance, when parsing command-line options, the .wgetrc or .netrc…"
			;;
		3 )
			echo "File I/O error"
			;;
		4 )
			echo "Network failure"
			;;
		5 )
			echo "SSL verification failure"
			;;
		6 )
			echo "Username/password authentication failure"
			;;
		7 )
			echo "Protocol errors"
			;;
		8 )
			echo "Server issued an error response"
			;;
		* )
			echo "Generic error code"
			;;
	esac

	}

function ConvertSecs
	{

	# http://stackoverflow.com/questions/12199631/convert-seconds-to-hours-minutes-seconds
	# $1 = a time in seconds to convert to 'hh:mm:ss'

	((h=${1}/3600))
	((m=(${1}%3600)/60))
	((s=${1}%60))

	printf "%02dh:%02dm:%02ds\n" $h $m $s

	}

function ColourTextBrightWhite
	{

	echo -en '\E[1;97m'"$(PrintResetColours "$1")"

	}

function ColourTextBrightGreen
	{

	echo -en '\E[1;32m'"$(PrintResetColours "$1")"

	}

function ColourTextBrightOrange
	{

	echo -en '\E[1;38;5;214m'"$(PrintResetColours "$1")"

	}

function ColourTextBrightRed
	{

	echo -en '\E[1;31m'"$(PrintResetColours "$1")"

	}

function ColourTextBrightBlue
	{

	echo -en '\E[1;94m'"$(PrintResetColours "$1")"

	}

function PrintResetColours
	{

	echo -en "$1"'\E[0m'

	}

function RemoveColourCodes
	{

	# http://www.commandlinefu.com/commands/view/3584/remove-color-codes-special-characters-with-sed
	echo -n "$1" | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g"

	}

function ShowAsFailed
	{

	# $1 = message to show in colour if colour is set

	if [ "$colour" == "true" ] ; then
		echo -n "$(ColourTextBrightRed "$1")"
	else
		echo -n "$1"
	fi

	}

function ShowAsSucceed
	{

	# $1 = message to show in colour if colour is set

	if [ "$colour" == "true" ] ; then
		echo -n "$(ColourTextBrightGreen "$1")"
	else
		echo -n "$1"
	fi

	}

function Uppercase
	{

	# $1 = some text to convert to uppercase

	echo "$1" | tr "[a-z]" "[A-Z]"

	}

function Lowercase
	{

	# $1 = some text to convert to lowercase

	echo "$1" | tr "[A-Z]" "[a-z]"

	}

function DisplayISO
	{

	# show $1 formatted with 'k', 'M', 'G'

	echo $1 | awk 'BEGIN{ u[0]=""; u[1]=" k"; u[2]=" M"; u[3]=" G"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } '

	}

function DisplayThousands
	{

	# show $1 formatted with thousands separator

	printf "%'.f\n" "$1"

	}

function WantedFonts
	{

	local font_list=""

	font_list+="Century-Schoolbook-L-Bold-Italic\n"
	font_list+="Droid-Serif-Bold-Italic\n"
	font_list+="FreeSerif-Bold-Italic\n"
	font_list+="Nimbus-Roman-No9-L-Medium-Italic\n"
	font_list+="Times-BoldItalic\n"
	font_list+="URW-Palladio-L-Bold-Italic\n"
	font_list+="Utopia-Bold-Italic\n"
	font_list+="Bitstream-Charter-Bold-Italic\n"

	echo -e "$font_list"

	}

function FirstPreferredFont
	{

	local preferred_fonts=$(WantedFonts)
	local available_fonts=$(convert -list font | grep "Font:" | sed 's| Font: ||')
	local first_available_font=""

	while read preferred_font ; do
		while read available_font ; do
			[ "$preferred_font" == "$available_font" ] && break 2
		done <<< "$available_fonts"
	done <<< "$preferred_fonts"

	if [ ! -z "$preferred_font" ] ; then
		echo "$preferred_font"
	else
		# uncomment 2nd line down to return first installed font if no preferred fonts could be found.
		# for 'convert -font' this isn't needed as it will use a default font if specified font is "".

		#read first_available_font others <<< $available_fonts

		echo "$first_available_font"
	fi

	}

# check for command-line parameters
user_parameters=$(getopt -o h,g,d,e,s,q,v,c,k,i:,l:,u:,r:,t:,a:,f:,n:,p: --long help,no-gallery,debug,delete-after,save-links,quiet,version,colour,skip-no-size,title:,lower-size:,upper-size:,retries:,timeout:,parallel:,failures:,number:,phrase: -n $(readlink -f -- "$0") -- "$@")
user_parameters_result=$?
user_parameters_raw="$@"

Init

# user parameter validation and bounds checks
if [ "$exitcode" -eq "0" ] ; then
	case ${images_required#[-+]} in
		*[!0-9]* )
			DebugThis "! specified \$images_required" "invalid"
			DisplayHelp
			echo
			echo "$(ShowAsFailed " !! number specified after (-n --number) must be a valid integer ... unable to continue.")"
			exitcode=2
			;;
		* )
			if [ "$images_required" -lt "1" ] ; then
				images_required=1
				DebugThis "~ \$images_required too low so set sensible minimum" "$images_required"
			fi

			if [ "$images_required" -gt "$google_max" ] ; then
				images_required=$google_max
				DebugThis "~ \$images_required too high so set as \$google_max" "$images_required"
			fi
			;;
	esac

	if [ "$exitcode" -eq "0" ] ; then
		case ${fail_limit#[-+]} in
			*[!0-9]* )
				DebugThis "! specified \$fail_limit" "invalid"
				DisplayHelp
				echo
				echo "$(ShowAsFailed " !! number specified after (-f --failures) must be a valid integer ... unable to continue.")"
				exitcode=2
				;;
			* )
				if [ "$fail_limit" -le "0" ] ; then
					fail_limit=$google_max
					DebugThis "~ \$fail_limit too low so set as \$google_max" "$fail_limit"
				fi

				if [ "$fail_limit" -gt "$google_max" ] ; then
					fail_limit=$google_max
					DebugThis "~ \$fail_limit too high so set as \$google_max" "$fail_limit"
				fi
				;;
		esac
	fi

	if [ "$exitcode" -eq "0" ] ; then
		case ${parallel_limit#[-+]} in
			*[!0-9]* )
				DebugThis "! specified \$parallel_limit" "invalid"
				DisplayHelp
				echo
				echo "$(ShowAsFailed " !! number specified after (-a --parallel) must be a valid integer ... unable to continue.")"
				exitcode=2
				;;
			* )
				if [ "$parallel_limit" -lt "1" ] ; then
					parallel_limit=1
					DebugThis "~ \$parallel_limit too low so set as" "$parallel_limit"
				fi

				if [ "$parallel_limit" -gt "$parallel_max" ] ; then
					parallel_limit=$parallel_max
					DebugThis "~ \$parallel_limit too high so set as" "$parallel_limit"
				fi
				;;
		esac
	fi

	if [ "$exitcode" -eq "0" ] ; then
		case ${timeout#[-+]} in
			*[!0-9]* )
				DebugThis "! specified \$timeout" "invalid"
				DisplayHelp
				echo
				echo "$(ShowAsFailed " !! number specified after (-t --timeout) must be a valid integer ... unable to continue.")"
				exitcode=2
				;;
			* )
				if [ "$timeout" -lt "1" ] ; then
					timeout=1
					DebugThis "~ \$timeout too low so set as" "$timeout"
				fi

				if [ "$timeout" -gt "$timeout_max" ] ; then
					timeout=$timeout_max
					DebugThis "~ \$timeout too high so set as" "$timeout"
				fi
				;;
		esac
	fi

	if [ "$exitcode" -eq "0" ] ; then
		case ${retries#[-+]} in
			*[!0-9]* )
				DebugThis "! specified \$retries" "invalid"
				DisplayHelp
				echo
				echo "$(ShowAsFailed " !! number specified after (-r --retries) must be a valid integer ... unable to continue.")"
				exitcode=2
				;;
			* )
				if [ "$retries" -lt "1" ] ; then
					retries=1
					DebugThis "~ \$retries too low so set as" "$retries"
				fi

				if [ "$retries" -gt "$retries_max" ] ; then
					retries=$retries_max
					DebugThis "~ \$retries too high so set as" "$retries"
				fi
				;;
		esac
	fi

	if [ "$exitcode" -eq "0" ] ; then
		case ${upper_size_limit#[-+]} in
			*[!0-9]* )
				DebugThis "! specified \$upper_size_limit" "invalid"
				DisplayHelp
				echo
				echo "$(ShowAsFailed " !! number specified after (-u --upper-size) must be a valid integer ... unable to continue.")"
				exitcode=2
				;;
			* )
				if [ "$upper_size_limit" -lt "0" ] ; then
					upper_size_limit=0
					DebugThis "~ \$upper_size_limit too small so set as" "$upper_size_limit (unlimited)"
				fi
				;;
		esac
	fi

	if [ "$exitcode" -eq "0" ] ; then
		case ${lower_size_limit#[-+]} in
			*[!0-9]* )
				DebugThis "! specified \$lower_size_limit" "invalid"
				DisplayHelp
				echo
				echo "$(ShowAsFailed " !! number specified after (-l --lower-size) must be a valid integer ... unable to continue.")"
				exitcode=2
				;;
			* )
				if [ "$lower_size_limit" -lt "0" ] ; then
					lower_size_limit=0
					DebugThis "~ \$lower_size_limit too small so set as" "$lower_size_limit"
				fi

				if [ "$upper_size_limit" -gt "0" ] && [ "$lower_size_limit" -gt "$upper_size_limit" ] ; then
					lower_size_limit=$(($upper_size_limit-1))
					DebugThis "~ \$lower_size_limit larger than \$upper_size_limit ($upper_size_limit) so set as" "$lower_size_limit"
				fi
				;;
		esac
	fi

	if [ "$exitcode" -eq "0" ] ; then
		if [ ! "$user_query" ] ; then
			DebugThis "! \$user_query" "unspecified"
			DisplayHelp
			echo
			echo "$(ShowAsFailed " !! search phrase (-p --phrase) was unspecified ... unable to continue.")"
			exitcode=2
		else
			safe_query="$(echo $user_query | tr ' ' '_')"	# replace whitepace with '_' so less issues later on!
			DebugThis "? \$safe_query" "$safe_query"
			target_path="${current_path}/${safe_query}"
			DebugThis "? \$target_path" "$target_path"
			targetimage_pathfile="${target_path}/${image_file}"
		fi
	fi

	if [ "$exitcode" -eq "0" ] ; then
		if [ ! "$gallery_title" ] ; then
			gallery_title=$user_query
			DebugThis "~ \$gallery_title was unspecified so set as" "$gallery_title"
		fi
	fi
fi

# create directory for search phrase
if [ "$exitcode" -eq "0" ] ; then
	if [ -e "${target_path}" ] ; then
		DebugThis "! create sub-directory [${target_path}]" "failed! Sub-directory already exists!"
		echo "$(ShowAsFailed " !! sub-directory [${target_path}] already exists ... unable to continue.")"
		exitcode=3
	fi

	if [ "$exitcode" -eq "0" ] ; then
		mkdir -p "${target_path}"
		result=$?

		if [ "$result" -gt "0" ] ; then
			DebugThis "! create sub-directory [${target_path}]" "failed! mkdir returned: ($result)"
			echo "$(ShowAsFailed " !! couldn't create sub-directory [${target_path}] ... unable to continue.")"
			exitcode=3
		else
			DebugThis "$ create sub-directory [${target_path}]" "success!"
			target_path_created=true
		fi
	fi
fi

# get list of search results
if [ "$exitcode" -eq "0" ] ; then
	if [ "$max_results_required" -lt "$(($images_required+$fail_limit))" ] ; then
		max_results_required=$(($images_required+$fail_limit))
		DebugThis "~ \$max_results_required too low so set as \$images_required + \$fail_limit" "$max_results_required"
	fi

	DownloadResultGroups

	if [ "$?" -gt "0" ] ; then
		echo "$(ShowAsFailed " !! couldn't download Google search results ... unable to continue.")"
		exitcode=4
	else
		if [ "$fail_limit" -gt "$result_count" ] ; then
			fail_limit=$result_count
			DebugThis "~ \$fail_limit too high so set as \$result_count" "$fail_limit"
		fi

		if [ "$images_required" -gt "$result_count" ] ; then
			images_required=$result_count
			DebugThis "~ \$images_required too high so set as \$result_count" "$result_count"
		fi
	fi

	if [ "$result_count" -eq "0" ] ; then
		DebugThis "= zero results returned? Wow..." "can't continue"
		exitcode=4
	fi
fi

# download images
if [ "$exitcode" -eq "0" ] ; then
	DownloadImages

	[ "$?" -gt "0" ] && exitcode=5
fi

# build thumbnail gallery even if fail_limit was reached
if [ "$exitcode" -eq "0" ] || [ "$exitcode" -eq "5" ] ; then
	if [ "$create_gallery" == "true" ] ; then
		BuildGallery

		if [ "$?" -gt "0" ] ; then
			echo "$(ShowAsFailed " !! couldn't build thumbnail gallery ... unable to continue (but we're all done anyway).")"
			exitcode=6
		else
			if [ "$remove_after" == "true" ] ; then
				rm -f "${target_path}/${image_file}"*
				DebugThis "= remove all downloaded images from" "[${target_path}]"
			fi
		fi
	fi
fi

# copy links file into target directory if possible. If not, then copy to current directory.
if [ "$exitcode" -eq "0" ] ; then
	if [ "$links" == "true" ] ; then
		if [ "$target_path_created" == "true" ] ; then
			cp -f "${imagelinks_pathfile}" "${target_path}/${imagelinks_file}"
		else
			cp -f "${imagelinks_pathfile}" "${current_path}/${imagelinks_file}"
		fi
	fi
fi

# write results into debug file
DebugThis "T [$script_file] elapsed time" "$(ConvertSecs "$(($(date +%s)-$script_startseconds))")"
DebugThis "< finished" "$(date)"

# copy debug file into target directory if possible. If not, then copy to current directory.
if [ "$debug" == "true" ] ; then
	if [ "$target_path_created" == "true" ] ; then
		[ -e "${target_path}/${debug_file}" ] && echo "" >> "${target_path}/${debug_file}"

		cp -f "${debug_pathfile}" "${target_path}/${debug_file}"
	else
		# append to current path debug file (if it exists)
		[ -e "${current_path}/${debug_file}" ] && echo "" >> "${current_path}/${debug_file}"

		cat "${debug_pathfile}" >> "${current_path}/${debug_file}"
	fi
fi

# display end
if [ "$verbose" == "true" ] ; then
	case "$exitcode" in
		0 )
			echo
			echo " -> $(ShowAsSucceed "All done!")"
			;;
		[1-6] )
			echo
			echo " -> $(ShowAsFailed "All done! (with errors)")"
			;;
		* )
			;;
	esac
fi

# reset exitcode if only displaying info
if [ "$show_version_only" == "true" ] || [ "$show_help_only" == "true" ] ; then
	exitcode=0
fi

exit $exitcode
