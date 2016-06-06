#/bin/bash

# Copyright (C) 2016 Teracow Software

# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

# If you find this code useful, please let me know. :) teracow@gmail.com

# return values:
#    $? = 0 - completed successfully.
#	= 1 - required program unavailable (wget, curl, perl, montage).
#	= 2 - required parameter unspecified or wrong - help shown or version requested.
#	= 3 - could not create subdirectory for 'search phrase'.
#	= 4 - could not get a list of search results from Google.
#	= 5 - image download aborted as failure limit was reached.
#	= 6 - thumbnail gallery build failed.

# The latest copy can be found here [https://github.com/teracow/bulk-google-image-download]

function Init
	{

	script_version="1.12"
	script_date="2016-06-05"
	script_name="$( basename -- "$( readlink -f -- "$0" )" )"
	script_details="${script_name} - v${script_version} (${script_date})"

	current_dir="$PWD"
	gallery_name="bulk-google-image-gallery"
	imagelinkslist_file="image-links.list"
	debug_file="bulk-download-debug.log"
	image_file="google-image"
	results_file="google-results-page.html"
	server="www.google.com.au"

	download_timeout=20
	download_retries=3
	exitcode=0
	results_max=400

	# user parameters
	user_query=""
	failures_max=10
	images_required=1
	create_gallery=true
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
		AddToDebugFile "? \$results_max" "$results_max"
		AddToDebugFile "? \$failures_max" "$failures_max"
		AddToDebugFile "? \$create_gallery" "$create_gallery"
	fi

	IsProgramAvailable "wget" || exitcode=1
	IsProgramAvailable "curl" || exitcode=1
	IsProgramAvailable "perl" || exitcode=1

	if [ "$create_gallery" == true ] ; then
		IsProgramAvailable "montage" || exitcode=1
	fi

	# 'nfpr=1' seems to perform exact string search - does not show most likely match results or suggested search.
	search_match_type="&nfpr=1"

	# 'tbm=isch' seems to search for images
	search_type="&tbm=isch"

	# 'q=' is the user supplied search query
	search_phrase="&q=$( echo $user_query | tr ' ' '+' )"	# replace whitepace with '+' to suit curl

	# 'hl=en' seems to be language
	search_language="&hl=en"

	# 'site=imghp' seems to be result layout style
	search_style="&site=imghp"

	}

function ShowHelp
	{

	local sample_images_required=12
	local sample_user_query="cows"
	local sample_long_user_query="small brown cows"

	echo " ${script_details}"
	echo
	echo " • a bulk image file downloader for 'Google Images' search results."
	echo
	echo " - Description: downloads the first [n]umber of images returned by Google for [phrase]. A gallery of these is then built using ImageMagick." | fold -s
	echo
	echo " - This is an expansion upon a solution provided by ShellFish on:"
	echo " [https://stackoverflow.com/questions/27909521/download-images-from-google-with-command-line]"
	echo
	echo " Requirements: wget, curl, Perl and ImageMagick."
	echo
	echo " Questions or comments? teracow@gmail.com"
	echo
	echo " Usage: ./$script_name [PARAMETERS]..."
	echo
	echo " Mandatory arguments to long options are mandatory for short options too."
	echo "  -n, --number=INTEGER (default $images_required)  Number of images to download. Maximum of $results_max."
	echo "  -p, --phrase=STRING (required)    Search phrase to look for. Enclose whitespace in quotes e.g. \"$sample_long_user_query\"."
	echo "  -l, --limit=INTEGER (default $failures_max)  Allow this many image download failures before exiting. 0 for unlimited ($results_max)."
	echo "  -g, --no-gallery                  Don't create thumbnail gallery. Default is to create a gallery."
	echo "  -h, --help                        Display this help then exit."
	echo "  -d, --debug                       Output debug info to file ($debug_file)."
	echo "  -v, --version                     Show script version then exit."
	echo
	echo " example:"
	echo " $ ./$script_name -n $sample_images_required -p \"${sample_user_query}\""
	echo
	echo " - This will download the first $sample_images_required available images for the search phrase \"${sample_user_query}\""
	echo

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
			-l | --limit )
				failures_max="$2"
				shift 2		# shift to next parameter in $1
				;;
			-p | --phrase )
				user_query="$2"
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
	local curl_list_cmd="curl --silent 'https://${server}/search?${search_type}${search_match_type}${search_phrase}${search_language}${search_style}${search_quarter}${search_start}' -H 'Connection: keep-alive' -H 'User-Agent: $useragent'"
	[ "$debug" == true ] && AddToDebugFile "? \$curl_list_cmd" "$curl_list_cmd"

	eval $curl_list_cmd >> "${results_pathfile}"

	}

function DownloadAllPageSegments
	{

	local total=4
	local pointer=0
	local percent=""
	local strlength=0

	for ((quarter=1; quarter<=$total; quarter++)) ; do
		pointer=$((($quarter-1)*100))

		# derived from: http://stackoverflow.com/questions/24284460/calculating-rounded-percentage-in-shell-script-without-using-bc
		percent="$((200*($quarter-1)/$total % 2 + 100*($quarter-1)/$total))% "

		printf %${strlength}s | tr ' ' '\b'
		echo -n "$percent"
		strlength=${#percent}

		DownloadSpecificPageSegment $(($quarter-1)) "$pointer"
	done

	printf %${strlength}s | tr ' ' '\b'	# clear last message

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
		[ "$debug" == true ] && AddToDebugFile "! [${FUNCNAME[0]}]" "failed! curl returned: ($result)"

		echo "failed!"
	fi

	if [ "$debug" == true ] ; then
		AddToDebugFile "T [${FUNCNAME[0]}] elapsed time" "$( ConvertSecs "$(($( date +%s )-$func_startseconds))")"
		AddToDebugFile "< [${FUNCNAME[0]}]" "exit"
	fi

	return $result

	}

function DownloadImages
	{

	[ "$debug" == true ] && AddToDebugFile "> [${FUNCNAME[0]}]" "entry"

	local func_startseconds=$( date +%s )
	local result_index=0
	local file_index=1
	local strlength=0
	local message=""
	downloads_count=0
	failures_count=0
	result=0

	echo -n " -> downloading: "

	while read imagelink; do
		((result_index++))

		printf %${strlength}s | tr ' ' '\b'

		progress_message="($(($downloads_count+1))/${images_required} images) "

		if [ $failures_count -gt 0 ] ; then
			progress_message+="with (${failures_count}/$failures_max failures) "
		fi

		echo -n "$progress_message"
		strlength=${#progress_message}

		# extract file extension
		ext=$( echo $imagelink | sed "s/.*\(\.[^\.]*\)$/\1/" )

		# increment file_index if file already exists
		while [[ -e "${targetimage_pathfile}(${file_index})${ext}" ]] ; do
			((file_index++))
		done
		targetimage_pathfileext="${targetimage_pathfile}(${file_index})${ext}"

		[ "$debug" == true ] && AddToDebugFile "? \$result_index" "$result_index"

		# build wget command string
		local wget_download_cmd="wget --max-redirect 0 --timeout=${download_timeout} --tries=${download_retries} --quiet --output-document \"${targetimage_pathfileext}\" \"${imagelink}\""
		[ "$debug" == true ] && AddToDebugFile "? \$wget_download_cmd" "$wget_download_cmd"

		eval $wget_download_cmd > /dev/null 2>&1
		result=$?

		if [ $result -eq 0 ] ; then
			((downloads_count++))
			[ "$debug" == true ] && AddToDebugFile "= \$result_index '$result_index'" "success!"
		else
			# increment failures_count but keep trying to download images
			[ "$debug" == true ] && AddToDebugFile "! \$result_index '$result_index'" "failed! Wget returned: ($result - $( WgetReturnCodes "$result" ))"

			# delete temp file if one was created
			[ -e "$targetimage_pathfileext" ] && rm -f "${targetimage_pathfileext}"

			((failures_count++))
			[ "$debug" == true ] && AddToDebugFile "> incremented \$failures_count" "$failures_count"

			if [ $failures_count -ge $failures_max ] ; then
				result=1
				break
			fi
		fi

		[ $downloads_count -eq $images_required ] && break

	done <"${imagelist_pathfile}"

	echo

	if [ "$debug" == true ] ; then
		AddToDebugFile "T [${FUNCNAME[0]}] elapsed time" "$( ConvertSecs "$(($( date +%s )-$func_startseconds))")"
		AddToDebugFile "< [${FUNCNAME[0]}]" "exit"
	fi

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
user_parameters=`getopt -o h,g,d,v,l:n:,p: --long help,no-gallery,debug,version,limit:,number:,phrase: -n $( readlink -f -- "$0" ) -- "$@"`
user_parameters_result=$?

Init

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

	case ${failures_max#[-+]} in
		*[!0-9]* )
			echo " !! number specified after (-l) must be a valid integer ... unable to continue."
			echo
			ShowHelp
			exitcode=2
			;;
		* )
			if [ $failures_max -le 0 ] ; then
				failures_max=$results_max
				[ "$debug" == true ] && AddToDebugFile "? \$failures_max too small so set as \$results_max" "$failures_max"
			fi

			if [ $failures_max -gt $results_max ] ; then
				failures_max=$results_max
				[ "$debug" == true ] && AddToDebugFile "? \$failures_max too large so set as \$results_max" "$failures_max"
			fi
			;;
	esac
fi

if [ $exitcode -eq 0 ] ; then
	if [ ! "$user_query" ] ; then
		echo " !! search phrase (-p) was unspecified ... unable to continue."
		echo
		ShowHelp
		exitcode=2
	fi
fi

if [ $exitcode -eq 0 ] ; then
	target_path="${current_dir}/${user_query}"
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

if [ $exitcode -eq 0 ] ; then
	DownloadList

	if [ $? -gt 0 ] ; then
		echo " !! couldn't download Google search results ... unable to continue."
		exitcode=4
	fi
fi

if [ $exitcode -eq 0 ] ; then
	DownloadImages

	if [ $? -gt 0 ] ; then
		echo " !! failures_max reached!"
		[ "$debug" == true ] && AddToDebugFile "! failures_max reached" "$failures_max"
		exitcode=5
	fi

	# build thumbnail gallery even if failures_max was reached
	if [ "$create_gallery" == true ] ; then
		BuildGallery

		if [ $? -gt 0 ] ; then
			echo " !! couldn't build thumbnail gallery ... unable to continue (but we're all done anyway)."
			exitcode=6
		fi
	fi
fi

if [ "$debug" == true ] ; then
	AddToDebugFile "? image download \$failures_count" "$failures_count"
	AddToDebugFile "T [$script_name] elapsed time" "$( ConvertSecs "$(($( date +%s )-$script_startseconds))")"
	AddToDebugFile "< finished" "$( date )"
fi

exit $exitcode
