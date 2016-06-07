#/bin/bash

# Copyright (C) 2016 Teracow Software

# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

# If you find this code useful, please let me know. :) teracow@gmail.com

# return values:
#    $? = 0 - completed successfully.
#	= 1 - required program unavailable (wget, perl, montage).
#	= 2 - required parameter unspecified or wrong - help shown or version requested.
#	= 3 - could not create subdirectory for 'search phrase'.
#	= 4 - could not get a list of search results from Google.
#	= 5 - image download aborted as failure limit was reached.
#	= 6 - thumbnail gallery build failed.

# The latest copy can be found here [https://github.com/teracow/googliser]

function Init
	{

	script_version="1.14"
	script_date="2016-06-08"
	script_name="$( basename -- "$( readlink -f -- "$0" )" )"
	script_details="${script_name} - v${script_version} (${script_date})"

	current_path="$PWD"
	temp_path="/dev/shm"
	gallery_name="googliser-gallery"
	imagelinkslist_file="googliser-links.list"
	debug_file="googliser-debug.log"
	image_file="google-image"
	results_file="google-results.html"
	server="www.google.com.au"

	exitcode=0
	results_max=400
	result_index=0
	failures_count=0
	spawn_max=40
	timeout_max=600
	retries_max=100
	process_tracker_pathfile="${temp_path}/child-process.count"
	download_success_count_pathfile="${temp_path}/successful-downloads.count"
	download_failures_count_pathfile="${temp_path}/failed-downloads.count"

	# user parameters
	user_query=""
	images_required=25
	spawn_limit=8
	failures_limit=10
	timeout=15
	retries=2
	create_gallery=true
	verbose=true
	debug=false

	# http://whatsmyuseragent.com
	useragent='Mozilla/5.0 (X11; Linux x86_64; rv:46.0) Gecko/20100101 Firefox/46.0'

	script_starttime=$( date )
	script_startseconds=$( date +%s )

	WhatAreMyOptions

	exitcode=$?

	if [ "$debug" == true ] ; then
		[ -e "${debug_file}" ] && echo "" >> "${debug_file}"
		AddToDebugFile "> started" "$script_starttime"
		AddToDebugFile "? \$script_details" "$script_details"
		AddToDebugFile "? \$user_query" "$user_query"
		AddToDebugFile "? \$images_required" "$images_required"
		AddToDebugFile "? \$spawn_limit" "$spawn_limit"
		AddToDebugFile "? \$results_max" "$results_max"
		AddToDebugFile "? \$failures_limit" "$failures_limit"
		AddToDebugFile "? \$verbose" "$verbose"
		AddToDebugFile "? \$create_gallery" "$create_gallery"
	fi

	IsProgramAvailable "wget" || exitcode=1
	IsProgramAvailable "perl" || exitcode=1

	if [ "$create_gallery" == true ] ; then
		IsProgramAvailable "montage" || exitcode=1
	fi

	[ -e "${download_success_count_pathfile}" ] && rm -f "${download_success_count_pathfile}"
	[ -e "${download_failures_count_pathfile}" ] && rm -f "${download_failures_count_pathfile}"

	# 'nfpr=1' seems to perform exact string search - does not show most likely match results or suggested search.
	search_match_type="&nfpr=1"

	# 'tbm=isch' seems to search for images
	search_type="&tbm=isch"

	# 'q=' is the user supplied search query
	search_phrase="&q=$( echo $user_query | tr ' ' '+' )"	# replace whitepace with '+' to suit curl/wget

	# 'hl=en' seems to be language
	search_language="&hl=en"

	# 'site=imghp' seems to be result layout style
	search_style="&site=imghp"

	}

function ShowHelp
	{

	local sample_images_required=12
	local sample_user_query_short="cows"
	local sample_user_query_long="small brown cows"

	echo " > ${script_details}"
	echo
	echo " - Basic: search 'Google Images' then download each of the image URLs returned."
	echo
	echo " - Description: downloads the first [n]umber of images returned by Google Images for [p]hrase. These are then built into a gallery using ImageMagick." | fold -s -w80
	echo
	echo " - This is an expansion upon a solution provided by ShellFish on:"
	echo " [https://stackoverflow.com/questions/27909521/download-images-from-google-with-command-line]"
	echo
	echo " - Requirements: Wget and Perl"
	echo " - Optional: montage (from ImageMagick)"
	echo
	echo " - Questions or comments? teracow@gmail.com"
	echo
	echo " - Usage: ./$script_name [PARAMETERS] ..."
	echo
	echo " Mandatory arguments to long options are mandatory for short options too."
	HelpParameterFormat "n" "number=INTEGER ($images_required)" "Number of images to download. Maximum of $results_max."
	HelpParameterFormat "p" "phrase=STRING (required)" "Search phrase to look for. Enclose whitespace in quotes e.g. \"$sample_user_query_long\"."
	HelpParameterFormat "f" "failures=INTEGER ($failures_limit)" "How many download failures before exiting? 0 for unlimited ($results_max)."
	HelpParameterFormat "c" "concurrency=INTEGER ($spawn_limit)" "How many concurrent image downloads? Maximum of $spawn_max. Use wisely!"
	HelpParameterFormat "t" "timeout=INTEGER ($timeout)" "Number of seconds before retrying download. Maximum of $timeout_max."
	HelpParameterFormat "r" "retries=INTEGER ($retries)" "Try to download each image this many times. Maximum of $retries_max."
	HelpParameterFormat "g" "no-gallery" "Don't create thumbnail gallery."
	HelpParameterFormat "h" "help" "Display this help then exit."
	HelpParameterFormat "v" "version " "Show script version then exit."
	HelpParameterFormat "q" "quiet" "Suppress display output. (non-functional in this version)"
	HelpParameterFormat "d" "debug" "Output debug info to file ($debug_file)."
	echo
	echo " - Example:"
	echo " $ ./$script_name -n $sample_images_required -p \"${sample_user_query_short}\""
	echo
	echo " This will download the first $sample_images_required available images for the search phrase \"${sample_user_query_short}\""
	echo

	}

function HelpParameterFormat
	{

	# $1 = short parameter
	# $2 = long parameter
	# $3 = description

	printf "  -%-1s --%-24s %s\n" "$1" "$2" "$3"

	}

function WhatAreMyOptions
	{

	# if getopt exited with an error then show help to user
	[ $user_parameters_result != 0 ] && echo && ShowHelp && return 2

	eval set -- "$user_parameters"

	# only need next line if a parameter MUST be specified on command-line
	[ $1 = "--" ] && ShowHelp && return 2

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

	if [ $? -gt 0 ] ; then
		echo " !! required program [$1] is unavailable ... unable to continue."
		echo
		[ "$debug" == true ] && AddToDebugFile "! required program is unavailable" "$1"
		ShowHelp
		return 1
	else
		[ "$debug" == true ] && AddToDebugFile "= required program is available" "$1"
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
	[ "$debug" == true ] && AddToDebugFile "? \$wget_list_cmd" "$wget_list_cmd"

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

	[ "$debug" == true ] && AddToDebugFile "> [${FUNCNAME[0]}]" "entry"

	local func_startseconds=$( date +%s )

	echo -n " -> searching Google for images matching the phrase \"$user_query\": "

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

	if [ $result -eq 0 ] ; then
		result_count=$( wc -l < "${imagelist_pathfile}" )

		if [ "$debug" == true ] ; then
			AddToDebugFile "= [${FUNCNAME[0]}]" "success!"
			AddToDebugFile "? \$result_count" "$result_count"
		fi

		echo "found ${result_count} results!"
	else
		[ "$debug" == true ] && AddToDebugFile "! [${FUNCNAME[0]}]" "failed! wget returned: ($result)"

		echo "failed!"
	fi

	if [ "$debug" == true ] ; then
		AddToDebugFile "T [${FUNCNAME[0]}] elapsed time" "$( ConvertSecs "$(($( date +%s )-$func_startseconds))")"
		AddToDebugFile "< [${FUNCNAME[0]}]" "exit"
	fi

	return $result

	}

function SingleImageDownloader
	{

	# This function runs as a background process
	# $1 = URL to download
	# $2 = current counter relative to main list

	IncrementFile "${process_tracker_pathfile}"

	[ "$debug" == true ] && AddToDebugFile "- download link # '$2'" "start"

	# extract file extension by checking only last 5 characters of URL (to handle .jpeg as worst case)
	ext=$( echo ${1:(-5)} | sed "s/.*\(\.[^\.]*\)$/\1/" )

	[[ "$ext" =~ "." ]] || ext=".jpg"	# if URL did not have a file extension then choose jpg as default

	targetimage_pathfileext="${targetimage_pathfile}($2)${ext}"

	local wget_download_cmd="wget --max-redirect 0 --timeout=${timeout} --tries=${retries} --quiet --output-document \"${targetimage_pathfileext}\" \"${imagelink}\""
	[ "$debug" == true ] && AddToDebugFile "? \$wget_download_cmd" "$wget_download_cmd"

	eval $wget_download_cmd > /dev/null 2>&1
	result=$?

	if [ $result -eq 0 ] ; then
		[ "$debug" == true ] && AddToDebugFile "= download link # '$2'" "success!"
		IncrementFile "${download_success_count_pathfile}"
	else
		# increment failures_count but keep trying to download images
		[ "$debug" == true ] && AddToDebugFile "! download link # '$2'" "failed! Wget returned: ($result - $( WgetReturnCodes "$result" ))"
		IncrementFile "${download_failures_count_pathfile}"

		# delete temp file if one was created
		[ -e "${targetimage_pathfileext}" ] && rm -f "${targetimage_pathfileext}"
	fi

	DecrementFile "${process_tracker_pathfile}"

	}

function DownloadImages
	{

	[ "$debug" == true ] && AddToDebugFile "> [${FUNCNAME[0]}]" "entry"

	local func_startseconds=$( date +%s )
	local result_index=0
	local file_index=1
	local strlength=0
	local message=""
	local child_count=0
	local countdown=$images_required		# control how many files are downloaded. Counts down to zero.
	failures_count=0
	result=0
	pids=""

	echo "${child_count}" > "${process_tracker_pathfile}"
	echo -n " -> downloading: "

	while read imagelink; do
		while true; do
			child_count=$(<"${process_tracker_pathfile}")

			[ "$child_count" -lt "$spawn_limit" ] && break

			sleep 0.5
		done

		if [ "$countdown" -gt 0 ] ; then
			ShowProgressMsg

			((result_index++))

			SingleImageDownloader "$msg" "$result_index" &
			pids[${result_index}]=$!		# record PID for checking later
			((countdown--))
			sleep 0.1				# allow spawned process time to update process accumulator file
		else
			# wait here while all running downloads finish
			for pid in ${pids[*]}; do
				wait $pid
			done

			# how many were successful?
			[ -e "${download_success_count_pathfile}" ] && success_count=$(<"${download_success_count_pathfile}") || success_count=0

			if [ "$success_count" -lt "$images_required" ] ; then
				# not enough yet, so go get some more
				# increase countdown again to get remaining files
				countdown=$(($images_required-$success_count))
			else
				break
			fi
		fi

# 			# increment failures_count but keep trying to download images

# 			((failures_count++))
# 			[ "$debug" == true ] && AddToDebugFile "> incremented \$failures_count" "$failures_count"

# 			if [ $failures_count -ge $failures_limit ] ; then
# 				result=1
# 				break
# 			fi

	done < "${imagelist_pathfile}"

# 	echo

	if [ "$debug" == true ] ; then
		AddToDebugFile "T [${FUNCNAME[0]}] elapsed time" "$( ConvertSecs "$(($( date +%s )-$func_startseconds))")"
		AddToDebugFile "< [${FUNCNAME[0]}]" "exit"
	fi

	ShowProgressMsg

	echo "all done!"

	return $result

	}

function BuildGallery
	{

	[ "$debug" == true ] && AddToDebugFile "> [${FUNCNAME[0]}]" "entry"

	local func_startseconds=$( date +%s )

	echo -n " -- building thumbnail gallery ... "

	gallery_cmd="montage \"${target_path}/*[0]\" -shadow -geometry 400x400 \"${target_path}/${gallery_name}-($user_query).png\""
	[ "$debug" == true ] && AddToDebugFile "? \$gallery_cmd" "$gallery_cmd"

	eval $gallery_cmd 2> /dev/null
	result=$?

	# note! montage will always return 1 at the moment coz the '.list' file cannot be opened by it. Gallery image still builds correctly.
	# So the following line is a workaround until I figure out how to get montage to ignore this file. :)
	result=0

	if [ $result -eq 0 ] ; then
		[ "$debug" == true ] && AddToDebugFile "= [${FUNCNAME[0]}]" "success!"
		echo "OK!"
	else
		[ "$debug" == true ] && AddToDebugFile "! [${FUNCNAME[0]}]" "failed! montage returned: ($result)"
		echo "failed!"
	fi

	if [ "$debug" == true ] ; then
		AddToDebugFile "T [${FUNCNAME[0]}] elapsed time" "$( ConvertSecs "$(($( date +%s )-$func_startseconds))")"
		AddToDebugFile "< [${FUNCNAME[0]}]" "exit"
	fi

	return $result

	}

function IncrementFile
	{

	# $1 = pathfile containing an integer to increment

	if [ -z "$1" ] ; then
		return 1
	else
		[ -e "$1" ] && count=$(<"$1") || count=0
		((count++))
		echo "$count" > "$1"
	fi

	}

function DecrementFile
	{

	# $1 = pathfile containing an integer to decrement

	if [ -z "$1" ] ; then
		return 1
	else
		[ -e "$1" ] && count=$(<"$1") || count=0
		((count--))
		echo "$count" > "$1"
	fi

	}

function ShowProgressMsg
	{

	printf %${strlength}s | tr ' ' '\b'

	RefreshSuccessFailure

	progress_message="(${success_count}/${images_required} images) "

	[ $failures_count -gt 0 ] && progress_message+="with (${failures_count}/$failures_limit failures) "

	echo -n "$progress_message"
	strlength=${#progress_message}

	}

function RefreshSuccessFailure
	{

	[ -e "${download_success_count_pathfile}" ] && success_count=$(<"${download_success_count_pathfile}") || success_count=0
	[ -e "${download_failures_count_pathfile}" ] && failures_count=$(<"${download_failures_count_pathfile}") || failures_count=0

	}

function AddToDebugFile
	{

	# $1 = item
	# $2 = value

	echo "$1: '$2'" >> "${debug_file}"

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
user_parameters=`getopt -o h,g,d,q,v,r:,t:,c:,f:,n:,p: --long help,no-gallery,debug,quiet,version,retries:,timeout:,concurrency:,failures:,number:,phrase: -n $( readlink -f -- "$0" ) -- "$@"`
user_parameters_result=$?

Init

# user parameter validation and bounds checks
if [ $exitcode -eq 0 ] ; then
	case ${images_required#[-+]} in
		*[!0-9]* )
			echo " !! number specified after (-n) must be a valid integer ... unable to continue."
			echo
			ShowHelp
			exitcode=2
			;;
		* )
			if [ $images_required -lt 1 ] ; then
				images_required=1
				[ "$debug" == true ] && AddToDebugFile "? \$images_required too small so set sensible minimum" "$images_required"
			fi

			if [ $images_required -gt $results_max ] ; then
				images_required=$results_max
				[ "$debug" == true ] && AddToDebugFile "? \$images_required too large so set as \$results_max" "$images_required"
			fi
			;;
	esac

	case ${failures_limit#[-+]} in
		*[!0-9]* )
			echo " !! number specified after (-l) must be a valid integer ... unable to continue."
			echo
			ShowHelp
			exitcode=2
			;;
		* )
			if [ $failures_limit -le 0 ] ; then
				failures_limit=$results_max
				[ "$debug" == true ] && AddToDebugFile "? \$failures_limit too small so set as \$results_max" "$failures_limit"
			fi

			if [ $failures_limit -gt $results_max ] ; then
				failures_limit=$results_max
				[ "$debug" == true ] && AddToDebugFile "? \$failures_limit too large so set as \$results_max" "$failures_limit"
			fi
			;;
	esac

	case ${spawn_limit#[-+]} in
		*[!0-9]* )
			echo " !! number specified after (-c) must be a valid integer ... unable to continue."
			echo
			ShowHelp
			exitcode=2
			;;
		* )
			if [ $spawn_limit -le 0 ] ; then
				spawn_limit=1
				[ "$debug" == true ] && AddToDebugFile "? \$spawn_limit too small so set as" "$spawn_limit"
			fi

			if [ $spawn_limit -gt $spawn_max ] ; then
				spawn_limit=$spawn_max
				[ "$debug" == true ] && AddToDebugFile "? \$spawn_limit too large so set as" "$spawn_limit"
			fi
			;;
	esac

	case ${timeout#[-+]} in
		*[!0-9]* )
			echo " !! number specified after (-t) must be a valid integer ... unable to continue."
			echo
			ShowHelp
			exitcode=2
			;;
		* )
			if [ $timeout -le 0 ] ; then
				timeout=1
				[ "$debug" == true ] && AddToDebugFile "? \$timeout too small so set as" "$timeout"
			fi

			if [ $timeout -gt $timeout_max ] ; then
				timeout=$timeout_max
				[ "$debug" == true ] && AddToDebugFile "? \$timeout too large so set as" "$timeout"
			fi
			;;
	esac

	case ${retries#[-+]} in
		*[!0-9]* )
			echo " !! number specified after (-r) must be a valid integer ... unable to continue."
			echo
			ShowHelp
			exitcode=2
			;;
		* )
			if [ $retries -le 0 ] ; then
				retries=1
				[ "$debug" == true ] && AddToDebugFile "? \$retries too small so set as" "$retries"
			fi

			if [ $retries -gt $retries_max ] ; then
				retries=$retries_max
				[ "$debug" == true ] && AddToDebugFile "? \$retries too large so set as" "$retries"
			fi
			;;
	esac

	if [ ! "$user_query" ] ; then
		echo " !! search phrase (-p) was unspecified ... unable to continue."
		echo
		ShowHelp
		exitcode=2
	fi
fi

# create directory for search phrase
if [ $exitcode -eq 0 ] ; then
	target_path="${current_path}/${user_query}"
	results_pathfile="${target_path}/${results_file}"
	imagelist_pathfile="${target_path}/${imagelinkslist_file}"
	targetimage_pathfile="${target_path}/${image_file}"

	echo " ${script_details}"
	echo

	mkdir -p "${target_path}"

	if [ $? -gt 0 ] ; then
		echo " !! couldn't create sub-directory [${target_path}] for phrase \"${user_query}\" ... unable to continue."
		exitcode=3
	fi
fi

# get list of search results
if [ $exitcode -eq 0 ] ; then
	DownloadList

	if [ $? -gt 0 ] ; then
		echo " !! couldn't download Google search results ... unable to continue."
		exitcode=4
	fi
fi

# download images and build gallery
if [ $exitcode -eq 0 ] ; then
	DownloadImages

	if [ $? -gt 0 ] ; then
		echo " !! failures_limit reached!"
		[ "$debug" == true ] && AddToDebugFile "! failures_limit reached" "$failures_limit"
		exitcode=5
	fi

	# build thumbnail gallery even if failures_limit was reached
	if [ "$create_gallery" == true ] ; then
		BuildGallery

		if [ $? -gt 0 ] ; then
			echo " !! couldn't build thumbnail gallery ... unable to continue (but we're all done anyway)."
			exitcode=6
		fi
	fi
fi

# write results into debug file
if [ "$debug" == true ] ; then
	AddToDebugFile "? image download \$failures_count" "$failures_count"
	AddToDebugFile "T [$script_name] elapsed time" "$( ConvertSecs "$(($( date +%s )-$script_startseconds))")"
	AddToDebugFile "< finished" "$( date )"
fi

exit $exitcode
