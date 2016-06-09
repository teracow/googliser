#/bin/bash

# Copyright (C) 2016 Teracow Software

# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

# If you find this code useful, please let me know. :) teracow@gmail.com

# The latest copy can be found here [https://github.com/teracow/googliser]

# return values ($?):
#	0	completed successfully
#	1	required program unavailable (wget, perl, montage)
#	2	required parameter unspecified or wrong - help shown or version requested
#	3	could not create subdirectory for 'search phrase'
#	4	could not get a list of search results from Google
#	5	image download aborted as failure limit was reached
#	6	thumbnail gallery build failed

# debug log first character notation:
#	>	script entry
#	<	script exit
#	\	function entry
#	/	function exit
#	?	variable value
#	~	variable had boundary issues so was set within bounds
#	$	success
#	!	failure
#	T	elapsed time

function Init
	{

	script_version="1.15"
	script_date="2016-06-09"
	script_name="$(basename -- "$(readlink -f -- "$0")")"
	script_details="${script_name} - v${script_version} (${script_date})"

	current_path="$PWD"
	temp_path="/dev/shm"

	gallery_name="googliser-gallery"
	imagelinkslist_file="googliser-links.list"
	debug_file="googliser-debug.log"
	image_file="google-image"

	spawn_count_pathfile="${temp_path}/spawned-process.count"
	success_count_pathfile="${temp_path}/successful-download.count"
	failure_count_pathfile="${temp_path}/failed-download.count"
	unknown_size_count_pathfile="${temp_path}/unknown-size-download.count"
	results_pathfile="${temp_path}/google-results.html"
	gallery_title_pathfile="${temp_path}/gallery-title.png"
	gallery_thumbnails_pathfile="${temp_path}/gallery-thumbnails.png"
	gallery_background_pathfile="${temp_path}/gallery-background.png"

	server="www.google.com.au"
	results_max=400
	spawn_max=40
	timeout_max=600
	retries_max=100

	# user parameters
	user_query=""
	images_required=25
	spawn_limit=8
	failures_limit=10
	upper_size_limit=0
	lower_size_limit=1000
	timeout=15
	retries=3
	create_gallery=true
	verbose=true
	debug=false

	# http://whatsmyuseragent.com
	useragent='Mozilla/5.0 (X11; Linux x86_64; rv:46.0) Gecko/20100101 Firefox/46.0'

	script_starttime=$(date)
	script_startseconds=$(date +%s)
	result_index=0
	failure_count=0
	exitcode=0

	WhatAreMyOptions

	exitcode=$?

	[ "$debug" == "true" ] && [ -e "${debug_file}" ] && echo "" >> "${debug_file}"

	AddToDebug "> started" "$script_starttime"
	AddToDebug "? \$script_details" "$script_details"
	AddToDebug "? \$user_query" "$user_query"
	AddToDebug "? \$images_required" "$images_required"
	AddToDebug "? \$spawn_limit" "$spawn_limit"
	AddToDebug "? \$upper_size_limit" "$upper_size_limit"
	AddToDebug "? \$lower_size_limit" "$lower_size_limit"
	AddToDebug "? \$results_max" "$results_max"
	AddToDebug "? \$failures_limit" "$failures_limit"
	AddToDebug "? \$verbose" "$verbose"
	AddToDebug "? \$create_gallery" "$create_gallery"

	IsProgramAvailable "wget" || exitcode=1
	IsProgramAvailable "perl" || exitcode=1

	if [ "$create_gallery" == "true" ] ; then
		IsProgramAvailable "montage" || exitcode=1
		IsProgramAvailable "convert" || exitcode=1
	fi

	[ -e "${spawn_count_pathfile}" ] && rm -f "${spawn_count_pathfile}"
	[ -e "${success_count_pathfile}" ] && rm -f "${success_count_pathfile}"
	[ -e "${failure_count_pathfile}" ] && rm -f "${failure_count_pathfile}"
	[ -e "${unknown_size_count_pathfile}" ] && rm -f "${unknown_size_count_pathfile}"
	[ -e "${results_pathfile}" ] && rm -f "${results_pathfile}"*

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

	}

function ShowHelp
	{

	AddToDebug "\ [${FUNCNAME[0]}]" "entry"

	local sample_user_query="cows"

	echo " > ${script_details}"
	echo
	echo " - search 'Google Images', download each of the image URLs returned, then build a thumbnail gallery using ImageMagick."
	echo
	echo " - This is an expansion upon a solution provided by ShellFish on:"
	echo " [https://stackoverflow.com/questions/27909521/download-images-from-google-with-command-line]"
	echo
	echo " - Requirements: Wget and Perl"
	echo " - Optional: montage & convert (from ImageMagick)"
	echo
	echo " - Questions or comments? teracow@gmail.com"
	echo
	echo " - Usage: ./$script_name [PARAMETERS] ..."
	echo
	echo " Mandatory arguments to long options are mandatory for short options too. Defaults values are shown in []"
	HelpParameterFormat "n" "number INTEGER [$images_required]" "Number of images to download. Maximum of $results_max."
	HelpParameterFormat "p" "phrase STRING" "*required* Search phrase to look for. Enclose whitespace in quotes."
	HelpParameterFormat "f" "failures INTEGER [$failures_limit]" "How many download failures before exiting? 0 for unlimited ($results_max)."
	HelpParameterFormat "c" "concurrency INTEGER [$spawn_limit]" "How many concurrent image downloads? Maximum of $spawn_max. Use wisely!"
	HelpParameterFormat "t" "timeout INTEGER [$timeout]" "Number of seconds before retrying download. Maximum of $timeout_max."
	HelpParameterFormat "r" "retries INTEGER [$retries]" "Try to download each image this many times. Maximum of $retries_max."
	HelpParameterFormat "u" "upper-size INTEGER [$upper_size_limit]" "Only download images that are smaller than this size. 0 for unlimited size."
	HelpParameterFormat "l" "lower-size INTEGER [$lower_size_limit]" "Only download images that are larger than this size."
	HelpParameterFormat "g" "no-gallery" "Don't create thumbnail gallery."
	HelpParameterFormat "h" "help" "Display this help then exit."
	HelpParameterFormat "v" "version " "Show script version then exit."
	HelpParameterFormat "q" "quiet" "Suppress standard message output. Error messages are still shown."
	HelpParameterFormat "d" "debug" "Output debug info to file [$debug_file]."
	echo
	echo " - Example:"
	echo " $ ./$script_name -p \"${sample_user_query}\""
	echo
	echo " This will download the first $images_required available images for the search phrase \"${sample_user_query}\" and build them into a gallery."
	echo

	AddToDebug "/ [${FUNCNAME[0]}]" "exit"

	}

function HelpParameterFormat
	{

	# $1 = short parameter
	# $2 = long parameter
	# $3 = description

	printf "  -%-1s --%-25s %s\n" "$1" "$2" "$3"

	}

function WhatAreMyOptions
	{

	# if getopt exited with an error then show help to user
	[ "$user_parameters_result" != "0" ] && echo && ShowHelp && return 2

	eval set -- "$user_parameters"

	while true
	do
		case "$1" in
			-n | --number )
				images_required="$2"
				shift 2		# shift to next parameter in $1
				;;
			-f | --failures )
				failures_limit="$2"
				shift 2		# shift to next parameter in $1
				;;
			-p | --phrase )
				user_query="$2"
				shift 2		# shift to next parameter in $1
				;;
			-c | --concurrency )
				spawn_limit="$2"
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
			-h | --help )
				ShowHelp
				return 2
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
				echo "v${script_version} (${script_date})"
				return 2
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

function IsProgramAvailable
	{

	# $1 = name of program to search for with 'which'
	# $? = 0 if 'which' found it, 1 if not

	which "$1" > /dev/null 2>&1

	if [ "$?" -gt "0" ] ; then
		echo " !! required program [$1] is unavailable ... unable to continue."
		echo
		AddToDebug "! required program is unavailable" "$1"
		ShowHelp
		return 1
	else
		AddToDebug "$ required program is available" "$1"
		return 0
	fi

	}

function DownloadSpecificPageSegment
	{

	# $1 = page quarter to load:		(0, 1, 2, 3)
	# $2 = pointer starts at result:	(0, 100, 200, 300)

	local search_quarter="&ijn=$1"
	local search_start="&start=$2"
	local wget_list_cmd="wget --quiet 'https://${server}/search?${search_type}${search_match_type}${search_phrase}${search_language}${search_style}${search_quarter}${search_start}' --user-agent '$useragent' --output-document -"
	AddToDebug "? \$wget_list_cmd" "$wget_list_cmd"

	eval $wget_list_cmd >> "${results_pathfile}.$1"

	}

function DownloadAllPageSegments
	{

	local total=4
	local pointer=0
	local percent=""
	local pids=""

	for ((quarter=1; quarter<=$total; quarter++)) ; do
		pointer=$((($quarter-1)*100))

		# derived from: http://stackoverflow.com/questions/24284460/calculating-rounded-percentage-in-shell-script-without-using-bc
		percent="$((200*($quarter-1)/$total % 2 + 100*($quarter-1)/$total))% "

		DownloadSpecificPageSegment $(($quarter-1)) "$pointer" &
		pids[${quarter}]=$!
	done

	# wait for spawned children to exit
	for pid in ${pids[*]}; do
		wait $pid
	done

	cat "${results_pathfile}".* > "${results_pathfile}"
	rm -f "${results_pathfile}".*

	}

function DownloadList
	{

	AddToDebug "\ [${FUNCNAME[0]}]" "entry"

	local func_startseconds=$(date +%s)

	[ "$verbose" == "true" ] && echo -n " -> searching Google for images matching the phrase \"$user_query\": "

	DownloadAllPageSegments

	# regexes explained:
	# 1. look for lines with '<div' and insert 2 linefeeds before them
	# 2. only list lines with '<div class="rg_meta">' and eventually followed by 'http'
	# 3. only list lines without 'youtube' or 'vimeo'
	# 4. remove everything from '<div class="rg_meta">' up to 'http' but keep 'http' on each line
	# 5. remove everything including and after '","ow"' on each line
	# 6. remove everything including and after '?' on each line

	cat "${results_pathfile}" | sed 's|<div|\n\n<div|g' | grep '<div class=\"rg_meta\">.*http' | grep -ivE 'youtube|vimeo' | perl -pe 's|(<div class="rg_meta">)(.*?)(http)|\3|; s|","ow".*||; s|\?.*||' > "${imagelist_pathfile}"
	result=$?

	if [ "$result" -eq "0" ] ; then
		result_count=$(wc -l < "${imagelist_pathfile}")

		if [ "$debug" == "true" ] ; then
			AddToDebug "$ [${FUNCNAME[0]}]" "success!"
			AddToDebug "? \$result_count" "$result_count"
		fi

		[ "$verbose" == "true" ] && echo "found ${result_count} results!"
# 		[ -e "${results_pathfile}" ] && rm -f "${results_pathfile}"

	else
		AddToDebug "! [${FUNCNAME[0]}]" "failed! wget returned: ($result)"
		[ "$verbose" == "true" ] && echo "failed!"
	fi

	if [ "$debug" == "true" ] ; then
		AddToDebug "T [${FUNCNAME[0]}] elapsed time" "$(ConvertSecs "$(($(date +%s)-$func_startseconds))")"
		AddToDebug "/ [${FUNCNAME[0]}]" "exit"
	fi

	return $result

	}

function SingleImageDownloader
	{

	# This function runs as a background process
	# $1 = URL to download
	# $2 = current counter relative to main list

	local result=0
	local size_ok=true
	local get_download=true
	IncrementFile "${spawn_count_pathfile}"

	AddToDebug "- download link # '$2'" "start"

	# extract file extension by checking only last 5 characters of URL (to handle .jpeg as worst case)
	ext=$(echo ${1:(-5)} | sed "s/.*\(\.[^\.]*\)$/\1/")

	[[ "$ext" =~ "." ]] || ext=".jpg"	# if URL did not have a file extension then choose jpg as default

	targetimage_pathfileext="${targetimage_pathfile}($2)${ext}"

	# are file size limits going to be applied before download?
	if [ "$upper_size_limit" -gt "0" ] || [ "$lower_size_limit" -gt "0" ] ; then
		# try to get file size from server
		estimated_size="$(wget --max-redirect 0 --timeout=${timeout} --tries=${retries} --spider "${imagelink}" 2>&1 | grep -i "length" | cut -d' ' -f2)"
		# possible return values are: 'unspecified', '123456' (integers), '' (empty)

		if [ -z "$estimated_size" ] || [ "$estimated_size" == "unspecified" ] ; then
			estimated_size="unknown"
		fi

		AddToDebug "? \$estimated_size for link # '$2'" "$estimated_size bytes"

		if [ "$estimated_size" != "unknown" ] ; then
			if [ "$estimated_size" -lt "$lower_size_limit" ] ; then
				AddToDebug "! link # '$2' before download is too small!" "$estimated_size bytes < $lower_size_limit bytes"
				size_ok=false
				get_download=false
			fi

			if [ "$upper_size_limit" != "0" ] && [ "$estimated_size" -gt "$upper_size_limit" ] ; then
				AddToDebug "! link # '$2' before download is too large!" "$estimated_size bytes > $upper_size_limit bytes"
				size_ok=false
				get_download=false
			fi
		fi
	fi

	if [ "$get_download" == "true" ] ; then
		[ "$estimated_size" == "unknown" ] && IncrementFile "${unknown_size_count_pathfile}"

		local wget_download_cmd="wget --max-redirect 0 --timeout=${timeout} --tries=${retries} --quiet --output-document \"${targetimage_pathfileext}\" \"${imagelink}\""
		AddToDebug "? \$wget_download_cmd" "$wget_download_cmd"

		eval $wget_download_cmd > /dev/null 2>&1
		result=$?

		if [ "$result" -eq "0" ] ; then
			actual_size=$(wc -c < "$targetimage_pathfileext")

			if [ "$debug" == "true" ] ; then
				AddToDebug "? \$actual_size for link # '$2'" "$actual_size bytes"
				if [ "$estimated_size" == "$actual_size" ] ; then
					AddToDebug "? \$estimated_size for link # '$2' ($estimated_size bytes) was" "correct."
				else
					AddToDebug "? \$estimated_size for link # '$2' ($estimated_size bytes) was" "incorrect!"
				fi
			fi

			if [ "$actual_size" -lt "$lower_size_limit" ] ; then
				AddToDebug "! link # '$2' after download is too small!" "$actual_size bytes < $lower_size_limit bytes"
				rm -f "$targetimage_pathfileext"
				size_ok=false
			fi

			if [ "$upper_size_limit" -gt "0" ] && [ "$actual_size" -gt "$upper_size_limit" ] ; then
				AddToDebug "! link # '$2' after download is too large!" "$actual_size bytes > $upper_size_limit bytes"
				rm -f "$targetimage_pathfileext"
				size_ok=false
			fi

			if [ "$size_ok" == "true" ] ; then
				AddToDebug "$ download link # '$2'" "success!"
				IncrementFile "${success_count_pathfile}"
			else
				# files that were outside size limits still count as failures
				IncrementFile "${failure_count_pathfile}"
			fi
		else
			AddToDebug "! download link # '$2'" "failed! Wget returned: ($result - $(WgetReturnCodes "$result"))"
			IncrementFile "${failure_count_pathfile}"

			# delete temp file if one was created
			[ -e "${targetimage_pathfileext}" ] && rm -f "${targetimage_pathfileext}"
		fi

		[ "$estimated_size" == "unknown" ] && DecrementFile "${unknown_size_count_pathfile}"
	else
		IncrementFile "${failure_count_pathfile}"
	fi

	DecrementFile "${spawn_count_pathfile}"

	}

function DownloadImages
	{

	AddToDebug "\ [${FUNCNAME[0]}]" "entry"

	local func_startseconds=$(date +%s)
	local result_index=0
	local file_index=1
	local message=""
	local countdown=$images_required		# control how many files are downloaded. Counts down to zero.
	local strlength=0
	local pids=""
	local result=0
	failure_count=0

	ResetSpawnCount
	ResetUnknownSizesCount

	[ "$verbose" == "true" ] && echo -n " -> "

	while read imagelink; do
		while true; do
			RefreshActiveCounts
			ShowProgressMsg

			[ "$spawn_count" -lt "$spawn_limit" ] && break

			sleep 0.5
		done

		if [ "$countdown" -gt "0" ] ; then
			if [ "$failure_count" -ge "$failures_limit" ] ; then
 				result=1

 				# wait here while all running downloads finish
				for pid in ${pids[*]}; do
					wait $pid
				done

 				break
 			fi

			((result_index++))

			SingleImageDownloader "$msg" "$result_index" &
			pids[${result_index}]=$!		# record PID for checking later
			((countdown--))
			sleep 0.1				# allow spawned process time to update process accumulator file
		else
			# can't start any more concurrent downloads yet so kill some time
			# wait here while all running downloads finish
			for pid in ${pids[*]}; do
				wait $pid
			done

			ResetSpawnCount
			ResetUnknownSizesCount
			RefreshActiveCounts
			ShowProgressMsg

			# how many were successful?
			if [ "$success_count" -lt "$images_required" ] ; then
				# not enough yet, so go get some more
				# increase countdown again to get remaining files
				countdown=$(($images_required-$success_count))
			else
				break
			fi
		fi
	done < "${imagelist_pathfile}"

	# wait here while all running downloads finish
	for pid in ${pids[*]}; do
		wait $pid
	done

	ResetSpawnCount
	ResetUnknownSizesCount
	RefreshActiveCounts
	ShowProgressMsg

	[ "$verbose" == "true" ] && echo

	if [ "$debug" == "true" ] ; then
		AddToDebug "T [${FUNCNAME[0]}] elapsed time" "$(ConvertSecs "$(($(date +%s )-$func_startseconds))")"
		AddToDebug "/ [${FUNCNAME[0]}]" "exit"
	fi

	return $result

	}

function BuildGallery
	{

	local title_font="Century-Schoolbook-L-Bold-Italic"
	local title_colour="goldenrod1"
	local strlength=0

	AddToDebug "\ [${FUNCNAME[0]}]" "entry"

	local func_startseconds=$(date +%s)

	if [ "$verbose" == "true" ] ; then
		echo -n " -> building thumbnail gallery: "
		progress_message="step 1 - construct thumbnails "
		echo -n "$progress_message"
		strlength=${#progress_message}
	fi

	# build gallery
	build_foreground_cmd="montage \"${target_path}/*[0]\" -background none -shadow -geometry 400x400 miff:- | convert - -background none -gravity north -splice 0x140 -bordercolor none -border 30 \"${gallery_thumbnails_pathfile}\""

	AddToDebug "? \$build_foreground_cmd" "$build_foreground_cmd"

	eval $build_foreground_cmd 2> /dev/null
	result=$?

	# note! montage will always return 1 at the moment coz the '.list' file cannot be opened by it. Gallery image still builds correctly.
	# So the following line is a workaround until I figure out how to get montage to ignore this file. :)
	result=0

	if [ "$result" -eq "0" ] ; then
		AddToDebug "$ \$build_foreground_cmd" "success!"
	else
		AddToDebug "! \$build_foreground_cmd" "failed! montage returned: ($result)"
	fi

	if [ "$result" -eq "0" ] ; then
		if [ "$verbose" == "true" ] ; then
			# backspace to start of previous message - then overwrite with spaces - then backspace to start again!
			printf "%${strlength}s" | tr ' ' '\b' ; printf "%${strlength}s" ; printf "%${strlength}s" | tr ' ' '\b'

			progress_message="step 2 - draw background pattern "
			echo -n "$progress_message"
			strlength=${#progress_message}
		fi

		# get image dimensions
		read -r width height <<< $(convert -ping "${gallery_thumbnails_pathfile}" -format "%w %h" info:)

		# create a dark image with light sphere in centre
		build_background_cmd="convert -size ${width}x${height} radial-gradient:WhiteSmoke-gray10 \"${gallery_background_pathfile}\""

		AddToDebug "? \$build_background_cmd" "$build_background_cmd"

		eval $build_background_cmd 2> /dev/null
		result=$?

		if [ "$result" -eq "0" ] ; then
			AddToDebug "$ \$build_background_cmd" "success!"
		else
			AddToDebug "! \$build_background_cmd" "failed! convert returned: ($result)"
		fi
	fi

	if [ "$result" -eq "0" ] ; then
		if [ "$verbose" == "true" ] ; then
			# backspace to start of previous message - then overwrite with spaces - then backspace to start again!
			printf "%${strlength}s" | tr ' ' '\b' ; printf "%${strlength}s" ; printf "%${strlength}s" | tr ' ' '\b'

			progress_message="step 3 - draw title text image "
			echo -n "$progress_message"
			strlength=${#progress_message}
		fi

		# create title image
		# let's try a fixed height of 100 pixels
		build_title_cmd="convert -size x100 -font $title_font -background none -stroke black -strokewidth 10 label:\"${user_query}\" -blur 0x5 -fill $title_colour -stroke none label:\"${user_query}\" -flatten \"${gallery_title_pathfile}\""

		AddToDebug "? \$build_title_cmd" "$build_title_cmd"

		eval $build_title_cmd 2> /dev/null
		result=$?

		if [ "$result" -eq "0" ] ; then
			AddToDebug "$ \$build_title_cmd" "success!"
		else
			AddToDebug "! \$build_title_cmd" "failed! convert returned: ($result)"
		fi
	fi

	if [ "$result" -eq "0" ] ; then
		if [ "$verbose" == "true" ] ; then
			# backspace to start of previous message - then overwrite with spaces - then backspace to start again!
			printf "%${strlength}s" | tr ' ' '\b' ; printf "%${strlength}s" ; printf "%${strlength}s" | tr ' ' '\b'

			progress_message="step 4 - compile all images "
			echo -n "$progress_message"
			strlength=${#progress_message}
		fi

		# compose thumbnails image on background image, then title image on top
		build_compose_cmd="convert \"${gallery_background_pathfile}\" \"${gallery_thumbnails_pathfile}\" -gravity center -composite \"${gallery_title_pathfile}\" -gravity north -geometry +0+25 -composite \"${target_path}/${gallery_name}-($user_query).png\""

		AddToDebug "? \$build_compose_cmd" "$build_compose_cmd"

		eval $build_compose_cmd 2> /dev/null
		result=$?

		if [ "$result" -eq "0" ] ; then
			AddToDebug "$ \$build_compose_cmd" "success!"
		else
			AddToDebug "! \$build_compose_cmd" "failed! convert returned: ($result)"
		fi
	fi

	[ -e "${gallery_title_pathfile}" ] && rm -f "${gallery_title_pathfile}"
	[ -e "${gallery_thumbnails_pathfile}" ] && rm -f "${gallery_thumbnails_pathfile}"
	[ -e "${gallery_background_pathfile}" ] && rm -f "${gallery_background_pathfile}"

	if [ "$result" -eq "0" ] ; then
		AddToDebug "$ [${FUNCNAME[0]}]" "success!"
		if [ "$verbose" == "true" ] ; then
			# backspace to start of previous message - then overwrite with spaces - then backspace to start again!
			printf "%${strlength}s" | tr ' ' '\b' ; printf "%${strlength}s" ; printf "%${strlength}s" | tr ' ' '\b'
			echo "done!"
		fi
	else
		AddToDebug "! [${FUNCNAME[0]}]" "failed! See previous!"
		[ "$verbose" == "true" ] && echo "failed!"
	fi

	if [ "$debug" == "true" ] ; then
		AddToDebug "T [${FUNCNAME[0]}] elapsed time" "$( ConvertSecs "$(($( date +%s )-$func_startseconds))")"
		AddToDebug "/ [${FUNCNAME[0]}]" "exit"
	fi

	return $result

	}

function ResetSpawnCount
	{

	spawn_count=0

	echo "${spawn_count}" > "${spawn_count_pathfile}"

	}

function ResetUnknownSizesCount
	{

	unknown_size_count=0

	echo "${unknown_size_count}" > "${unknown_size_count_pathfile}"

	}

function IncrementFile
	{

	# $1 = pathfile containing an integer to increment

	local count=0

	if [ -z "$1" ] ; then
		return 1
	else
		[ -e "$1" ] && count=$(<"$1")
		((count++))
		echo "$count" > "$1"
	fi

	}

function DecrementFile
	{

	# $1 = pathfile containing an integer to decrement

	local count=0

	if [ -z "$1" ] ; then
		return 1
	else
		[ -e "$1" ] && count=$(<"$1")
		((count--))
		echo "$count" > "$1"
	fi

	}

function ShowProgressMsg
	{

	if [ "$verbose" == "true" ] ; then
		# backspace to start of previous message - then overwrite with spaces - then backspace to start again!
		printf "%${strlength}s" | tr ' ' '\b' ; printf "%${strlength}s" ; printf "%${strlength}s" | tr ' ' '\b'

		# number of image downloads that are OK
		progress_message="${success_count}/${images_required} images have downloaded"

		# include failures (if any)
		if [ "$failure_count" -gt "0" ] ; then
			progress_message+=" with ${failure_count}/${failures_limit} failures"
		fi

		# show the number of files currently downloading (if any)
		case "$spawn_count" in
			0 )
				progress_message+=""
				;;
			1 )
				progress_message+=", ${spawn_count}/${spawn_limit} download is in progress"
				;;
			* )
				progress_message+=", ${spawn_count}/${spawn_limit} downloads are in progress"
				;;
		esac

		# show the number of files currently downloading where the file size is unknown (if any)
		case "$unknown_size_count" in
			0 )
				progress_message+=""
				;;
			1 )
				progress_message+=" (but 1 is of unknown size)"
				;;
			* )
				progress_message+=" (but ${unknown_size_count} are of unknown size)"
				;;
		esac

 		progress_message+="."

		# append a space to separate cursor from message
		progress_message+=" "

		echo -n "$progress_message"
		strlength=${#progress_message}
	fi

	}

function RefreshActiveCounts
	{

	[ -e "${success_count_pathfile}" ] && success_count=$(<"${success_count_pathfile}") || success_count=0
	[ -e "${failure_count_pathfile}" ] && failure_count=$(<"${failure_count_pathfile}") || failure_count=0
	[ -e "${unknown_size_count_pathfile}" ] && unknown_size_count=$(<"${unknown_size_count_pathfile}") || unknown_size_count=0
	[ -e "${spawn_count_pathfile}" ] && spawn_count=$(<"${spawn_count_pathfile}") || spawn_count=0

	}

function AddToDebug
	{

	# $1 = item
	# $2 = value

	[ "$debug" == "true" ] && echo "$1: '$2'" >> "${debug_file}"

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

# check for command-line parameters
user_parameters=`getopt -o h,g,d,q,v,l:,u:,r:,t:,c:,f:,n:,p: --long help,no-gallery,debug,quiet,version,lower-size:,upper-size:,retries:,timeout:,concurrency:,failures:,number:,phrase: -n $( readlink -f -- "$0" ) -- "$@"`
user_parameters_result=$?

Init

# user parameter validation and bounds checks
if [ "$exitcode" -eq "0" ] ; then
	case ${images_required#[-+]} in
		*[!0-9]* )
			AddToDebug "! specified \$images_required" "invalid"
			echo " !! number specified after (-n --number) must be a valid integer ... unable to continue."
			echo
			ShowHelp
			exitcode=2
			;;
		* )
			if [ "$images_required" -lt "1" ] ; then
				images_required=1
				AddToDebug "~ \$images_required too small so set sensible minimum" "$images_required"
			fi

			if [ "$images_required" -gt "$results_max" ] ; then
				images_required=$results_max
				AddToDebug "~ \$images_required too large so set as \$results_max" "$images_required"
			fi
			;;
	esac

	case ${failures_limit#[-+]} in
		*[!0-9]* )
			AddToDebug "! specified \$failures_limit" "invalid"
			echo " !! number specified after (-f --failures) must be a valid integer ... unable to continue."
			echo
			ShowHelp
			exitcode=2
			;;
		* )
			if [ "$failures_limit" -le "0" ] ; then
				failures_limit=$results_max
				AddToDebug "~ \$failures_limit too small so set as \$results_max" "$failures_limit"
			fi

			if [ "$failures_limit" -gt "$results_max" ] ; then
				failures_limit=$results_max
				AddToDebug "~ \$failures_limit too large so set as \$results_max" "$failures_limit"
			fi
			;;
	esac

	case ${spawn_limit#[-+]} in
		*[!0-9]* )
			AddToDebug "! specified \$spawn_limit" "invalid"
			echo " !! number specified after (-c --concurrency) must be a valid integer ... unable to continue."
			echo
			ShowHelp
			exitcode=2
			;;
		* )
			if [ "$spawn_limit" -lt "1" ] ; then
				spawn_limit=1
				AddToDebug "~ \$spawn_limit too small so set as" "$spawn_limit"
			fi

			if [ "$spawn_limit" -gt "$spawn_max" ] ; then
				spawn_limit=$spawn_max
				AddToDebug "~ \$spawn_limit too large so set as" "$spawn_limit"
			fi
			;;
	esac

	case ${timeout#[-+]} in
		*[!0-9]* )
			AddToDebug "! specified \$timeout" "invalid"
			echo " !! number specified after (-t --timeout) must be a valid integer ... unable to continue."
			echo
			ShowHelp
			exitcode=2
			;;
		* )
			if [ "$timeout" -lt "1" ] ; then
				timeout=1
				AddToDebug "~ \$timeout too small so set as" "$timeout"
			fi

			if [ "$timeout" -gt "$timeout_max" ] ; then
				timeout=$timeout_max
				AddToDebug "~ \$timeout too large so set as" "$timeout"
			fi
			;;
	esac

	case ${retries#[-+]} in
		*[!0-9]* )
			AddToDebug "! specified \$retries" "invalid"
			echo " !! number specified after (-r --retries) must be a valid integer ... unable to continue."
			echo
			ShowHelp
			exitcode=2
			;;
		* )
			if [ "$retries" -lt "1" ] ; then
				retries=1
				AddToDebug "~ \$retries too small so set as" "$retries"
			fi

			if [ "$retries" -gt "$retries_max" ] ; then
				retries=$retries_max
				AddToDebug "~ \$retries too large so set as" "$retries"
			fi
			;;
	esac

	case ${upper_size_limit#[-+]} in
		*[!0-9]* )
			AddToDebug "! specified \$upper_size_limit" "invalid"
			echo " !! number specified after (-u --upper-size) must be a valid integer ... unable to continue."
			echo
			ShowHelp
			exitcode=2
			;;
		* )
			if [ "$upper_size_limit" -lt "0" ] ; then
				upper_size_limit=0
				AddToDebug "~ \$upper_size_limit too small so set as" "$upper_size_limit (unlimited)"
			fi
			;;
	esac

	case ${lower_size_limit#[-+]} in
		*[!0-9]* )
			AddToDebug "! specified \$lower_size_limit" "invalid"
			echo " !! number specified after (-l --lower-size) must be a valid integer ... unable to continue."
			echo
			ShowHelp
			exitcode=2
			;;
		* )
			if [ "$lower_size_limit" -lt "0" ] ; then
				lower_size_limit=0
				AddToDebug "~ \$lower_size_limit too small so set as" "$lower_size_limit"
			fi

			if [ "$upper_size_limit" -gt "0" ] && [ "$lower_size_limit" -gt "$upper_size_limit" ] ; then
				lower_size_limit=$(($upper_size_limit-1))
				AddToDebug "~ \$lower_size_limit larger than \$upper_size_limit ($upper_size_limit) so set as" "$lower_size_limit"
			fi
			;;
	esac

	if [ ! "$user_query" ] ; then
		AddToDebug "! \$user_query" "unspecified"
		echo " !! search phrase (-p --phrase) was unspecified ... unable to continue."
		echo
		ShowHelp
		exitcode=2
	fi
fi

# create directory for search phrase
if [ "$exitcode" -eq "0" ] ; then
	target_path="${current_path}/${user_query}"
	imagelist_pathfile="${target_path}/${imagelinkslist_file}"
	targetimage_pathfile="${target_path}/${image_file}"

	[ "$verbose" == "true" ] && echo " > ${script_details}"
	[ "$verbose" == "true" ] && echo

	mkdir -p "${target_path}"

	if [ "$?" -gt "0" ] ; then
		echo " !! couldn't create sub-directory [${target_path}] for phrase \"${user_query}\" ... unable to continue."
		exitcode=3
	fi
fi

# get list of search results
if [ "$exitcode" -eq "0" ] ; then
	DownloadList

	if [ "$?" -gt "0" ] ; then
		echo " !! couldn't download Google search results ... unable to continue."
		exitcode=4
	fi
fi

# download images and build gallery
if [ "$exitcode" -eq "0" ] ; then
	DownloadImages

	if [ "$?" -gt "0" ] ; then
		echo " !! failure limit reached!"
		AddToDebug "! failure limit reached" "$failures_limit"
		exitcode=5
	fi

	# build thumbnail gallery even if failures_limit was reached
	if [ "$create_gallery" == "true" ] ; then
		BuildGallery

		if [ "$?" -gt "0" ] ; then
			echo " !! couldn't build thumbnail gallery ... unable to continue (but we're all done anyway)."
			exitcode=6
		fi
	fi
fi

# write results into debug file
if [ "$debug" == "true" ] ; then
	AddToDebug "? image download \$failure_count" "$failure_count"
	AddToDebug "T [$script_name] elapsed time" "$(ConvertSecs "$(($(date +%s)-$script_startseconds))")"
	AddToDebug "< finished" "$(date)"
fi

exit $exitcode
