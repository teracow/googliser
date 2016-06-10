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
#	2	required parameter unspecified or wrong
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
#	=	evaluation
#	~	variable had boundary issues so was set within bounds
#	$	success
#	!	failure
#	T	elapsed time

function Init
	{

	script_version="1.17"
	script_date="2016-06-11"
	script_name="$(basename -- "$(readlink -f -- "$0")")"
	script_details="${script_name} - v${script_version} (${script_date}) PID:[$$]"

	current_path="$PWD"
	temp_path="/dev/shm/$script_name.$$"

	mkdir -p "${temp_path}"

	image_file="google-image"
	gallery_name="googliser-gallery"
	imagelist_file="download.links.list"
	debug_file="debug.log"

	results_success_count_pathfile="${temp_path}/results.success.count"
	results_fail_count_pathfile="${temp_path}/results.fail.count"
	download_success_count_pathfile="${temp_path}/download.success.count"
	download_fail_count_pathfile="${temp_path}/download.fail.count"
	download_unknown_size_count_pathfile="${temp_path}/download.unknown.size.count"
	results_pathfile="${temp_path}/results.page.html"
	gallery_title_pathfile="${temp_path}/gallery.title.png"
	gallery_thumbnails_pathfile="${temp_path}/gallery.thumbnails.png"
	gallery_background_pathfile="${temp_path}/gallery.background.png"
	debug_pathfile="${temp_path}/${debug_file}"
	imagelist_pathfile="${temp_path}/${imagelist_file}"

	server="www.google.com.au"

	# http://whatsmyuseragent.com
	useragent='Mozilla/5.0 (X11; Linux x86_64; rv:46.0) Gecko/20100101 Firefox/46.0'

	results_max=1000
	spawn_max=40
	timeout_max=600
	retries_max=100

	# user parameters
	user_query=""
	images_required=25
	spawn_limit=8
	fail_limit=40
	upper_size_limit=0
	lower_size_limit=1000
	timeout=15
	retries=3
	create_gallery=true
	verbose=true
	debug=false
	gallery_title=""

	script_starttime=$(date)
	script_startseconds=$(date +%s)
	result_index=0
	target_path_created=false
	helpme=false
	showversion=false
	showhelp=false

	WhatAreMyOptions

	exitcode=$?

	# display start
	if [ "$showversion" == "true" ] ; then
		echo "v${script_version} (${script_date})"
		verbose=false
	fi

	if [ "$verbose" == "true" ] ; then
		echo " > ${script_details}"
		echo
	fi

	if [ "$showhelp" == "true" ] ; then
		DisplayHelp
	fi

	DebugThis "> started" "$script_starttime"
	DebugThis "? \$script_details" "$script_details"
	DebugThis "? \$user_query" "$user_query"
	DebugThis "? \$images_required" "$images_required"
	DebugThis "? \$spawn_limit" "$spawn_limit"
	DebugThis "? \$upper_size_limit" "$upper_size_limit"
	DebugThis "? \$lower_size_limit" "$lower_size_limit"
	DebugThis "? \$results_max" "$results_max"
	DebugThis "? \$fail_limit" "$fail_limit"
	DebugThis "? \$verbose" "$verbose"
	DebugThis "? \$create_gallery" "$create_gallery"
	DebugThis "? \$gallery_title" "$gallery_title"
	DebugThis "? \$temp_path" "$temp_path"

	IsProgramAvailable "wget" || exitcode=1
	IsProgramAvailable "perl" || exitcode=1

	if [ "$create_gallery" == "true" ] ; then
		IsProgramAvailable "montage" || exitcode=1
		IsProgramAvailable "convert" || exitcode=1
	fi

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

function DisplayHelp
	{

	DebugThis "\ [${FUNCNAME[0]}]" "entry"

	local sample_user_query="cows"

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
	HelpParameterFormat "f" "failures INTEGER [$fail_limit]" "How many download failures before exiting? 0 for unlimited ($results_max)."
	HelpParameterFormat "c" "concurrency INTEGER [$spawn_limit]" "How many concurrent image downloads? Maximum of $spawn_max. Use wisely!"
	HelpParameterFormat "t" "timeout INTEGER [$timeout]" "Number of seconds before retrying download. Maximum of $timeout_max."
	HelpParameterFormat "r" "retries INTEGER [$retries]" "Try to download each image this many times. Maximum of $retries_max."
	HelpParameterFormat "u" "upper-size INTEGER [$upper_size_limit]" "Only download images that are smaller than this size. 0 for unlimited size."
	HelpParameterFormat "l" "lower-size INTEGER [$lower_size_limit]" "Only download images that are larger than this size."
	HelpParameterFormat "i" "title STRING" "Custom title for thumbnail gallery. Default is search phrase (-p --phrase)."
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

	DebugThis "/ [${FUNCNAME[0]}]" "exit"

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
	[ "$user_parameters_result" != "0" ] && echo && DisplayHelp && return 2

	eval set -- "$user_parameters"

	while true
	do
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
			-i | --title )
				gallery_title="$2"
				shift 2		# shift to next parameter in $1
				;;
			-h | --help )
				showhelp=true
				return 7
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
				showversion=true
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

function IsProgramAvailable
	{

	# $1 = name of program to search for with 'which'
	# $? = 0 if 'which' found it, 1 if not

	which "$1" > /dev/null 2>&1

	if [ "$?" -gt "0" ] ; then
		echo " !! required program [$1] is unavailable ... unable to continue."
		echo
		DebugThis "! required program is unavailable" "$1"
		DisplayHelp
		return 1
	else
		DebugThis "$ required program is available" "$1"
		return 0
	fi

	}

function DownloadResultSegment_auto
	{

	# *** This function runs as a background process ***
	# $1 = page segment to load:		(0, 1, 2, 3, etc...)
	# $2 = pointer starts at result:	(0, 100, 200, 300, etc...)

	local search_segment="&ijn=$1"
	local search_start="&start=$2"

	DebugThis "- result segment #$1 download" "start"

	local wget_list_cmd="wget --quiet 'https://${server}/search?${search_type}${search_match_type}${search_phrase}${search_language}${search_style}${search_segment}${search_start}' --user-agent '$useragent' --output-document \"${results_pathfile}.$1\""
	DebugThis "? \$wget_list_cmd" "$wget_list_cmd"

	eval $wget_list_cmd
	result=$?

	if [ "$result" -eq "0" ] ; then
		DebugThis "$ result segment #$1 download" "success!"
		IncrementFile "${results_success_count_pathfile}"
	else
		DebugThis "! result segment #$1 download" "failed! Wget returned: ($result - $(WgetReturnCodes "$result"))"
		IncrementFile "${results_fail_count_pathfile}"
	fi

	return 0

	}

function DownloadResultSegments
	{

	DebugThis "\ [${FUNCNAME[0]}]" "entry"

	local func_startseconds=$(date +%s)
	local segments_max=$(($results_max/100))
	local pointer=0
	local strlength=0
	local spawn_count=0

	[ "$verbose" == "true" ] && echo -n " -> Searching Google for phrase \"$user_query\": "

	ResetAllResultCounts

	for ((segment=1; segment<=$segments_max; segment++)) ; do
		RefreshActiveResultCounts

		if [ "$spawn_count" -eq "$spawn_limit" ] ; then
			# wait here while all running downloads finish
			# when all current downloads have finished, then start next batch

			wait
		fi

		while true; do
			RefreshActiveResultCounts

			ProgressUpdater "${success_count}/${segments_max} result segments have been downloaded."

  			[ "$spawn_count" -lt "$spawn_limit" ] && break

			sleep 0.5
		done

		pointer=$((($segment-1)*100))

		# derived from: http://stackoverflow.com/questions/24284460/calculating-rounded-percentage-in-shell-script-without-using-bc
# 		percent="$((200*($segment-1)/$segments_max % 2 + 100*($segment-1)/$segments_max))% "

		DownloadResultSegment_auto $(($segment-1)) "$pointer" &
	done

	# wait here while all running downloads finish
	wait

	RefreshActiveResultCounts
	ProgressUpdater "${success_count}/${segments_max} result segments have been downloaded."

	# build all segments into a single file
	cat "${results_pathfile}".* > "${results_pathfile}"
	#rm -f "${results_pathfile}".*

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
	# $2 = current counter relative to main list

	local result=0
	local size_ok=true
	local get_download=true

	DebugThis "- link #$2 download" "start"

	# extract file extension by checking only last 5 characters of URL (to handle .jpeg as worst case)
	ext=$(echo ${1:(-5)} | sed "s/.*\(\.[^\.]*\)$/\1/")

	[[ "$ext" =~ "." ]] || ext=".jpg"	# if URL did not have a file extension then choose jpg as default

	targetimage_pathfileext="${targetimage_pathfile}($2)${ext}"

	# are file size limits going to be applied before download?
	if [ "$upper_size_limit" -gt "0" ] || [ "$lower_size_limit" -gt "0" ] ; then
		# try to get file size from server
		estimated_size="$(wget --max-redirect 0 --timeout=${timeout} --tries=${retries} --user-agent ${useragent} --spider "${imagelink}" 2>&1 | grep -i "length" | cut -d' ' -f2)"
		# possible return values are: 'unspecified', '123456' (integers), '' (empty)

		if [ -z "$estimated_size" ] || [ "$estimated_size" == "unspecified" ] ; then
			estimated_size="unknown"
		fi

		DebugThis "? link #$2 \$estimated_size" "$estimated_size bytes"

		if [ "$estimated_size" != "unknown" ] ; then
			if [ "$estimated_size" -lt "$lower_size_limit" ] ; then
				DebugThis "! link #$2 (before download) is too small!" "$estimated_size bytes < $lower_size_limit bytes"
				size_ok=false
				get_download=false
			fi

			if [ "$upper_size_limit" != "0" ] && [ "$estimated_size" -gt "$upper_size_limit" ] ; then
				DebugThis "! link #$2 (before download) is too large!" "$estimated_size bytes > $upper_size_limit bytes"
				size_ok=false
				get_download=false
			fi
		fi
	fi

	# perform actual image download
	if [ "$get_download" == "true" ] ; then
		[ "$estimated_size" == "unknown" ] && IncrementFile "${download_unknown_size_count_pathfile}"

		local wget_download_cmd="wget --max-redirect 0 --timeout=${timeout} --tries=${retries} --user-agent \"$useragent\" --output-document \"${targetimage_pathfileext}\" \"${imagelink}\""
		DebugThis "? \$wget_download_cmd" "$wget_download_cmd"

		# http://stackoverflow.com/questions/36249714/parse-download-speed-from-wget-output-in-terminal
		download_speed=$(eval $wget_download_cmd 2>&1 | grep -o '\([0-9.]\+ [KM]B/s\)')
		result=$?

		if [ "$result" -eq "0" ] ; then
			if [ -e "${targetimage_pathfileext}" ] ; then
				actual_size=$(wc -c < "$targetimage_pathfileext")

				if [ "$actual_size" == "$estimated_size" ] ; then
					DebugThis "? link #$2 \$actual_size" "$actual_size bytes (estimate was correct)"
				else
					DebugThis "? link #$2 \$actual_size" "$actual_size bytes (estimate of $estimated_size bytes was incorrect)"
				fi

				if [ "$actual_size" -lt "$lower_size_limit" ] ; then
					DebugThis "! link #$2 \$actual_size (after download) is too small!" "$actual_size bytes < $lower_size_limit bytes"
					rm -f "$targetimage_pathfileext"
					size_ok=false
				fi

				if [ "$upper_size_limit" -gt "0" ] && [ "$actual_size" -gt "$upper_size_limit" ] ; then
					DebugThis "! link #$2 \$actual_size (after download) is too large!" "$actual_size bytes > $upper_size_limit bytes"
					rm -f "$targetimage_pathfileext"
					size_ok=false
				fi
			else
				# file does not exist
				size_ok=false
			fi

			if [ "$size_ok" == "true" ] ; then
				DebugThis "$ link #$2 download" "success!"
				IncrementFile "${download_success_count_pathfile}"
				DebugThis "? link #$2 \$download_speed" "$download_speed"
			else
				# files that were outside size limits still count as failures
				IncrementFile "${download_fail_count_pathfile}"
			fi
		else
			DebugThis "! link #$2 download" "failed! Wget returned $result ($(WgetReturnCodes "$result"))"
			IncrementFile "${download_fail_count_pathfile}"

			# delete temp file if one was created
			[ -e "${targetimage_pathfileext}" ] && rm -f "${targetimage_pathfileext}"
		fi

		[ "$estimated_size" == "unknown" ] && DecrementFile "${download_unknown_size_count_pathfile}"
	else
		IncrementFile "${download_fail_count_pathfile}"
	fi

	return 0

	}

function DownloadImages
	{

	DebugThis "\ [${FUNCNAME[0]}]" "entry"

	local func_startseconds=$(date +%s)
	local result_index=0
	local file_index=1
	local message=""
	local countdown=$images_required		# control how many files are downloaded. Counts down to zero.
	local strlength=0
	local result=0

	ResetAllDownloadCounts

	[ "$verbose" == "true" ] && echo -n " -> "

	while read imagelink; do
		while true; do
			RefreshActiveDownloadCounts
			ShowImageDownloadProgress

			[ "$spawn_count" -lt "$spawn_limit" ] && break

			sleep 0.5
		done

		if [ "$countdown" -gt "0" ] ; then
			# some images are still required
			if [ "$fail_count" -ge "$fail_limit" ] ; then
				# but too many failures so stop downloading.
				DebugThis "! failure limit reached" "$fail_limit"
 				result=1

 				# wait here while all running downloads finish
				wait

 				break
 			fi

			((result_index++))

			DownloadImage_auto "$msg" "$result_index" &
			((countdown--))
		else
			# can't start any more concurrent downloads yet so kill some time
			# wait here while all running downloads finish
			wait

# 			ResetUnknownSizesCount
			RefreshActiveDownloadCounts
			ShowImageDownloadProgress

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
	wait

# 	ResetUnknownSizesCount
	RefreshActiveDownloadCounts
	ShowImageDownloadProgress

	[ "$spawn_count" -gt "0" ] && DebugThis "! \$spawn_count" "$spawn_count ($(jobs -l))"

	[ "$verbose" == "true" ] && echo

	DebugThis "? \$success_count" "$success_count"
	DebugThis "? \$fail_count" "$fail_count"
	DebugThis "T [${FUNCNAME[0]}] elapsed time" "$(ConvertSecs "$(($(date +%s )-$func_startseconds))")"
	DebugThis "/ [${FUNCNAME[0]}]" "exit"

	return $result

	}

function ParseResults
	{

	DebugThis "\ [${FUNCNAME[0]}]" "entry"

	result_count=0

	# regexes explained:
	# 1. look for lines with '<div' and insert 2 linefeeds before them
	# 2. only list lines with '<div class="rg_meta">' and eventually followed by 'http'
	# 3. only list lines without 'youtube' or 'vimeo'
	# 4. remove everything from '<div class="rg_meta">' up to 'http' but keep 'http' on each line
	# 5. remove everything including and after '","ow"' on each line
	# 6. remove everything including and after '?' on each line

	cat "${results_pathfile}" | sed 's|<div|\n\n<div|g' | grep '<div class=\"rg_meta\">.*http' | grep -ivE 'youtube|vimeo' | perl -pe 's|(<div class="rg_meta">)(.*?)(http)|\3|; s|","ow".*||; s|\?.*||' > "${imagelist_pathfile}"

	if [ -e "$imagelist_pathfile" ] ; then
		result_count=$(wc -l < "${imagelist_pathfile}")

		[ "$verbose" == "true" ] && echo "Found ${result_count} results!"
	else
		[ "$verbose" == "true" ] && echo "No results to count!"
	fi

	DebugThis "? \$result_count" "$result_count"
	DebugThis "/ [${FUNCNAME[0]}]" "exit"

	}

function BuildGallery
	{

	local title_font="Century-Schoolbook-L-Bold-Italic"
	local title_colour="goldenrod1"
	local strlength=0

	DebugThis "\ [${FUNCNAME[0]}]" "entry"

	local func_startseconds=$(date +%s)

	[ "$verbose" == "true" ] && echo -n " -> Building thumbnail gallery: "

	ProgressUpdater "step 1 (construct thumbnails)"

	# build gallery
	build_foreground_cmd="montage \"${target_path}/*[0]\" -background none -shadow -geometry 400x400 miff:- | convert - -background none -gravity north -splice 0x140 -bordercolor none -border 30 \"${gallery_thumbnails_pathfile}\""

	DebugThis "? \$build_foreground_cmd" "$build_foreground_cmd"

	eval $build_foreground_cmd 2> /dev/null
	result=$?

	if [ "$result" -eq "0" ] ; then
		DebugThis "$ \$build_foreground_cmd" "success!"
	else
		DebugThis "! \$build_foreground_cmd" "failed! montage returned: ($result)"
	fi

	if [ "$result" -eq "0" ] ; then
		ProgressUpdater "step 2 (draw background pattern)"

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
		ProgressUpdater "step 3 (draw title text image)"

		# create title image
		# let's try a fixed height of 100 pixels
		build_title_cmd="convert -size x100 -font $title_font -background none -stroke black -strokewidth 10 label:\"${gallery_title}\" -blur 0x5 -fill $title_colour -stroke none label:\"${gallery_title}\" -flatten \"${gallery_title_pathfile}\""

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
		ProgressUpdater "step 4 (compile all images)"

		# compose thumbnails image on background image, then title image on top
		build_compose_cmd="convert \"${gallery_background_pathfile}\" \"${gallery_thumbnails_pathfile}\" -gravity center -composite \"${gallery_title_pathfile}\" -gravity north -geometry +0+25 -composite \"${target_path}/${gallery_name}-($user_query).png\""

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
			# backspace to start of previous message - then overwrite with spaces - then backspace to start again!
			printf "%${strlength}s" | tr ' ' '\b' ; printf "%${strlength}s" ; printf "%${strlength}s" | tr ' ' '\b'
			echo "done!"
		fi
	else
		DebugThis "! [${FUNCNAME[0]}]" "failed! See previous!"
		[ "$verbose" == "true" ] && echo "failed!"
	fi

	DebugThis "T [${FUNCNAME[0]}] elapsed time" "$(ConvertSecs "$(($(date +%s)-$func_startseconds))")"
	DebugThis "/ [${FUNCNAME[0]}]" "exit"

	return $result

	}

function ResetUnknownSizesCount
	{

	unknown_size_count=0

	echo "${unknown_size_count}" > "${download_unknown_size_count_pathfile}"

	}

function ResetAllResultCounts
	{

	success_count=0
	echo "${success_count}" > "${results_success_count_pathfile}"

	fail_count=0
	echo "${fail_count}" > "${results_fail_count_pathfile}"

	}

function ResetAllDownloadCounts
	{

	ResetUnknownSizesCount

	success_count=0
	echo "${success_count}" > "${download_success_count_pathfile}"

	fail_count=0
	echo "${fail_count}" > "${download_fail_count_pathfile}"

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

function ProgressUpdater
	{

	# This will take a message and overwrite the previous one if $strlength has been set.

	# $1 = message to display.

	if [ "$verbose" == "true" ] ; then
		# backspace to start of previous message - then overwrite with spaces - then backspace to start again!
		printf "%${strlength}s" | tr ' ' '\b' ; printf "%${strlength}s" ; printf "%${strlength}s" | tr ' ' '\b'

		echo -n "$1 "
		strlength=$((${#1}+1))
	fi

	}

function ShowImageDownloadProgress
	{

	if [ "$verbose" == "true" ] ; then
		# number of image downloads that are OK
		progress_message="${success_count}/${images_required} images have downloaded"

		# include failures (if any)
		if [ "$fail_count" -gt "0" ] ; then
			progress_message+=" with ${fail_count}/${fail_limit} failures"
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

		ProgressUpdater "${progress_message}"
	fi

	}

function RefreshActiveResultCounts
	{

	[ -e "${results_success_count_pathfile}" ] && success_count=$(<"${results_success_count_pathfile}") || success_count=0
	[ -e "${results_fail_count_pathfile}" ] && fail_count=$(<"${results_fail_count_pathfile}") || fail_count=0

	spawn_count=$(jobs -p | wc -w)

	}

function RefreshActiveDownloadCounts
	{

	[ -e "${download_success_count_pathfile}" ] && success_count=$(<"${download_success_count_pathfile}") || success_count=0
	[ -e "${download_fail_count_pathfile}" ] && fail_count=$(<"${download_fail_count_pathfile}") || fail_count=0
	[ -e "${download_unknown_size_count_pathfile}" ] && unknown_size_count=$(<"${download_unknown_size_count_pathfile}") || unknown_size_count=0

	spawn_count=$(jobs -p | wc -w)

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

# check for command-line parameters
user_parameters=`getopt -o h,g,d,q,v,i:,l:,u:,r:,t:,c:,f:,n:,p: --long help,no-gallery,debug,quiet,version,title:,lower-size:,upper-size:,retries:,timeout:,concurrency:,failures:,number:,phrase: -n $(readlink -f -- "$0") -- "$@"`
user_parameters_result=$?

Init

# user parameter validation and bounds checks
if [ "$exitcode" -eq "0" ] ; then
	case ${images_required#[-+]} in
		*[!0-9]* )
			DebugThis "! specified \$images_required" "invalid"
			DisplayHelp
			echo
			echo " !! number specified after (-n --number) must be a valid integer ... unable to continue."
			exitcode=2
			;;
		* )
			if [ "$images_required" -lt "1" ] ; then
				images_required=1
				DebugThis "~ \$images_required too small so set sensible minimum" "$images_required"
			fi

			if [ "$images_required" -gt "$results_max" ] ; then
				images_required=$results_max
				DebugThis "~ \$images_required too large so set as \$results_max" "$images_required"
			fi
			;;
	esac

	if [ "$exitcode" -eq "0" ] ; then
		case ${fail_limit#[-+]} in
			*[!0-9]* )
				DebugThis "! specified \$fail_limit" "invalid"
				DisplayHelp
				echo
				echo " !! number specified after (-f --failures) must be a valid integer ... unable to continue."
				exitcode=2
				;;
			* )
				if [ "$fail_limit" -le "0" ] ; then
					fail_limit=$results_max
					DebugThis "~ \$fail_limit too small so set as \$results_max" "$fail_limit"
				fi

				if [ "$fail_limit" -gt "$results_max" ] ; then
					fail_limit=$results_max
					DebugThis "~ \$fail_limit too large so set as \$results_max" "$fail_limit"
				fi
				;;
		esac
	fi

	if [ "$exitcode" -eq "0" ] ; then
		case ${spawn_limit#[-+]} in
			*[!0-9]* )
				DebugThis "! specified \$spawn_limit" "invalid"
				DisplayHelp
				echo
				echo " !! number specified after (-c --concurrency) must be a valid integer ... unable to continue."
				exitcode=2
				;;
			* )
				if [ "$spawn_limit" -lt "1" ] ; then
					spawn_limit=1
					DebugThis "~ \$spawn_limit too small so set as" "$spawn_limit"
				fi

				if [ "$spawn_limit" -gt "$spawn_max" ] ; then
					spawn_limit=$spawn_max
					DebugThis "~ \$spawn_limit too large so set as" "$spawn_limit"
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
				echo " !! number specified after (-t --timeout) must be a valid integer ... unable to continue."
				exitcode=2
				;;
			* )
				if [ "$timeout" -lt "1" ] ; then
					timeout=1
					DebugThis "~ \$timeout too small so set as" "$timeout"
				fi

				if [ "$timeout" -gt "$timeout_max" ] ; then
					timeout=$timeout_max
					DebugThis "~ \$timeout too large so set as" "$timeout"
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
				echo " !! number specified after (-r --retries) must be a valid integer ... unable to continue."
				exitcode=2
				;;
			* )
				if [ "$retries" -lt "1" ] ; then
					retries=1
					DebugThis "~ \$retries too small so set as" "$retries"
				fi

				if [ "$retries" -gt "$retries_max" ] ; then
					retries=$retries_max
					DebugThis "~ \$retries too large so set as" "$retries"
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
				echo " !! number specified after (-u --upper-size) must be a valid integer ... unable to continue."
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
				echo " !! number specified after (-l --lower-size) must be a valid integer ... unable to continue."
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
			echo " !! search phrase (-p --phrase) was unspecified ... unable to continue."
			exitcode=2
		else
			target_path="${current_path}/${user_query}"
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
		echo " !! sub-directory [${target_path}] already exists ... unable to continue."
		exitcode=3
	fi

	if [ "$exitcode" -eq "0" ] ; then
		mkdir -p "${target_path}"
		result=$?

		if [ "$result" -gt "0" ] ; then
			DebugThis "! create sub-directory [${target_path}]" "failed! mkdir returned: ($result)"
			echo " !! couldn't create sub-directory [${target_path}] ... unable to continue."
			exitcode=3
		else
			DebugThis "$ create sub-directory [${target_path}]" "success!"
			target_path_created=true
		fi
	fi
fi

# get list of search results
if [ "$exitcode" -eq "0" ] ; then
	DownloadResultSegments

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
		exitcode=5
	fi
fi

# build thumbnail gallery even if fail_limit was reached
if [ "$exitcode" -eq "0" ] || [ "$exitcode" -eq "5" ] ; then
	if [ "$create_gallery" == "true" ] ; then
		BuildGallery

		if [ "$?" -gt "0" ] ; then
			echo " !! couldn't build thumbnail gallery ... unable to continue (but we're all done anyway)."
			exitcode=6
		fi
	fi
fi

# copy links list into target directory
[ "$target_path_created" == "true" ] && cp -f "${imagelist_pathfile}" "${target_path}/${imagelist_file}"

# write results into debug file
DebugThis "T [$script_name] elapsed time" "$(ConvertSecs "$(($(date +%s)-$script_startseconds))")"
DebugThis "< finished" "$(date)"

# copy debug file into target directory if possible. If not, then copy to current directory.
if [ "$debug" == "true" ] ; then
	if [ "$target_path_created" == "true" ] ; then
		[ -e "${target_path}/${debug_file}" ] && echo "" >> "${target_path}/${debug_file}"

		cat "${debug_pathfile}" >> "${target_path}/${debug_file}"
	else
		[ -e "${current_path}/${debug_file}" ] && echo "" >> "${current_path}/${debug_file}"

		cat "${debug_pathfile}" >> "${current_path}/${debug_file}"
	fi
fi

# display end
if [ "$verbose" == "true" ] ; then
	case "$exitcode" in
		0 )
			echo
			echo " -> Finished!"
			;;
		[1-6] )
			echo
			echo " -> Finished! (with errors)"
			;;
		* )
			;;
	esac
fi

# reset exitcode if only displaying info
if [ "$showversion" == "true" ] || [ "$showhelp" == "true" ] ; then
	exitcode=0
fi

exit $exitcode
