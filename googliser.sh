#!/usr/bin/env bash

###############################################################################
# googliser.sh
#
# (C)opyright 2016-2019 Teracow Software
#
# If you find this script useful, please send me an email to let me know. :)
#   teracow@gmail.com
#
# The latest copy can be found here [https://github.com/teracow/googliser]
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.
###############################################################################

# return values ($?):
#   0   completed successfully
#   1   required/alternative program unavailable (wget, curl, montage, convert, identify, brew, etc...)
#   2   required parameter unspecified or wrong
#   3   could not create output directory for 'phrase'
#   4   could not get a list of search results from Google
#   5   image download aborted as failure limit was reached or ran out of images
#   6   thumbnail gallery build failed
#   7   unable to create a temporary build directory

# debug log first character notation:
#   >   child process spawned
#   <   child-process ended
#   \   function entry
#   /   function exit
#   ?   variable value
#   =   execution
#   ~   variable was reset within bounds
#   $   success
#   !   failure
#   T   elapsed time
#   #   comment

Init()
    {

    local SCRIPT_VERSION=190126
    SCRIPT_FILE=googliser.sh

    # parameter defaults
    IMAGES_REQUIRED_DEFAULT=25
    PARALLEL_LIMIT_DEFAULT=10
    FAIL_LIMIT_DEFAULT=40
    UPPER_SIZE_LIMIT_DEFAULT=0
    LOWER_SIZE_LIMIT_DEFAULT=1000
    TIMEOUT_DEFAULT=8
    RETRIES_DEFAULT=3
    max_results_required=$IMAGES_REQUIRED_DEFAULT
    fail_limit=$FAIL_LIMIT_DEFAULT
    BORDER_THICKNESS_DEFAULT=30
    RECENT_DEFAULT=any

    # parameter limits
    GOOGLE_MAX=1000
    PARALLEL_MAX=40
    TIMEOUT_MAX=600
    RETRIES_MAX=100

    # internals
    local script_starttime=$(date)
    script_startseconds=$(date +%s)
    target_path_created=false
    show_help_only=false
    exitcode=0
    local SCRIPT_VERSION_PID="v:$SCRIPT_VERSION PID:$$"
    script_details_colour="$(ColourBackgroundBlack "$(ColourTextBrightWhite " $SCRIPT_FILE ")") $SCRIPT_VERSION_PID"
    script_details_plain="$SCRIPT_FILE $SCRIPT_VERSION_PID"
    USERAGENT='--user-agent "Mozilla/5.0 (X11; Linux x86_64; rv:64.0) Gecko/20100101 Firefox/64.0"'

    # user-changeable parameters
    user_query=''
    images_required=$IMAGES_REQUIRED_DEFAULT
    user_fail_limit=$fail_limit
    parallel_limit=$PARALLEL_LIMIT_DEFAULT
    timeout=$TIMEOUT_DEFAULT
    retries=$RETRIES_DEFAULT
    upper_size_limit=$UPPER_SIZE_LIMIT_DEFAULT
    lower_size_limit=$LOWER_SIZE_LIMIT_DEFAULT
    recent=$RECENT_DEFAULT
    create_gallery=true
    gallery_title=''
    condensed_gallery=false
    save_links=false
    colour=false
    verbose=true
    debug=false
    skip_no_size=false
    remove_after=false
    lightning=false
    min_pixels=''
    aspect_ratio=''
    usage_rights=''
    image_type=''
    input_pathfile=''
    output_path=''
    links_only=false
    dimensions=''
    border_thickness=$BORDER_THICKNESS_DEFAULT

    FindPackageManager
    BuildWorkPaths

    DebugScriptEntry
    DebugScriptVar SCRIPT_VERSION
    DebugScriptVal 'PID' "$$"
    DebugScriptNow

    }

FindPackageManager()
    {

    case "$OSTYPE" in
        "darwin"*)
            PACKAGER_BIN=$(which brew)
            ;;
        "linux"*)
            if ! PACKAGER_BIN=$(which apt); then
                if ! PACKAGER_BIN=$(which yum); then
                    if ! PACKAGER_BIN=$(which opkg); then
                        PACKAGER_BIN=''
                    fi
                fi
            fi
            ;;
    esac

    [[ -z $PACKAGER_BIN ]] && PACKAGER_BIN=unknown

    }

BuildWorkPaths()
    {

    Flee()
        {

        echo "! Unable to create a temporary build directory! Exiting."; exit 7

        }

    image_file_prefix=google-image
    test_file=test-image          # this is used during size testing
    imagelinks_file=download.links.list
    debug_file=debug.log
    gallery_name=googliser-gallery
    current_path="$PWD"

    TEMP_PATH=$(mktemp -d "/tmp/${SCRIPT_FILE%.*}.$$.XXX") || Flee

    results_run_count_path="$TEMP_PATH/results.running.count"
    mkdir -p "$results_run_count_path" || Flee

    results_success_count_path="$TEMP_PATH/results.success.count"
    mkdir -p "$results_success_count_path" || Flee

    results_fail_count_path="$TEMP_PATH/results.fail.count"
    mkdir -p "$results_fail_count_path" || Flee

    download_run_count_path="$TEMP_PATH/download.running.count"
    mkdir -p "$download_run_count_path" || Flee

    download_success_count_path="$TEMP_PATH/download.success.count"
    mkdir -p "$download_success_count_path" || Flee

    download_fail_count_path="$TEMP_PATH/download.fail.count"
    mkdir -p "$download_fail_count_path" || Flee

    testimage_pathfile="$TEMP_PATH/$test_file"
    searchresults_pathfile="$TEMP_PATH/search.results.page.html"
    gallery_title_pathfile="$TEMP_PATH/gallery.title.png"
    gallery_thumbnails_pathfile="$TEMP_PATH/gallery.thumbnails.png"
    gallery_background_pathfile="$TEMP_PATH/gallery.background.png"
    imagelinks_pathfile="$TEMP_PATH/$imagelinks_file"
    debug_pathfile="$TEMP_PATH/$debug_file"

    unset -f Flee

    }

ProcEnvironment()
    {

    DebugFuncEntry

    WhatAreMyOptions

    if [[ $verbose = true ]]; then
        if [[ $colour = true ]]; then
            echo " $script_details_colour"
        else
            echo " $script_details_plain"
        fi
    fi

    if [[ $show_help_only = true ]]; then
        DisplayHelp
        return 1
    else
        ValidateParameters
    fi

    DebugScriptComment 'runtime parameters after validation and adjustment'
    DebugScriptVar images_required
    DebugScriptVar user_fail_limit
    DebugScriptVar max_results_required
    DebugScriptVar parallel_limit
    DebugScriptVal '$timeout (seconds)' "$timeout"
    DebugScriptVar retries
    DebugScriptVal '$upper_size_limit (bytes)' "$upper_size_limit"
    DebugScriptVal '$lower_size_limit (bytes)' "$lower_size_limit"
    DebugScriptVar recent
    DebugScriptVar create_gallery
    DebugScriptVar condensed_gallery
    DebugScriptVar save_links
    DebugScriptVar colour
    DebugScriptVar verbose
    DebugScriptVar debug
    DebugScriptVar skip_no_size
    DebugScriptVar remove_after
    DebugScriptVar lightning
    DebugScriptVar min_pixels
    DebugScriptVar aspect_ratio
    DebugScriptVar image_type
    DebugScriptVar usage_rights
    DebugScriptVar input_pathfile
    DebugScriptVar output_path
    DebugScriptVar links_only
    #DebugScriptVar dimensions
    DebugScriptVal '$border_thickness (pixels)' "$border_thickness"
    DebugScriptComment 'internal parameters'
    DebugScriptVar OSTYPE
    DebugScriptVal '$GOOGLE_MAX (number of images)' "$GOOGLE_MAX"
    DebugScriptVar PACKAGER_BIN
    DebugScriptVar TEMP_PATH

    if ! DOWNLOADER_BIN=$(which wget); then
        if ! DOWNLOADER_BIN=$(which curl); then
            SuggestInstall wget
            exitcode=1
            return 1
        fi
    fi

    DebugScriptVar DOWNLOADER_BIN

    if [[ $create_gallery = true && $show_help_only = false ]]; then
        if ! MONTAGE_BIN=$(which montage); then
            SuggestInstall montage imagemagick
            exitcode=1
            return 1
        elif ! CONVERT_BIN=$(which convert); then
            SuggestInstall convert imagemagick
            exitcode=1
            return 1
        fi
    fi

    DebugScriptVar MONTAGE_BIN
    DebugScriptVar CONVERT_BIN

    ! IDENTIFY_BIN=$(which identify) && DebugThis "! no recognised 'identify' binary found"

    DebugScriptVar IDENTIFY_BIN

    trap CTRL_C_Captured INT

    DebugFuncExit

    return 0

    }

WhatAreMyOptions()
    {

    DebugScriptVar user_parameters_raw

    [[ $user_parameters_result -ne 0 ]] && { echo; exitcode=2; return 1 ;}
    [[ $user_parameters = ' --' ]] && { show_help_only=true; exitcode=2; return 1 ;}

    eval set -- "$user_parameters"

    while true; do
        case "$1" in
            -n|--number)
                images_required="$2"
                shift 2
                ;;
            -f|--failures)
                user_fail_limit="$2"
                shift 2
                ;;
            -p|--phrase)
                user_query="$2"
                shift 2
                ;;
            -P|--parallel)
                parallel_limit="$2"
                shift 2
                ;;
            -t|--timeout)
                timeout="$2"
                shift 2
                ;;
            -r|--retries)
                retries="$2"
                shift 2
                ;;
            -u|--upper-size)
                upper_size_limit="$2"
                shift 2
                ;;
            -l|--lower-size)
                lower_size_limit="$2"
                shift 2
                ;;
            -T|--title)
                if [[ $(Lowercase "$2") = false ]]; then
                    gallery_title="_false_"
                else
                    gallery_title="$2"
                fi
                shift 2
                ;;
            -o|--output)
                output_path="$2"
                shift 2
                ;;
            -i|--input)
                input_pathfile="$2"
                shift 2
                ;;
            #--dimensions)
            #   dimensions="$2"
            #   shift 2
            #   ;;
            -S|--skip-no-size)
                skip_no_size=true
                shift
                ;;
            -s|--save-links)
                save_links=true
                shift
                ;;
            -D|--delete-after)
                remove_after=true
                shift
                ;;
            -z|--lightning)
                lightning=true
                shift
                ;;
            -h|--help)
                show_help_only=true
                exitcode=2
                return 1
                ;;
            -c|--colour)
                colour=true
                shift
                ;;
            -N|--no-gallery)
                create_gallery=false
                shift
                ;;
            -C|--condensed)
                condensed_gallery=true
                shift
                ;;
            -q|--quiet)
                verbose=false
                shift
                ;;
            -d|--debug)
                debug=true
                shift
                ;;
            -L|--links-only)
                links_only=true
                shift
                ;;
            -m|--minimum-pixels)
                min_pixels="$2"
                shift 2
                ;;
            -a|--aspect-ratio)
                aspect_ratio="$2"
                shift 2
                ;;
            -b|--border-thickness)
                border_thickness="$2"
                shift 2
                ;;
            -R|--recent)
                recent="$2"
                shift 2
                ;;
            --type)
                image_type="$2"
                shift 2
                ;;
            --usage-rights)
                usage_rights="$2"
                shift 2
                ;;
            --)
                shift       # shift to next parameter in $1
                break
                ;;
            *)
                break       # there are no more matching parameters
                ;;
        esac
    done

    return 0

    }

DisplayHelp()
    {

    DebugThis "\ [${FUNCNAME[0]}]" 'entry'

    local SAMPLE_USER_QUERY=cows

    echo
    if [[ $colour = true ]]; then
        echo " Usage: $(ColourTextBrightWhite "./$SCRIPT_FILE") [PARAMETERS] ..."
        message="$(ShowGoogle) $(ColourTextBrightBlue "images")"
    else
        echo " Usage: ./$SCRIPT_FILE [PARAMETERS] ..."
        message='Google images'
    fi

    echo
    echo " search '$message', download from each of the image URLs, then create a gallery image using ImageMagick."
    echo
    echo " External requirements: Wget or cURL"
    echo " and optionally: identify, montage & convert (from ImageMagick)"
    echo
    echo " Questions or comments? teracow@gmail.com"
    echo
    echo " Mandatory arguments for long options are mandatory for short options too. Defaults values are shown as [n]."
    echo

    if [[ $colour = true ]]; then
        echo " $(ColourTextBrightOrange "* Required *")"
    else
        echo " * Required *"
    fi

    FormatHelpLine "p" "phrase" "Phrase to search for. Enclose whitespace in quotes. A sub-directory is created with this name unless '--output' is specified."
    echo
    echo " Optional"
    FormatHelpLine a aspect-ratio "Image aspect ratio. Specify like '-a square'. Presets are:"
    FormatHelpLine '' '' "'tall'"
    FormatHelpLine '' '' "'square'"
    FormatHelpLine '' '' "'wide'"
    FormatHelpLine '' '' "'panoramic'"
    FormatHelpLine b border-thickness "Thickness of border surrounding gallery image in pixels [$BORDER_THICKNESS_DEFAULT]. Use '0' for no border."
    FormatHelpLine c colour "Display with ANSI coloured text."
    FormatHelpLine C condensed "Create a condensed thumbnail gallery. All square images with no tile padding."
    FormatHelpLine d debug "Save the debug file [$debug_file] into the output directory."
    #FormatHelpLine d dimensions "Specify exact image dimensions to download."
    FormatHelpLine D delete-after "Remove all downloaded images afterwards."
    FormatHelpLine f failures "Total number of download failures allowed before aborting [$FAIL_LIMIT_DEFAULT]. Use '0' for unlimited ($GOOGLE_MAX)."
    FormatHelpLine h help "Display this help then exit."
    FormatHelpLine i input "A text file containing a list of phrases to download. One phrase per line."
    FormatHelpLine l lower-size "Only download images that are larger than this many bytes [$LOWER_SIZE_LIMIT_DEFAULT]."
    FormatHelpLine L links-only "Only get image file URLs. Don't download any images."
    FormatHelpLine m minimum-pixels "Images must contain at least this many pixels. Specify like '-m 8mp'. Presets are:"
    FormatHelpLine '' '' "'qsvga' (400 x 300)"
    FormatHelpLine '' '' "'vga'   (640 x 480)"
    FormatHelpLine '' '' "'svga'  (800 x 600)"
    FormatHelpLine '' '' "'xga'   (1024 x 768)"
    FormatHelpLine '' '' "'2mp'   (1600 x 1200)"
    FormatHelpLine '' '' "'4mp'   (2272 x 1704)"
    FormatHelpLine '' '' "'6mp'   (2816 x 2112)"
    FormatHelpLine '' '' "'8mp'   (3264 x 2448)"
    FormatHelpLine '' '' "'10mp'  (3648 x 2736)"
    FormatHelpLine '' '' "'12mp'  (4096 x 3072)"
    FormatHelpLine '' '' "'15mp'  (4480 x 3360)"
    FormatHelpLine '' '' "'20mp'  (5120 x 3840)"
    FormatHelpLine '' '' "'40mp'  (7216 x 5412)"
    FormatHelpLine '' '' "'70mp'  (9600 x 7200)"
    FormatHelpLine '' '' "'large'"
    FormatHelpLine '' '' "'medium'"
    FormatHelpLine '' '' "'icon'"
    FormatHelpLine n number "Number of images to download [$IMAGES_REQUIRED_DEFAULT]. Maximum of $GOOGLE_MAX."
    FormatHelpLine N no-gallery "Don't create thumbnail gallery."
    FormatHelpLine o output "The image output directory [phrase]."
    FormatHelpLine P parallel "How many parallel image downloads? [$PARALLEL_LIMIT_DEFAULT]. Maximum of $PARALLEL_MAX. Use wisely!"
    FormatHelpLine q quiet "Suppress standard output. Errors are still shown."
    FormatHelpLine r retries "Retry image download this many times [$RETRIES_DEFAULT]. Maximum of $RETRIES_MAX."
    FormatHelpLine R recent "Only get images published this far back in time [$RECENT_DEFAULT]. Specify like '--recent month'. Presets are:"
    FormatHelpLine '' '' "'any'"
    FormatHelpLine '' '' "'hour'"
    FormatHelpLine '' '' "'day'"
    FormatHelpLine '' '' "'week'"
    FormatHelpLine '' '' "'month'"
    FormatHelpLine '' '' "'year'"
    FormatHelpLine s save-links "Save URL list to file [$imagelinks_file] into the output directory."
    FormatHelpLine S skip-no-size "Don't download any image if its size cannot be determined."
    FormatHelpLine t timeout "Number of seconds before aborting each image download [$TIMEOUT_DEFAULT]. Maximum of $TIMEOUT_MAX."
    FormatHelpLine T title "Title for thumbnail gallery image [phrase]. Enclose whitespace in quotes. Use 'false' for no title."
    FormatHelpLine '' type "Image type. Specify like '--type clipart'. Presets are:"
    FormatHelpLine '' '' "'face'"
    FormatHelpLine '' '' "'photo'"
    FormatHelpLine '' '' "'clipart'"
    FormatHelpLine '' '' "'lineart'"
    FormatHelpLine '' '' "'animated'"
    FormatHelpLine u upper-size "Only download images that are smaller than this many bytes [$UPPER_SIZE_LIMIT_DEFAULT]. Use '0' for unlimited."
    #FormatHelpLine '?' random "Download a single random image only"
    FormatHelpLine '' usage-rights "Usage rights. Specify like '--usage-rights reuse'. Presets are:"
    FormatHelpLine '' '' "'reuse'"
    FormatHelpLine '' '' "'reuse-with-mod'"
    FormatHelpLine '' '' "'noncomm-reuse'"
    FormatHelpLine '' '' "'noncomm-reuse-with-mod'"
    FormatHelpLine z lightning "Download images even faster by using an optimized set of parameters. For those who really can't wait!"
    echo
    echo " Example:"

    if [[ $colour = true ]]; then
        echo "$(ColourTextBrightWhite " $ ./$SCRIPT_FILE -p '$SAMPLE_USER_QUERY'")"
    else
        echo " $ ./$SCRIPT_FILE -p '$SAMPLE_USER_QUERY'"
    fi

    echo
    echo " This will download the first $IMAGES_REQUIRED_DEFAULT available images for the phrase '$SAMPLE_USER_QUERY' and build them into a gallery image."

    DebugThis "/ [${FUNCNAME[0]}]" 'exit'

    }

ValidateParameters()
    {

    DebugFuncEntry

    if [[ $create_gallery = false && $remove_after = true && $links_only = false ]]; then
        echo
        echo " Hmmm, so you've requested:"
        echo " 1. don't create a gallery,"
        echo " 2. delete the images after downloading,"
        echo " 3. don't save the links file."
        echo " Might be time to (R)ead-(T)he-(M)anual. ;)"
        exitcode=2
        return 1
    fi

    if [[ $lightning = true ]]; then
        # Yeah!
        timeout=1
        retries=0
        skip_no_size=true
        parallel_limit=16
        links_only=false
        create_gallery=false
        user_fail_limit=0
    fi

    if [[ $links_only = true ]]; then
        create_gallery=false
        save_links=true
        user_fail_limit=0
    fi

    if [[ $condensed_gallery = true ]]; then
        create_gallery=true
    fi

    case ${images_required#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $images_required' 'invalid'
            echo
            echo "$(ShowAsFailed " !! number specified after (-n, --number) must be a valid integer")"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $images_required -lt 1 ]]; then
                images_required=1
                DebugFuncVarAdjustment '$images_required TOO LOW so set to a sensible minimum' "$images_required"
            fi

            if [[ $images_required -gt $GOOGLE_MAX ]]; then
                images_required=$GOOGLE_MAX
                DebugThis '~ $images_required TOO HIGH so set as $GOOGLE_MAX' "$images_required"
            fi
            ;;
    esac

    if [[ -n $input_pathfile ]]; then
        if [[ ! -e $input_pathfile ]]; then
            DebugThis '! $input_pathfile' 'not found'
            echo
            echo "$(ShowAsFailed ' !! input file  (-i, --input) was not found')"
            exitcode=2
            return 1
        fi
    fi

    case ${user_fail_limit#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $user_fail_limit' 'invalid'
            echo
            echo "$(ShowAsFailed ' !! number specified after (-f, --failures) must be a valid integer')"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $user_fail_limit -le 0 ]]; then
                user_fail_limit=$GOOGLE_MAX
                DebugThis '~ $user_fail_limit TOO LOW so set as $GOOGLE_MAX' "$user_fail_limit"
            fi

            if [[ $user_fail_limit -gt $GOOGLE_MAX ]]; then
                user_fail_limit=$GOOGLE_MAX
                DebugThis '~ $user_fail_limit TOO HIGH so set as $GOOGLE_MAX' "$user_fail_limit"
            fi
            ;;
    esac

    case ${parallel_limit#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $parallel_limit' 'invalid'
            echo
            echo "$(ShowAsFailed ' !! number specified after (-P, --parallel) must be a valid integer')"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $parallel_limit -lt 1 ]]; then
                parallel_limit=1
                DebugThis '~ $parallel_limit TOO LOW so set as' "$parallel_limit"
            fi

            if [[ $parallel_limit -gt $PARALLEL_MAX ]]; then
                parallel_limit=$PARALLEL_MAX
                DebugThis '~ $parallel_limit TOO HIGH so set as' "$parallel_limit"
            fi
            ;;
    esac

    case ${timeout#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $timeout' 'invalid'
            echo
            echo "$(ShowAsFailed ' !! number specified after (-t, --timeout) must be a valid integer')"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $timeout -lt 1 ]]; then
                timeout=1
                DebugThis '~ $timeout TOO LOW so set as' "$timeout"
            fi

            if [[ $timeout -gt $TIMEOUT_MAX ]]; then
                timeout=$TIMEOUT_MAX
                DebugThis '~ $timeout TOO HIGH so set as' "$timeout"
            fi
            ;;
    esac

    case ${retries#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $retries' 'invalid'
            echo
            echo "$(ShowAsFailed ' !! number specified after (-r, --retries) must be a valid integer')"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $retries -lt 0 ]]; then
                retries=0
                DebugThis '~ $retries TOO LOW so set as' "$retries"
            fi

            if [[ $retries -gt $RETRIES_MAX ]]; then
                retries=$RETRIES_MAX
                DebugThis '~ $retries TOO HIGH so set as' "$retries"
            fi
            ;;
    esac

    case ${upper_size_limit#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $upper_size_limit' 'invalid'
            echo
            echo "$(ShowAsFailed ' !! number specified after (-u, --upper-size) must be a valid integer')"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $upper_size_limit -lt 0 ]]; then
                upper_size_limit=0
                DebugThis '~ $upper_size_limit TOO LOW so set as' "$upper_size_limit (unlimited)"
            fi
            ;;
    esac

    case ${lower_size_limit#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $lower_size_limit' 'invalid'
            echo
            echo "$(ShowAsFailed ' !! number specified after (-l, --lower-size) must be a valid integer')"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $lower_size_limit -lt 0 ]]; then
                lower_size_limit=0
                DebugThis '~ $lower_size_limit TOO LOW so set as' "$lower_size_limit"
            fi

            if [[ $upper_size_limit -gt 0 && $lower_size_limit -gt $upper_size_limit ]]; then
                lower_size_limit=$((upper_size_limit-1))
                DebugThis "~ \$lower_size_limit larger than \$upper_size_limit ($upper_size_limit) so set as" "$lower_size_limit"
            fi
            ;;
    esac

    case ${border_thickness#[-+]} in
        *[!0-9]*)
            DebugThis '! specified $border_thickness' 'invalid'
            echo
            echo "$(ShowAsFailed ' !! number specified after (-b, --border-thickness) must be a valid integer')"
            exitcode=2
            return 1
            ;;
        *)
            if [[ $border_thickness -lt 0 ]]; then
                border_thickness=0
                DebugThis '~ $border_thickness TOO LOW so set as' "$border_thickness"
            fi
            ;;
    esac

    if [[ $max_results_required -lt $((images_required+user_fail_limit)) ]]; then
        max_results_required=$((images_required+user_fail_limit))
        DebugFuncVarAdjustment '$max_results_required TOO LOW so set as $images_required + $user_fail_limit' "$max_results_required"
    fi

    dimensions_search=''
    if [[ -n $dimensions ]]; then
        # parse dimensions strings like '1920x1080' or '1920' or 'x1080'
        echo "dimensions: [$dimensions]"

        if grep -q 'x' <<< $dimensions; then
            echo "found a separator"
            image_width=${dimensions%x*}
            image_height=${dimensions#*x}
        else
            image_width=$dimensions
        fi

        [[ $image_width =~ ^-?[0-9]+$ ]] && echo "image_width is a number" || echo "image_width is NOT a number"
        [[ $image_height =~ ^-?[0-9]+$ ]] && echo "image_height is a number" || echo "image_height is NOT a number"

        echo "image_width: [$image_width]"
        echo "image_height: [$image_height]"
        echo "dimensions_search: [$dimensions_search]"

        # only while debugging - remove for release
        exitcode=2
        return 1
    fi

    if [[ -n $dimensions && -n $min_pixels ]]; then
        min_pixels=''
        DebugThis '~ $dimensions was specified so cleared $min_pixels'
    fi

    min_pixels_search=''
    if [[ -n $min_pixels ]]; then
        case "$min_pixels" in
            qsvga|vga|svga|xga|2mp|4mp|6mp|8mp|10mp|12mp|15mp|20mp|40mp|70mp)
                min_pixels_search="isz:lt,islt:$min_pixels"
                ;;
            large)
                min_pixels_search='isz:l'
                ;;
            medium)
                min_pixels_search='isz:m'
                ;;
            icon)
                min_pixels_search='isz:i'
                ;;
            *)
                echo
                echo "$(ShowAsFailed ' !! (-m, --minimum-pixels) preset invalid')"
                exitcode=2
                return 1
                ;;
        esac
    fi

    aspect_ratio_search=''
    if [[ -n $aspect_ratio ]]; then
        case "$aspect_ratio" in
            tall)
                ar_type='t'
                ;;
            square)
                ar_type='s'
                ;;
            wide)
                ar_type='w'
                ;;
            panoramic)
                ar_type='xw'
                ;;
            *)
                echo
                echo "$(ShowAsFailed ' !! (-a, --aspect-ratio) preset invalid')"
                exitcode=2
                return 1
                ;;
        esac
        [[ -n $ar_type ]] && aspect_ratio_search="iar:$ar_type"
    fi

    image_type_search=''
    if [[ -n $image_type ]]; then
        case "$image_type" in
            face|photo|clipart|lineart|animated)
                image_type_search="itp:$image_type"
                ;;
            *)
                echo
                echo "$(ShowAsFailed ' !! (--type) preset invalid')"
                exitcode=2
                return 1
                ;;
        esac
    fi

    usage_rights_search=''
    if [[ -n $usage_rights ]]; then
        case "$usage_rights" in
            reuse-with-mod)
                usage_rights_search='sur:fmc'
                ;;
            reuse)
                usage_rights_search='sur:fc'
                ;;
            noncomm-reuse-with-mod)
                usage_rights_search='sur:fm'
                ;;
            noncomm-reuse)
                usage_rights_search='sur:f'
                ;;
            *)
                echo
                echo "$(ShowAsFailed ' !! (--usage-rights) preset invalid')"
                exitcode=2
                return 1
                ;;
        esac
    fi

    if [[ -n $recent ]]; then
        case "$recent" in
            any)
                recent_search=''
                ;;
            hour)
                recent_search='qdr:h'
                ;;
            day)
                recent_search='qdr:d'
                ;;
            week)
                recent_search='qdr:w'
                ;;
            month)
                recent_search='qdr:m'
                ;;
            year)
                recent_search='qdr:y'
                ;;
            *)
                echo
                echo "$(ShowAsFailed ' !! (--recent) preset invalid')"
                exitcode=2
                return 1
                ;;
        esac
    fi

    if [[ -n $min_pixels_search || -n $aspect_ratio_search || -n $image_type_search || -n $usage_rights_search || -n $recent_search ]]; then
        advanced_search="&tbs=$min_pixels_search,$aspect_ratio_search,$image_type_search,$usage_rights_search,$recent_search"
    fi

    DebugFuncExit

    return 0

    }

ProcSingleQuery()
    {

    DebugFuncEntry

    echo
    DebugFuncComment 'user query parameters'

    # some last-minute parameter validation - needed when reading phrases from text file
    if [[ -z $user_query ]]; then
        DebugFuncFailure '$user_query' 'unspecified'
        echo "$(ShowAsFailed ' !! search phrase (-p, --phrase) was unspecified')"
        exitcode=2
        return 1
    fi

    echo " -> processing query: \"$user_query\""
    local safe_search_phrase="${user_query// /+}"       # replace whitepace with '+' to suit curl/wget
    DebugFuncVar safe_search_phrase
    safe_path_phrase="${user_query// /_}"               # replace whitepace with '_' so less issues later on!
    safe_search_query="&q=$safe_search_phrase"

    if [[ -z $output_path ]]; then
        target_path="$current_path/$safe_path_phrase"
    else
        safe_path="${output_path// /_}"                 # replace whitepace with '_' so less issues later on!
        DebugFuncVar safe_path
        if [[ -n $input_pathfile ]]; then
            target_path="$safe_path/$safe_path_phrase"
        else
            target_path="$safe_path"
        fi
    fi

    DebugFuncVar target_path

    if [[ $exitcode -eq 0 && -z $gallery_title ]]; then
        gallery_title="$user_query"
        DebugFuncVarAdjustment 'gallery title unspecified so set as' "'$gallery_title'"
    fi

    # create directory for search phrase
    if [[ -e $target_path ]]; then
        DebugFuncSuccess "target path already exists $target_path"
    else
        mkdir -p "$target_path"
        result=$?
        if [[ $result -gt 0 ]]; then
            DebugFuncFailure "create target path" "failed! mkdir returned: ($result)"
            echo
            echo "$(ShowAsFailed " !! couldn't create target path [$target_path]")"
            exitcode=3
            return 1
        else
            DebugFuncSuccess 'create target path'
            target_path_created=true
        fi
    fi

    # download search results pages
    DownloadResultGroups
    if [[ $? -gt 0 ]]; then
        echo "$(ShowAsFailed " !! couldn't download Google search results")"
        exitcode=4
        return 1
    else
        fail_limit=$user_fail_limit
        if [[ $fail_limit -gt $result_count ]]; then
            fail_limit=$result_count
            DebugFuncVarAdjustment '$fail_limit TOO HIGH so set as $result_count' "$fail_limit"
        fi

        if [[ $images_required -gt $result_count ]]; then
            images_required=$result_count
            DebugFuncVarAdjustment '$images_required TOO HIGH so set as $result_count' "$result_count"
        fi
    fi

    if [[ $result_count -eq 0 ]]; then
        DebugLinkVal 'zero results returned?' 'Oops...'
        exitcode=4
        return 1
    fi

    # download images
    if [[ $exitcode -eq 0 ]]; then
        if [[ $links_only = false ]]; then
            DownloadImages
            [[ $? -gt 0 ]] && exitcode=5
        fi
    fi

    # build thumbnail gallery even if fail_limit was reached
    if [[ $exitcode -eq 0 || $exitcode -eq 5 ]]; then
        if [[ $create_gallery = true ]]; then
            BuildGallery
            if [[ $? -gt 0 ]]; then
                echo
                echo "$(ShowAsFailed ' !! unable to build thumbnail gallery')"
                exitcode=6
            else
                if [[ $remove_after = true ]]; then
                    rm -f "$target_path/$image_file_prefix"*
                    DebugFuncVal 'remove all downloaded images from' "$target_path"
                fi
            fi
        fi
    fi

    # copy links file into target directory if possible. If not, then copy to current directory.
    if [[ $exitcode -eq 0 || $exitcode -eq 5 ]]; then
        if [[ $save_links = true ]]; then
            if [[ $target_path_created = true ]]; then
                cp -f "$imagelinks_pathfile" "$target_path/$imagelinks_file"
            else
                cp -f "$imagelinks_pathfile" "$current_path/$imagelinks_file"
            fi
        fi
    fi

    DebugFuncExit

    return 0

    }

DownloadResultGroups()
    {

    DebugFuncEntry

    local func_startseconds=$(date +%s)
    local groups_max=$((GOOGLE_MAX/100))
    local pointer=0
    local parallel_count=0
    local success_count=0
    local fail_count=0

    InitProgress
    InitResultsCounts

    if [[ $verbose = true ]]; then
        if [[ $colour = true ]]; then
            echo -n " -> searching $(ShowGoogle): "
        else
            echo -n " -> searching Google: "
        fi
    fi

    for ((group=1; group<=$groups_max; group++)); do
        # wait here until a download slot becomes available
        while [[ $parallel_count -eq $parallel_limit ]]; do
            sleep 0.5

            RefreshResultsCounts
            ShowResultDownloadProgress
        done

        group_index=$(printf "%02d" $group)

        # create run file here as it takes too long to happen in background function
        touch "$results_run_count_path/$group_index"
        { DownloadResultGroup_auto "$group" "$group_index" & } 2>/dev/null

        RefreshResultsCounts
        ShowResultDownloadProgress

        [[ $((group*100)) -gt $max_results_required ]] && break
    done

    # wait here while all running downloads finish
    wait 2>/dev/null

    RefreshResultsCounts
    ShowResultDownloadProgress

    # build all groups into a single file
    cat ${searchresults_pathfile}.* > "$searchresults_pathfile"

    ParseResults

    [[ $fail_count -gt 0 ]] && result=1 || result=0

    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return $result

    }

DownloadResultGroup_auto()
    {

    # *** This function runs as a background process ***
    # $1 = page group to load           e.g. 0, 1, 2, 3, etc...
    # $2 = debug index identifier       e.g. (02)

    local page_group="$1"
    local group_index="$2"
    local response=''
    local result=0

    local run_pathfile="$results_run_count_path/$group_index"
    local success_pathfile="$results_success_count_path/$group_index"
    local fail_pathfile="$results_fail_count_path/$group_index"

    DebugSearchChildSpawned "$group_index"

    response=$(Downloader_GetResults "$page_group" "$group_index")
    result=$?

    if [[ $result -eq 0 ]]; then
        mv "$run_pathfile" "$success_pathfile"
        DebugSearchSuccess "$group_index" 'get search results'
    else
        mv "$run_pathfile" "$fail_pathfile" 'get search results'
        DebugSearchFailure "$group_index" "downloader returned \"$result: $(Downloader_ReturnCodes "$result")\""
    fi

    DebugSearchChildEnd "$group_index"

    return 0

    }

DownloadImages()
    {

    DebugFuncEntry

    local func_startseconds=$(date +%s)
    local result_index=0
    local message=''
    local result=0
    local parallel_count=0
    local success_count=0
    local fail_count=0
    local imagelink=''
    local download_bytes=0

    [[ $verbose = true ]] && echo -n " -> acquiring images: "

    InitProgress
    InitDownloadsCounts

    while read imagelink; do
        while true; do
            RefreshDownloadCounts
            ShowImageDownloadProgress

            # abort downloading if too many failures
            if [[ $fail_count -ge $fail_limit ]]; then
                result=1

                wait 2>/dev/null

                break 2
            fi

            # wait here until a download slot becomes available
            while [[ $parallel_count -eq $parallel_limit ]]; do
                sleep 0.5

                RefreshDownloadCounts
            done

            # have enough images now so exit loop
            [[ $success_count -eq $images_required ]] &&    break 2

            if [[ $((success_count+parallel_count)) -lt $images_required ]]; then
                ((result_index++))
                local link_index=$(printf "%04d" $result_index)

                # create run file here as it takes too long to happen in background function
                touch "$download_run_count_path/$link_index"
                { DownloadImage_auto "$imagelink" "$link_index" & } 2>/dev/null

                break
            fi
        done
    done < "$imagelinks_pathfile"

    wait 2>/dev/null

    RefreshDownloadCounts
    ShowImageDownloadProgress

    if [[ $fail_count -gt 0 ]]; then
        # derived from: http://stackoverflow.com/questions/24284460/calculating-rounded-percentage-in-shell-script-without-using-bc
        percent="$((200*(fail_count)/(success_count+fail_count) % 2 + 100*(fail_count)/(success_count+fail_count)))%"

        if [[ $colour = true ]]; then
            echo -n "($(ColourTextBrightRed "$percent")) "
        else
            echo -n "($percent) "
        fi
    fi

    if [[ $result -eq 1 ]]; then
        DebugFuncFailure '! failure limit reached' "$fail_count/$fail_limit"

        if [[ $colour = true ]]; then
            echo "$(ColourTextBrightRed 'Too many failures!')"
        else
            echo "Too many failures!"
        fi
    else
        if [[ $result_index -eq $result_count ]]; then
            DebugFuncFailure '! ran out of images to download!' "$result_index/$result_count"

            if [[ $colour = true ]]; then
                echo "$(ColourTextBrightRed 'Ran out of images to download!')"
            else
                echo "Ran out of images to download!"
            fi

            result=1
        else
            [[ $verbose = true ]] && echo
        fi
    fi

    if [[ $result -ne 1 ]]; then
        download_bytes="$($DU_BIN "$target_path/$image_file_prefix"* -cb | tail -n1 | cut -f1)"
        DebugFuncVal 'downloaded bytes' "$(DisplayThousands "$download_bytes")"

        download_seconds="$(($(date +%s)-func_startseconds))"
        DebugFuncVal 'download seconds' "$(DisplayThousands "$download_seconds")"
        if [[ $download_seconds -lt 1 ]]; then
            download_seconds=1
            DebugFuncVarAdjustment "\$download_seconds TOO LOW so set to a usable minimum" "$download_seconds"
        fi

        DebugFuncVal 'average download speed' "$(DisplayISO "$((download_bytes/download_seconds))")B/s"
    fi

    DebugFuncVal 'downloads OK' "$success_count"
    DebugFuncVal 'downloads failed' "$fail_count"
    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return $result

    }

DownloadImage_auto()
    {

    # *** This function runs as a background process ***
    # $1 = URL to download
    # $2 = debug index identifier e.g. "0026"

    local URL="$1"
    local link_index="$2"
    local get_download=true
    local size_ok=true
    local response=''
    local result=0
    local download_speed=''
    local actual_size=0

    local run_pathfile="$download_run_count_path/$link_index"
    local success_pathfile="$download_success_count_path/$link_index"
    local fail_pathfile="$download_fail_count_path/$link_index"

    DebugLinkChildSpawned "$link_index"

    # extract file extension by checking only last 5 characters of URL (to handle .jpeg as worst case)
    local ext=$(echo ${1:(-5)} | $SED_BIN "s/.*\(\.[^\.]*\)$/\1/")

    [[ ! "$ext" =~ '.' ]] && ext='.jpg' # if URL did not have a file extension then choose jpg as default

    local testimage_pathfileext="$testimage_pathfile($link_index)$ext"
    local targetimage_pathfile="$target_path/$image_file_prefix"
    local targetimage_pathfileext="$targetimage_pathfile($link_index)$ext"

    # apply file size limits before download?
    if [[ $upper_size_limit -gt 0 || $lower_size_limit -gt 0 ]]; then
        # try to get file size from server
        response=$(Downloader_GetHeaders "$URL" "$link_index" "$testimage_pathfileext")
        result=$?

        if [[ $result -eq 0 ]]; then
            estimated_size="$(grep -i 'content-length:' <<< "$response" | $SED_BIN 's|^.*: ||;s|\r||')"
            [[ -z $estimated_size || $estimated_size = unspecified ]] && estimated_size=unknown

            DebugLinkVal "$link_index" 'pre-download image size' "$estimated_size bytes"

            if [[ $estimated_size != unknown ]]; then
                if [[ $estimated_size -lt $lower_size_limit ]] || [[ $upper_size_limit -gt 0 && $estimated_size -gt $upper_size_limit ]]; then
                    DebugLinkFailure "$link_index" 'image size range validation'
                    size_ok=false
                    get_download=false
                else
                    DebugLinkSuccess "$link_index" 'image size range validation'
                fi
            else
                if [[ $skip_no_size = true ]]; then
                    DebugLinkFailure "$link_index" 'pre-download image size is UNKNOWN'
                    get_download=false
                fi
            fi
        else
            DebugLinkFailure "$link_index" "pre-downloader returned: \"$result: $(Downloader_ReturnCodes "$result")\""

            if [[ $skip_no_size = true ]]; then
                get_download=false
            else
                estimated_size=unknown
            fi
        fi
    fi

    # perform image download
    if [[ $get_download = true ]]; then
        response=$(Downloader_GetFile "$URL" "$link_index" "$targetimage_pathfileext")
        result=$?

        if [[ $result -eq 0 ]]; then
            if [[ -e $targetimage_pathfileext ]]; then
                actual_size=$(wc -c < "$targetimage_pathfileext"); actual_size=${actual_size##* }
                # http://stackoverflow.com/questions/36249714/parse-download-speed-from-wget-output-in-terminal
                download_speed=$(tail -n1 <<< "$response" | grep -o '\([0-9.]\+ [KM]B/s\)'); download_speed="${download_speed/K/k}"

                DebugLinkVal "$link_index" 'post-download image size' "$actual_size bytes"
                DebugLinkVal "$link_index" "average download speed" "$download_speed"

                if [[ $actual_size -lt $lower_size_limit ]] || [[ $upper_size_limit -gt 0 && $actual_size -gt $upper_size_limit ]]; then
                    rm -f "$targetimage_pathfileext"
                    size_ok=false
                fi
            else
                # file does not exist
                size_ok=false
            fi

            if [[ $size_ok = true ]]; then
                DebugLinkSuccess "$link_index" 'image size range validation'
                RenameExtAsType "$targetimage_pathfileext"

                if [[ $? -eq 0 ]]; then
                    mv "$run_pathfile" "$success_pathfile"
                    DebugLinkSuccess "$link_index" 'image type validation'
                    DebugLinkSuccess "$link_index" 'image download'
                else
                    DebugLinkFailure "$link_index" 'image type validation'
                fi
            else
                # files that were outside size limits still count as failures
                mv "$run_pathfile" "$fail_pathfile"
                DebugLinkFailure "$link_index" 'image size range validation'
            fi
        else
            mv "$run_pathfile" "$fail_pathfile"
            DebugLinkFailure "$link_index" "post-downloader returned: \"$result: $(Downloader_ReturnCodes "$result")\""

            # delete temp file if one was created
            [[ -e $targetimage_pathfileext ]] && rm -f "$targetimage_pathfileext"
        fi
    else
        mv "$run_pathfile" "$fail_pathfile"
        DebugLinkFailure "$link_index" 'image download'
    fi

    DebugLinkChildEnd "$link_index"

    return 0

    }

Downloader_GetResults()
    {

    # $1 = page group to load           e.g. 0, 1, 2, 3, etc...
    # $2 = debug log link index         e.g. (02)
    # echo = downloader stdout & stderr
    # $? = downloader return code

    local page_group="$1"
    local group_index="$2"
    local search_group="&ijn=$((page_group-1))"
    local search_start="&start=$(((page_group-1)*100))"
    local SERVER=www.google.com
    local get_results_cmd=''

    # ------------- assumptions regarding Google's URL parameters ---------------------------------------------------
    local search_type='&tbm=isch'       # search for images
    local search_language='&hl=en'      # language
    local search_style='&site=imghp'    # result layout style
    local search_match_type='&nfpr=1'   # perform exact string search - does not show most likely match results or suggested search.

    # compiled search string
    local search_string="\"https://$SERVER/search?${search_type}${search_match_type}${safe_search_query}${search_language}${search_style}${search_group}${search_start}${advanced_search}\""

    if [[ $(basename $DOWNLOADER_BIN) = wget ]]; then
        get_results_cmd="$DOWNLOADER_BIN --quiet --timeout 5 --tries 3 $search_string $USERAGENT --output-document \"$searchresults_pathfile.$page_group\""
    elif [[ $(basename $DOWNLOADER_BIN) = curl ]]; then
        get_results_cmd="$DOWNLOADER_BIN --max-time 30 $search_string $USERAGENT --output \"$searchresults_pathfile.$page_group\""
    else
        DebugThis "! [${FUNCNAME[0]}]" 'unknown downloader'
        return 1
    fi

    DebugSearchExec "$group_index" "get search results" "$get_results_cmd"

    eval "$get_results_cmd" 2>&1

    }

Downloader_GetHeaders()
    {

    # $1 = URL to check
    # $2 = debug index identifier e.g. (0002)
    # $3 = temporary filename to download to (only used by Wget)
    # echo = header string
    # $? = downloader return code

    local URL="$1"
    local link_index="$2"
    local output_pathfile="$3"
    local get_headers_cmd=''

    if [[ $(basename $DOWNLOADER_BIN) = wget ]]; then
        get_headers_cmd="$DOWNLOADER_BIN --spider --server-response --max-redirect 0 --no-check-certificate --timeout $timeout --tries $((retries+1)) $USERAGENT --output-document \"$output_pathfile\" \"$URL\""
    elif [[ $(basename $DOWNLOADER_BIN) = curl ]]; then
        get_headers_cmd="$DOWNLOADER_BIN --silent --head --insecure --max-time 30 $USERAGENT \"$URL\""
    else
        DebugThis "! [${FUNCNAME[0]}]" 'unknown downloader'
        return 1
    fi

    DebugLinkExec "$link_index" "get image size" "$get_headers_cmd"

    eval "$get_headers_cmd" 2>&1

    }

Downloader_GetFile()
    {

    # $1 = URL to check
    # $2 = debug index identifier e.g. (0002)
    # $3 = filename to download to
    # echo = downloader stdout & stderr
    # $? = downloader return code

    local URL="$1"
    local link_index="$2"
    local output_pathfile="$3"
    local get_image_cmd=''

    if [[ $(basename $DOWNLOADER_BIN) = wget ]]; then
        get_image_cmd="$DOWNLOADER_BIN --max-redirect 0 --no-check-certificate --timeout $timeout --tries $((retries+1)) $USERAGENT --output-document \"$output_pathfile\" \"$URL\""
    elif [[ $(basename $DOWNLOADER_BIN) = curl ]]; then
        get_image_cmd="$DOWNLOADER_BIN --silent --max-time 30 $USERAGENT --output \"$output_pathfile\" \"$URL\""
    else
        DebugThis "! [${FUNCNAME[0]}]" 'unknown downloader'
        return 1
    fi

    DebugLinkExec "$link_index" "get image" "$get_image_cmd"

    eval "$get_image_cmd" 2>&1

    }

ParseResults()
    {

    DebugFuncEntry

    result_count=0

    ScrapeSearchResults

    if [[ -e $imagelinks_pathfile ]]; then
        # check against allowable file types
        while read imagelink; do
            AllowableFileType "$imagelink"
            [[ $? -eq 0 ]] && echo "$imagelink" >> "$imagelinks_pathfile.tmp"
        done < "$imagelinks_pathfile"

        [[ -e $imagelinks_pathfile.tmp ]] && mv "$imagelinks_pathfile.tmp" "$imagelinks_pathfile"

        # get link count
        result_count=$(wc -l < "$imagelinks_pathfile"); result_count=${result_count##* }
        DebugFuncVar result_count

        # if too many results then trim
        if [[ $result_count -gt $max_results_required ]]; then
            DebugFuncVarAdjustment "trimming results back to required amount" "$max_results_required"
            head -n "$max_results_required" "$imagelinks_pathfile" > "$imagelinks_pathfile".tmp
            mv "$imagelinks_pathfile".tmp "$imagelinks_pathfile"
            result_count=$max_results_required
        fi
    fi

    if [[ $verbose = true ]]; then
        if [[ $result_count -gt 0 ]]; then
            if [[ $colour = true ]]; then
                if [[ $result_count -ge $max_results_required ]]; then
                    echo "$(ColourTextBrightGreen "$result_count") results!"
                fi

                if [[ $result_count -ge $images_required && $result_count -lt $max_results_required ]]; then
                    echo "$(ColourTextBrightOrange "$result_count") results!"
                fi

                if [[ $result_count -lt $images_required ]]; then
                    echo "$(ColourTextBrightRed "$result_count") results!"
                fi
            else
                echo "$result_count results!"
            fi
        else
            if [[ $colour = true ]]; then
                echo "$(ColourTextBrightRed 'No results!')"
            else
                echo "No results!"
            fi
        fi
    fi

    DebugFuncVar result_count
    DebugFuncExit

    }

BuildGallery()
    {

    DebugFuncEntry

    local thumbnail_dimensions='400x400'
    local func_startseconds=$(date +%s)
    local reserve_for_border="-border $border_thickness"
    local title_height=100
    local stage_description=''

    InitProgress

    # build thumbnails image overlay
    stage_description='compose thumbnails'
    if [[ $verbose = true ]]; then
        echo -n " -> building gallery: "

        if [[ $colour = true ]]; then
            progress_message="$(ColourTextBrightOrange 'stage 1/4')"
        else
            progress_message='stage 1/4'
        fi

        progress_message+=" ($stage_description)"
        ProgressUpdater "$progress_message"
    fi

    if [[ $gallery_title = '_false_' ]]; then
        reserve_for_title=''
    else
        reserve_for_title="-gravity north -splice 0x$((title_height+border_thickness+10))"
    fi

    if [[ $condensed_gallery = true ]]; then
        build_foreground_cmd="$CONVERT_BIN \"$target_path/*[0]\" -define jpeg:size=$thumbnail_dimensions -thumbnail ${thumbnail_dimensions}^ -gravity center -extent $thumbnail_dimensions miff:- | montage - -background none -geometry +0+0 miff:- | convert - -background none $reserve_for_title -bordercolor none $reserve_for_border \"$gallery_thumbnails_pathfile\""
    else
        build_foreground_cmd="$MONTAGE_BIN \"$target_path/*[0]\" -background none -shadow -geometry $thumbnail_dimensions miff:- | convert - -background none $reserve_for_title -bordercolor none $reserve_for_border \"$gallery_thumbnails_pathfile\""
    fi

    DebugFuncExec "$stage_description" "$build_foreground_cmd"

    eval $build_foreground_cmd 2>/dev/null
    result=$?

    if [[ $result -eq 0 ]]; then
        DebugFuncSuccess "$stage_description"
    else
        DebugFuncFailure "$stage_description" "($result)"
    fi

    if [[ $result -eq 0 ]]; then
        # build background image
        stage_description='draw background'
        if [[ $verbose = true ]]; then
            if [[ $colour = true ]]; then
                progress_message="$(ColourTextBrightOrange 'stage 2/4')"
            else
                progress_message='stage 2/4'
            fi

            progress_message+=" ($stage_description)"
            ProgressUpdater "$progress_message"
        fi

        # get image dimensions
        read -r width height <<< $($CONVERT_BIN -ping "$gallery_thumbnails_pathfile" -format "%w %h" info:)

        # create a dark image with light sphere in centre
        build_background_cmd="$CONVERT_BIN -size ${width}x${height} radial-gradient:WhiteSmoke-gray10 \"$gallery_background_pathfile\""

        DebugFuncExec "$stage_description" "$build_background_cmd"

        eval $build_background_cmd 2>/dev/null
        result=$?

        if [[ $result -eq 0 ]]; then
            DebugFuncSuccess "$stage_description"
        else
            DebugFuncFailure "$stage_description" "($result)"
        fi
    fi

    if [[ $result -eq 0 ]]; then
        # build title image overlay
        stage_description='draw title'
        if [[ $verbose = true ]]; then
            if [[ $colour = true ]]; then
                progress_message="$(ColourTextBrightOrange 'stage 3/4')"
            else
                progress_message='stage 3/4'
            fi

            progress_message+=" ($stage_description)"
            ProgressUpdater "$progress_message"
        fi

        if [[ $gallery_title != '_false_' ]]; then
            # create title image
            # let's try a fixed height of 100 pixels
            build_title_cmd="$CONVERT_BIN -size x$title_height -font $(FirstPreferredFont) -background none -stroke black -strokewidth 10 label:\"\\ \\ $gallery_title\\ \" -blur 0x5 -fill goldenrod1 -stroke none label:\"\\ \\ $gallery_title\\ \" -flatten \"$gallery_title_pathfile\""

            DebugFuncExec "$stage_description" "$build_title_cmd"

            eval $build_title_cmd 2>/dev/null
            result=$?

            if [[ $result -eq 0 ]]; then
                DebugFuncSuccess "$stage_description"
            else
                DebugFuncFailure "$stage_description" "($result)"
            fi
        fi
    fi

    if [[ $result -eq 0 ]]; then
        # compose thumbnail and title images onto background image
        stage_description='compose images'
        if [[ $verbose = true ]]; then
            if [[ $colour = true ]]; then
                progress_message="$(ColourTextBrightOrange 'stage 4/4')"
            else
                progress_message='stage 4/4'
            fi

            progress_message+=" ($stage_description)"
            ProgressUpdater "$progress_message"
        fi

        if [[ $gallery_title = '_false_' ]]; then
            include_title=''
        else
            include_title="-composite \"$gallery_title_pathfile\" -gravity north -geometry +0+$((border_thickness+10))"
        fi

        # compose thumbnails image on background image, then title image on top
        build_compose_cmd="$CONVERT_BIN \"$gallery_background_pathfile\" \"$gallery_thumbnails_pathfile\" -gravity center $include_title -composite \"$target_path/$gallery_name-($safe_path_phrase).png\""

        DebugFuncExec "$stage_description" "$build_compose_cmd"

        eval $build_compose_cmd 2>/dev/null
        result=$?

        if [[ $result -eq 0 ]]; then
            DebugFuncSuccess "$stage_description"
        else
            DebugFuncFailure "$stage_description" "($result)"
        fi
    fi

    [[ -e $gallery_title_pathfile ]] && rm -f "$gallery_title_pathfile"
    [[ -e $gallery_thumbnails_pathfile ]] && rm -f "$gallery_thumbnails_pathfile"
    [[ -e $gallery_background_pathfile ]] && rm -f "$gallery_background_pathfile"

    if [[ $result -eq 0 ]]; then
        if [[ $verbose = true ]]; then
            if [[ $colour = true ]]; then
                ProgressUpdater "$(ColourTextBrightGreen 'done!')"
            else
                ProgressUpdater 'done!'
            fi
        fi
    else
        if [[ $colour = true ]]; then
            ProgressUpdater "$(ColourTextBrightRed 'failed!')"
        else
            ProgressUpdater 'failed!'
        fi
    fi

    [[ $verbose = true ]] && echo

    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return $result

    }

Finish()
    {

    # display end
    if [[ $verbose = true ]]; then
        case $exitcode in
            0)
                echo
                echo " -> $(ShowAsSucceed 'All done!')"
                ;;
            [1-2])
                if [[ $show_help_only != true ]]; then
                    echo
                    echo " use '-h' or '--help' to display parameter list."
                fi
                ;;
            [3-6])
                echo
                echo " -> $(ShowAsFailed 'All done! (with errors)')"
                ;;
            *)
                ;;
        esac
    fi

    # write results into debug file
    DebugScriptNow
    DebugScriptElapsedTime "$script_startseconds"
    DebugScriptExit

    # copy debug file into target directory if possible. If not, then copy to current directory.
    if [[ $debug = true ]]; then
        if [[ $target_path_created = true ]]; then
            [[ -e $target_path/$debug_file ]] && echo "" >> "$target_path/$debug_file"
            cp -f "$debug_pathfile" "$target_path/$debug_file"
        else
            # append to current path debug file (if it exists)
            [[ -e $current_path/$debug_file ]] && echo "" >> "$current_path/$debug_file"
            cat "$debug_pathfile" >> "$current_path/$debug_file"
        fi
    fi

    [[ $show_help_only = true ]] && exitcode=0

    }

SuggestInstall()
    {

    # $1 = executable name missing
    # $2 (optional) = package to install. Only specify this if different to $1

    [[ -n $1 ]] && executable=$1 || return 1
    [[ -n $2 ]] && package=$2 || package=$executable

    DebugThis "! no recognised '$executable' executable found"
    echo -e "\n '$executable' executable not found!"
    if [[ $PACKAGER_BIN != unknown ]]; then
        echo -e "\n try installing with:"
        echo " $ $(basename $PACKAGER_BIN) install $package"
    else
        echo " no local package manager found!"
        echo " well, I'm out of ideas..."
    fi

    }

InitProgress()
    {

    # needs to be called prior to first call of ProgressUpdater

    progress_message=''
    previous_length=0
    previous_msg=''

    }

ProgressUpdater()
    {

    # $1 = message to display

    if [[ $1 != $previous_msg ]]; then
        temp=$(RemoveColourCodes "$1")
        current_length=$((${#temp}+1))

        if [[ $current_length -lt $previous_length ]]; then
            appended_length=$((current_length-previous_length))
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

InitResultsCounts()
    {

    # clears the paths used to count the search result pages

    [[ -d $results_run_count_path ]] && rm -f ${results_run_count_path}/*
    [[ -d $results_success_count_path ]] && rm -f ${results_success_count_path}/*
    [[ -d $results_fail_count_path ]] && rm -f ${results_fail_count_path}/*

    }

InitDownloadsCounts()
    {

    # clears the paths used to count the downloaded images

    [[ -d $download_run_count_path ]] && rm -f ${download_run_count_path}/*
    [[ -d $download_success_count_path ]] && rm -f ${download_success_count_path}/*
    [[ -d $dowload_fail_count_path ]] && rm -f ${download_fail_count_path}/*

    }

RefreshResultsCounts()
    {

    parallel_count=$(ls -1 "$results_run_count_path" | wc -l); parallel_count=${parallel_count##* }
    success_count=$(ls -1 "$results_success_count_path" | wc -l); success_count=${success_count##* }
    fail_count=$(ls -1 "$results_fail_count_path" | wc -l); fail_count=${fail_count##* }

    }

ShowResultDownloadProgress()
    {

    if [[ $verbose = true ]]; then
        if [[ $colour = true ]]; then
            if [[ $success_count -eq $groups_max ]]; then
                progress_message="$(ColourTextBrightGreen "$success_count/$groups_max")"
            else
                progress_message="$(ColourTextBrightOrange "$success_count/$groups_max")"
            fi
        else
            progress_message="$success_count/$groups_max"
        fi

        progress_message+=' result groups downloaded.'
        ProgressUpdater "$progress_message"
    fi

    }

RefreshDownloadCounts()
    {

    parallel_count=$(ls -1 "$download_run_count_path" | wc -l); parallel_count=${parallel_count##* }
    success_count=$(ls -1 "$download_success_count_path" | wc -l); success_count=${success_count##* }
    fail_count=$(ls -1 "$download_fail_count_path" | wc -l); fail_count=${fail_count##* }

    }

ShowImageDownloadProgress()
    {

    if [[ $verbose = true ]]; then
        # number of image downloads that are OK
        if [[ $colour = true ]]; then
            progress_message="$(ColourTextBrightGreen "$success_count/$images_required")"
        else
            progress_message="$success_count/$images_required"
        fi

        progress_message+=' downloaded'

        # show the number of files currently downloading (if any)
        if [[ $parallel_count -gt 0 ]]; then
            progress_message+=', '

            if [[ $colour = true ]]; then
                progress_message+="$(ColourTextBrightOrange "$parallel_count/$parallel_limit")"
            else
                progress_message+="$parallel_count/$parallel_limit"
            fi

            progress_message+=' are in progress'
        fi

        # include failures (if any)
        if [[ $fail_count -gt 0 ]]; then
            progress_message+=' and '

            if [[ $colour = true ]]; then
                progress_message+="$(ColourTextBrightRed "$fail_count/$fail_limit")"
            else
                progress_message+="$fail_count/$fail_limit"
            fi

            progress_message+=' failed'
        fi

        progress_message+='.'
        ProgressUpdater "$progress_message"
    fi

    }

ShowGoogle()
    {

    echo -n "$(ColourTextBrightBlue 'G')$(ColourTextBrightRed 'o')$(ColourTextBrightOrange 'o')$(ColourTextBrightBlue 'g')$(ColourTextBrightGreen 'l')$(ColourTextBrightRed 'e')"

    }

FormatHelpLine()
    {

    # $1 = short parameter
    # $2 = long parameter
    # $3 = description

    if [[ -n $1 && -n $2 ]]; then
        printf "  -%-1s, --%-17s %s\n" "$1" "$2" "$3"
    elif [[ -z $1 && -n $2 ]]; then
        printf "   %-1s  --%-17s %s\n" '' "$2" "$3"
    else
        printf "   %-1s    %-17s %s\n" '' '' "$3"
    fi

    }

RenameExtAsType()
    {

    # checks output of 'identify -format "%m"' and ensures provided file extension matches
    # $1 = image filename. Is it actually a valid image?
    # $? = 0 if it IS an image, 1 if not an image

    local returncode=0

    if [[ -n $IDENTIFY_BIN ]]; then
        [[ -z $1 ]] && returncode=1
        [[ ! -e $1 ]] && returncode=1

        if [[ $returncode -eq 0 ]]; then
            rawtype=$($IDENTIFY_BIN -format "%m" "$1")
            returncode=$?
        fi

        if [[ $returncode -eq 0 ]]; then
            # only want first 4 chars
            imagetype="${rawtype:0:4}"

            # exception to handle identify's output for animated gifs i.e. "GIFGIFGIFGIFGIF"
            [[ $imagetype = 'GIFG' ]] && imagetype='GIF'

            # exception to handle identify's output for BMP i.e. "BMP3"
            [[ $imagetype = 'BMP3' ]] && imagetype='BMP'

            case "$imagetype" in
                JPEG|GIF|PNG|BMP|ICO)
                    # move file into temp file
                    mv "$1" "$1".tmp

                    # then back but with new extension created from $imagetype
                    mv "$1".tmp "${1%.*}.$(Lowercase "$imagetype")"
                    ;;
                *)
                    # not a valid image
                    returncode=1
                    ;;
            esac
        fi
    fi

    return $returncode

    }

AllowableFileType()
    {

    # only these image types are considered acceptable
    # $1 = string to check
    # $? = 0 if OK, 1 if not

    local lcase=$(Lowercase "$1")
    local ext=$(echo ${lcase:(-5)} | $SED_BIN "s/.*\(\.[^\.]*\)$/\1/")

    # if string does not have a '.' then assume no extension present
    [[ ! "$ext" =~ '.' ]] && ext=''

    case "$ext" in
        .jpg|.jpeg|.gif|.png|.bmp|.ico)
            # valid image type
            return 0
            ;;
        *)
            # not a valid image
            return 1
            ;;
    esac

    }

ScrapeSearchResults()
    {

    #------------- these regexes will need updating when Google change their web-code again --------------
    #
    # sed   1. add 2 x newline chars before each occurence of '<div',
    #       2. remove ' notranslate' (if this is one of the odd times Google have added it),
    #
    # grep  3. only list lines with '<div class="rg_meta">',
    #
    # sed   4. remove lines with 'YouTube' (case insensitive),
    #       5. remove lines with 'Vimeo' (case insensitive),
    #       6. add newline char before first occurence of 'http',
    #       7. remove from '<div' to newline,
    #       8. remove from '","ow"' to end of line,
    #       9. remove from '?' to end of line.
    #
    #---------------------------------------------------------------------------------------------------------------

    cat "$searchresults_pathfile" \
    | $SED_BIN 's|<div|\n\n&|g;s| notranslate||g' \
    | grep '<div class="rg_meta">' \
    | $SED_BIN '/youtube/Id;/vimeo/Id;s|http|\n&|;s|<div.*\n||;s|","ow".*||;s|\?.*||' \
    > "$imagelinks_pathfile"

    }

CTRL_C_Captured()
    {

    DebugThis "! [SIGINT]" "detected"

    echo

    if [[ $colour = true ]]; then
        echo " -> $(ColourTextBrightRed '[SIGINT]') - let's cleanup now ..."
    else
        echo " -> [SIGINT] - let's cleanup now ..."
    fi

    # http://stackoverflow.com/questions/81520/how-to-suppress-terminated-message-after-killing-in-bash
    kill $(jobs -p) 2>/dev/null
    wait $(jobs -p) 2>/dev/null

    RefreshDownloadCounts

    if [[ $parallel_count -gt 0 ]]; then
        # remove any image files where processing by [DownloadImage_auto] was incomplete
        for currentfile in $(ls -1 "$download_run_count_path"); do
            rm -f "$target_path/$image_file_prefix($currentfile)".*
            DebugThis "= link ($currentfile) was partially processed" 'deleted!'
        done
    fi

    DebugThis "< finished" "$(date)"

    echo
    echo " -> And ... we're done."

    exit

    }

DebugScriptEntry()
    {

    DebugEntry "$(FormatScript)"

    }

DebugScriptExit()
    {

    DebugExit "$(FormatScript)"

    }

DebugScriptNow()
    {

    DebugNow "$(FormatScript)"

    }

DebugScriptVal()
    {

    [[ -z $1 || -z $2 ]] && return 1

    DebugVal "$(FormatScript)" "$1: $2"

    }

DebugScriptVar()
    {

    # $1 = script variable name and value to log

    [[ -z $1 ]] && return 1

    DebugVar "$(FormatScript)" "$1"

    }

DebugScriptElapsedTime()
    {

    # $1 = number of seconds to count from

    [[ -z $1 ]] && return 1

    DebugThis "T $(FormatScript) elapsed time" "$(ConvertSecs "$(($(date +%s)-$1))")"

    }

DebugScriptComment()
    {

    # $1 = script comment to log

    [[ -z $1 ]] && return 1

    DebugComment "[${SCRIPT_FILE}]" "$1"

    }

DebugFuncEntry()
    {

    DebugEntry "$(FormatFunc)"

    }

DebugFuncExit()
    {

    DebugExit "$(FormatFunc)"

    }

DebugFuncElapsedTime()
    {

    # $1 = number of seconds to count from

    [[ -z $1 ]] && return 1

    DebugThis "T" "$(FormatFunc) elapsed time:" "$(ConvertSecs "$(($(date +%s)-$1))")"

    }

DebugFuncVarAdjustment()
    {

    # $1 = reason
    # $2 = result

    [[ -z $1 || -z $2 ]] && return 1

    DebugThis '~' "$(FormatFunc) $1:" "$2"

    }

DebugFuncSuccess()
    {

    # $1 = operation

    [[ -z $1 ]] && return 1

    DebugSuccess "$(FormatFunc)" "$1"

    }

DebugFuncFailure()
    {

    # $1 = operation
    # $2 = reason

    [[ -z $1 || -z $2 ]] && return 1

    DebugFailed "$(FormatFunc) $1" "$2"

    }

DebugFuncVar()
    {

    # $1 = function variable name and value to log

    DebugVar "$(FormatFunc)" "$1"

    }

DebugFuncExec()
    {

    # $1 = description
    # $2 = command string to execute

    [[ -z $1 || -z $2 ]] && return 1

    DebugExec "$(FormatFunc) $1" "$2"

    }

DebugFuncVal()
    {

    # $1 = function variable name to log
    # $2 = value

    DebugVal "$(FormatFunc)" "$1: $2"

    }

DebugFuncComment()
    {

    # $1 = function comment to log

    DebugComment "$(FormatFunc)" "$1"

    }

DebugSearchSuccess()
    {

    # $1 = search index
    # $2 = operation

    [[ -z $1 || -z $2 ]] && return 1

    DebugSuccess "$(FormatSearch $1)" "$2"

    }

DebugSearchFailure()
    {

    # $1 = search index
    # $2 = operation

    [[ -z $1 || -z $2 ]] && return 1

    DebugFailed "$(FormatSearch $1)" "$2"

    }

DebugSearchChildSpawned()
    {

    # record $1 (search group index) as spawned process in debug log

    DebugThis '>' "$(FormatSearch $1)" "processor spawned"

    }

DebugSearchChildEnd()
    {

    # record $1 (search group index) as spawned process in debug log

    DebugThis '<' "$(FormatSearch $1)" "processor ended"

    }

DebugSearchVal()
    {

    # $1 = search index
    # $2 = variable
    # $3 = value

    [[ -z $1 || -z $2 ]] && return 1

    DebugVal "$(FormatSearch $1) $2:" "$3"

    }

DebugSearchExec()
    {

    # $1 = search index
    # $2 = reason
    # $3 = command string to execute

    [[ -z $1 || -z $2 ]] && return 1

    DebugExec "$(FormatSearch $1) $2" "$3"

    }

DebugLinkSuccess()
    {

    # $1 = link index
    # $2 = operation

    [[ -z $1 || -z $2 ]] && return 1

    DebugSuccess "$(FormatLink $1)" "$2"

    }

DebugLinkFailure()
    {

    # $1 = link index
    # $2 = operation

    [[ -z $1 || -z $2 ]] && return 1

    DebugFailed "$(FormatLink $1)" "$2"

    }

DebugLinkChildSpawned()
    {

    # record $1 (link name) as spawned process in debug log

    DebugThis '>' "$(FormatLink $1)" "processor spawned"

    }

DebugLinkChildEnd()
    {

    # record $1 (link name) as spawned process in debug log

    DebugThis '<' "$(FormatLink $1)" "processor ended"

    }

DebugLinkVal()
    {

    # $1 = link index
    # $2 = variable
    # $3 = value

    [[ -z $1 || -z $2 ]] && return 1

    DebugVal "$(FormatLink $1) $2:" "$3"

    }

DebugLinkExec()
    {

    # $1 = link index
    # $2 = reason
    # $3 = command string to execute

    [[ -z $1 || -z $2 ]] && return 1

    DebugExec "$(FormatLink $1) $2" "$3"

    }

DebugNow()
    {

    # record variable name and value in debug log

    DebugThis '=' "$1 now:" "$(date)"

    }

DebugVar()
    {

    # $1 = scope
    # $2 = variable name and value to log

    if [[ -n ${!2} ]]; then
        DebugVal "$1" "\$$2" "${!2}"
    else
        DebugVal "$1" "\$$2" "''"
    fi

    }

DebugVal()
    {

    # make a record of name and value in debug log
    # $1 = section
    # $2 = name
    # $3 - value

    [[ -z $1 || -z $2 ]] && return 1

    if [[ -n $3 ]]; then
        DebugThis '?' "$1" "$2: $3"
    else
        DebugThis '?' "$1" "$2"
    fi

    }

DebugEntry()
    {

    # record $1 as a function or script name name in debug log

    DebugThis '\' "$1" "entry"

    }

DebugExit()
    {

    # record $1 as a function or script name name in debug log

    DebugThis '/' "$1" "exit"

    }

DebugSuccess()
    {

    # $1 = section
    # $2 = operation

    [[ -z $1 ]] && return 1

    DebugThis '$' "$1 $2:" "OK"

    }

DebugFailed()
    {

    # $1 = section
    # $2 = operation
    # $3 = optional reason

    [[ -z $1 ]] && return 1

    if [[ -n $3 ]]; then
        DebugThis '!' "$1 $2: $3:" "failed"
    else
        DebugThis '!' "$1 $2:" "failed"
    fi

    }

DebugExec()
    {

    # record process execution start in debug log

    DebugThis '=' "$1:" "'$2'"

    }

DebugComment()
    {

    # record comment in debug log

    DebugThis '#' "$1" "*** $2 ***"

    }

DebugThis()
    {

    # $1 = symbol
    # $2 = item
    # $3 = value

    [[ -z $1 || -z $2 ]] && return 1

    if [[ -n $3 ]]; then
        echo "$1 $2 $3" >> "$debug_pathfile"
    else
        echo "$1 $2" >> "$debug_pathfile"
    fi

    }

FormatScript()
    {

    # stdout = formatted script filename

    echo "[$SCRIPT_FILE]"

    }

FormatFunc()
    {

    # stdout = formatted function name 2 steps back in stack

    echo "[${FUNCNAME[2]}]"

    }

FormatSearch()
    {

    # $1 = search index
    # stdout = formatted search index

    [[ -z $1 ]] && return 1

    echo "search ($1)"

    }

FormatLink()
    {

    # $1 = link index
    # stdout = formatted link index

    [[ -z $1 ]] && return 1

    echo "link ($1)"

    }

Downloader_ReturnCodes()
    {

    # $1 = downloader return code
    # echo = return code description

    if [[ $(basename $DOWNLOADER_BIN) = wget ]]; then
        WgetReturnCodes "$1"
    elif [[ $(basename $DOWNLOADER_BIN) = curl ]]; then
        CurlReturnCodes "$1"
    else
        DebugThis "! no return codes available for this downloader"
        return 1
    fi

    }

WgetReturnCodes()
    {

    # convert Wget return code into a description
    # https://gist.github.com/cosimo/5747881#file-wget-exit-codes-txt

    # $1 = Wget return code
    # echo = text string

    case "$1" in
        0)
            echo "No problems occurred"
            ;;
        2)
            echo "Parse error — for instance, when parsing command-line options, the .wgetrc or .netrc…"
            ;;
        3)
            echo "File I/O error"
            ;;
        4)
            echo "Network failure"
            ;;
        5)
            echo "SSL verification failure"
            ;;
        6)
            echo "Username/password authentication failure"
            ;;
        7)
            echo "Protocol errors"
            ;;
        8)
            echo "Server issued an error response"
            ;;
        *)
            echo "Generic error code"
            ;;
    esac

    }

CurlReturnCodes()
    {

    # convert cURL return code into a description
    # https://ec.haxx.se/usingcurl-returns.html

    # $1 = cURL return code
    # echo = text string

    case "$1" in
        0)
            echo "No problems occurred"
            ;;
        1)
            echo "Unsupported protocol"
            ;;
        2)
            echo "Failed to initialize"
            ;;
        3)
            echo "URL malformed"
            ;;
        4)
            echo "A feature or option that was needed to perform the desired request was not enabled or was explicitly disabled at build-time"
            ;;
        5)
            echo "Couldn't resolve proxy"
            ;;
        6)
            echo "Couldn't resolve host"
            ;;
        7)
            echo "Failed to connect to host"
            ;;
        8)
            echo "Unknown FTP server response"
            ;;
        9)
            echo "FTP access denied"
            ;;
        10)
            echo "FTP accept failed"
            ;;
        11)
            echo "FTP weird PASS reply"
            ;;
        12)
            echo "During an active FTP session (PORT is used) while waiting for the server to connect, the timeout expired"
            ;;
        13)
            echo "Unknown response to FTP PASV command, Curl could not parse the reply sent to the PASV request"
            ;;
        14)
            echo "Unknown FTP 227 format"
            ;;
        15)
            echo "FTP can't get host"
            ;;
        16)
            echo "HTTP/2 error"
            ;;
        17)
            echo "FTP couldn't set binary"
            ;;
        18)
            echo "Partial file"
            ;;
        19)
            echo "FTP couldn't download/access the given file"
            ;;
        21)
            echo "Quote error"
            ;;
        22)
            echo "HTTP page not retrieved"
            ;;
        23)
            echo "Write error"
            ;;
        25)
            echo "Upload failed"
            ;;
        26)
            echo "Read error"
            ;;
        27)
            echo "Out of memory"
            ;;
        28)
            echo "Operation timeout"
            ;;
        30)
            echo "FTP PORT failed"
            ;;
        31)
            echo "FTP couldn't use REST"
            ;;
        33)
            echo "HTTP range error"
            ;;
        34)
            echo "HTTP post error"
            ;;
        35)
            echo "A TLS/SSL connect error"
            ;;
        36)
            echo "Bad download resume"
            ;;
        37)
            echo "Couldn't read the given file when using the FILE:// scheme"
            ;;
        38)
            echo "LDAP cannot bind"
            ;;
        39)
            echo "LDAP search failed"
            ;;
        42)
            echo "Aborted by callback"
            ;;
        43)
            echo "Bad function argument"
            ;;
        45)
            echo "Interface error"
            ;;
        47)
            echo "Too many redirects"
            ;;
        48)
            echo "Unknown option specified to libcurl"
            ;;
        49)
            echo "Malformed telnet option"
            ;;
        51)
            echo "The server's SSL/TLS certificate or SSH fingerprint failed verification"
            ;;
        52)
            echo "The server did not reply anything, which in this context is considered an error"
            ;;
        53)
            echo "SSL crypto engine not found"
            ;;
        54)
            echo "Cannot set SSL crypto engine as default"
            ;;
        55)
            echo "Failed sending network data"
            ;;
        56)
            echo "Failure in receiving network data"
            ;;
        58)
            echo "Problem with the local certificate"
            ;;
        59)
            echo "Couldn't use the specified SSL cipher"
            ;;
        60)
            echo "Peer certificate cannot be authenticated with known CA certificates"
            ;;
        61)
            echo "Unrecognized transfer encoding"
            ;;
        62)
            echo "Invalid LDAP URL"
            ;;
        63)
            echo "Maximum file size exceeded"
            ;;
        64)
            echo "Requested FTP SSL level failed"
            ;;
        65)
            echo "Sending the data requires a rewind that failed"
            ;;
        66)
            echo "Failed to initialize SSL Engine"
            ;;
        67)
            echo "The user name, password, or similar was not accepted and curl failed to log in"
            ;;
        68)
            echo "File not found on TFTP server"
            ;;
        69)
            echo "Permission problem on TFTP server"
            ;;
        70)
            echo "Out of disk space on TFTP server"
            ;;
        71)
            echo "Illegal TFTP operation"
            ;;
        72)
            echo "Unknown TFTP transfer ID"
            ;;
        73)
            echo "File already exists (TFTP)"
            ;;
        74)
            echo "No such user (TFTP)"
            ;;
        75)
            echo "Character conversion failed"
            ;;
        76)
            echo "Character conversion functions required"
            ;;
        77)
            echo "Problem with reading the SSL CA cert"
            ;;
        78)
            echo "The resource referenced in the URL does not exist"
            ;;
        79)
            echo "An unspecified error occurred during the SSH session"
            ;;
        80)
            echo "Failed to shut down the SSL connection"
            ;;
        82)
            echo "Could not load CRL file, missing or wrong format"
            ;;
        83)
            echo "TLS certificate issuer check failed"
            ;;
        84)
            echo "The FTP PRET command failed"
            ;;
        85)
            echo "RTSP: mismatch of CSeq numbers"
            ;;
        86)
            echo "RTSP: mismatch of Session Identifiers"
            ;;
        87)
            echo "unable to parse FTP file list"
            ;;
        88)
            echo "FTP chunk callback reported error"
            ;;
        89)
            echo "No connection available, the session will be queued"
            ;;
        90)
            echo "SSL public key does not matched pinned public key"
            ;;
        91)
            echo "Invalid SSL certificate status"
            ;;
        92)
            echo "Stream error in HTTP/2 framing layer"
            ;;
        *)
            echo "Unknown error code"
            ;;
    esac

    }

ConvertSecs()
    {

    # http://stackoverflow.com/questions/12199631/convert-seconds-to-hours-minutes-seconds
    # $1 = a time in seconds to convert to 'hh:mm:ss'

    ((h=${1}/3600))
    ((m=(${1}%3600)/60))
    ((s=${1}%60))

    printf "%02dh:%02dm:%02ds\n" $h $m $s

    }

ColourBackgroundBlack()
    {

    echo -en '\033[40m'"$(PrintResetColours "$1")"

    }

ColourTextBrightWhite()
    {

    echo -en '\033[1;97m'"$(PrintResetColours "$1")"

    }

ColourTextBrightGreen()
    {

    echo -en '\033[1;32m'"$(PrintResetColours "$1")"

    }

ColourTextBrightOrange()
    {

    echo -en '\033[1;38;5;214m'"$(PrintResetColours "$1")"

    }

ColourTextBrightRed()
    {

    echo -en '\033[1;31m'"$(PrintResetColours "$1")"

    }

ColourTextBrightBlue()
    {

    echo -en '\033[1;94m'"$(PrintResetColours "$1")"

    }

PrintResetColours()
    {

    echo -en "$1"'\033[0m'

    }

RemoveColourCodes()
    {

    # http://www.commandlinefu.com/commands/view/3584/remove-color-codes-special-characters-with-sed
    echo -n "$1" | $SED_BIN "s,\x1B\[[0-9;]*[a-zA-Z],,g"

    }

ShowAsFailed()
    {

    # $1 = message to show in colour if colour is set

    if [[ $colour = true ]]; then
        echo -n "$(ColourTextBrightRed "$1")"
    else
        echo -n "$1"
    fi

    }

ShowAsSucceed()
    {

    # $1 = message to show in colour if colour is set

    if [[ $colour = true ]]; then
        echo -n "$(ColourTextBrightGreen "$1")"
    else
        echo -n "$1"
    fi

    }

Uppercase()
    {

    # $1 = some text to convert to uppercase

    echo "$1" | tr "[a-z]" "[A-Z]"

    }

Lowercase()
    {

    # $1 = some text to convert to lowercase

    echo "$1" | tr "[A-Z]" "[a-z]"

    }

DisplayISO()
    {

    # show $1 formatted with 'k', 'M', 'G'

    echo $1 | awk 'BEGIN{ u[0]=""; u[1]=" k"; u[2]=" M"; u[3]=" G"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } '

    }

DisplayThousands()
    {

    # show $1 formatted with thousands separator

    printf "%'.f\n" "$1"

    }

WantedFonts()
    {

    local font_list=''

    font_list+='Century-Schoolbook-L-Bold-Italic\n'
    font_list+='Droid-Serif-Bold-Italic\n'
    font_list+='FreeSerif-Bold-Italic\n'
    font_list+='Nimbus-Roman-No9-L-Medium-Italic\n'
    font_list+='Times-BoldItalic\n'
    font_list+='URW-Palladio-L-Bold-Italic\n'
    font_list+='Utopia-Bold-Italic\n'
    font_list+='Bitstream-Charter-Bold-Italic\n'

    echo -e "$font_list"

    }

FirstPreferredFont()
    {

    local preferred_fonts=$(WantedFonts)
    local available_fonts=$($CONVERT_BIN -list font | grep "Font:" | $SED_BIN 's| Font: ||')
    local first_available_font=''

    while read preferred_font; do
        while read available_font; do
            [[ $preferred_font = $available_font ]] && break 2
        done <<< "$available_fonts"
    done <<< "$preferred_fonts"

    if [[ -n $preferred_font ]]; then
        echo "$preferred_font"
    else
        # uncomment 2nd line down to return first installed font if no preferred fonts could be found.
        # for 'convert -font' this isn't needed as it will use a default font if specified font is "".

        #read first_available_font others <<< $available_fonts

        echo "$first_available_font"
    fi

    }

#OSTYPE="darwin"

Init

case "$OSTYPE" in
    "darwin"*)
        READLINK_BIN=greadlink
        SED_BIN=gsed
        DU_BIN=gdu
        if [[ $(basename $PACKAGER_BIN) = brew ]]; then
            GETOPT_BIN="$(brew --prefix gnu-getopt)/bin/getopt" # based upon https://stackoverflow.com/a/47542834/6182835
        else
            DebugThis "! 'brew' executable" "not found"
            echo " 'brew' executable was not found!"
            echo -e "\n On this platform, you can try installing it with:"
            echo ' $ xcode-select --install && ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"'
            exit 1
        fi
        ;;
    *)
        READLINK_BIN=readlink
        SED_BIN=sed
        DU_BIN=du
        GETOPT_BIN=getopt
        ;;
esac

user_parameters=$($GETOPT_BIN -o c,C,d,D,h,L,N,q,s,S,z,a:,b:,f:i:,l:,m:,n:,o:,p:,P:,r:,R:,t:,T:,u: -l colour,condensed,debug,delete-after,help,lightning,links-only,no-gallery,quiet,save-links,skip-no-size,aspect-ratio:,border-thickness:,dimensions:,input:,failures:,lower-size:,minimum-pixels:,number:,output:,parallel:,phrase:,recent:,retries:,timeout:,title:,type:,upper-size:,usage-rights: -n $($READLINK_BIN -f -- "$0") -- "$@")
user_parameters_result=$?
user_parameters_raw="$@"

ProcEnvironment

if [[ $exitcode -eq 0 ]]; then
    if [[ -n $input_pathfile ]]; then
        while read -r file_query; do
            if [[ -n $file_query ]]; then
                if [[ $file_query != \#* ]]; then
                    user_query="$file_query"
                    ProcSingleQuery
                else
                    DebugThis '! ignoring $file_query' 'comment'
                fi
            else
                DebugThis '! ignoring $file_query' 'null'
            fi
        done < "$input_pathfile"
    else
        ProcSingleQuery
    fi
fi

Finish

exit $exitcode
