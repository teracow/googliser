#!/usr/bin/env bash
####################################################################################
# googliser.sh
#
# (C)opyright 2016-2020 Teracow Software
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
####################################################################################
# * Style Guide *
# function names: CamelCase
# forked function names: TrailingUnderscore_
# sub-function names: :LeadingColon
# variable names: lowercase_with_underscores (except for 'returncode' & 'errorcode')
# constants: UPPERCASE_WITH_UNDERSCORES
# indents: 4 x spaces
####################################################################################

# return values ($?):
#   0   completed successfully
#   1   required/alternative program unavailable (wget, curl, montage, convert, identify, brew, etc...)
#   2   required parameter unspecified or wrong
#   3   could not create output directory for 'phrase'
#   4   could not get a list of search results from Google
#   5   URL links list has been exhausted
#   6   thumbnail gallery building failed
#   7   unable to create a temporary build directory
#   8   Internet inaccessible

# debug log first characters notation:
#   >>  child process forked
#   <<  child process ended
#   \\  function entry
#   //  function exit
#   VV  variable value
#   ??  other value
#   ==  execution
#   ~~  variable was reset within bounds
#   $$  success
#   xx  warning
#   !!  failure
#   TT  elapsed time
#   ##  comment

readonly ORIGIN=$_

InitOK()
    {

    # check and log runtime environment
    # $? = 0 if OK, 1 if not

    # script constants
    local -r SCRIPT_VERSION=200212

    readonly DEBUG_FILE=debug.log
    readonly IMAGE_FILE_PREFIX=image
    readonly SCRIPT_FILE=googliser.sh
    readonly SCRIPT_STARTSECONDS=$(date +%s)
    readonly SCRIPT_VERSION_PID="v:$SCRIPT_VERSION PID:$$"
    readonly USERAGENT='--user-agent "Mozilla/5.0 (X11; Linux x86_64; rv:70.0) Gecko/20100101 Firefox/70.0"'

    # parameter default constants
    readonly GALLERY_BORDER_PIXELS_DEFAULT=30
    readonly GALLERY_THUMBNAIL_DIMENSIONS_DEFAULT=400x400
    readonly IMAGES_REQUESTED_DEFAULT=36
    readonly LOWER_SIZE_BYTES_DEFAULT=2000
    readonly PARALLEL_LIMIT_DEFAULT=64
    readonly RETRIES_DEFAULT=3
    readonly TIMEOUT_SECONDS_DEFAULT=30
    readonly UPPER_SIZE_BYTES_DEFAULT=200000

    # limits
    readonly BING_RESULTS_MAX=1000
    readonly GOOGLE_RESULTS_MAX=1000
    readonly PARALLEL_MAX=512
    readonly RETRIES_MAX=100
    readonly TIMEOUT_SECONDS_MAX=600

    # script-variables
    current_path=$PWD
    errorcode=0
    gallery_images_required=$IMAGES_REQUESTED_DEFAULT   # number of images to build gallery with. This is ideally same as $user_images_requested except when performing random (single) image download.
    image_links_file=image.links.list

    # script-variable flags
    target_path_created=false

    # user-variable parameters
    gallery_border_pixels=$GALLERY_BORDER_PIXELS_DEFAULT
    gallery_thumbnail_dimensions=$GALLERY_THUMBNAIL_DIMENSIONS_DEFAULT
    lower_size_bytes=$LOWER_SIZE_BYTES_DEFAULT
    parallel_limit=$PARALLEL_LIMIT_DEFAULT
    retries=$RETRIES_DEFAULT
    timeout_seconds=$TIMEOUT_SECONDS_DEFAULT
    upper_size_bytes=$UPPER_SIZE_BYTES_DEFAULT
    user_images_requested=$IMAGES_REQUESTED_DEFAULT

    # user-variable options
    debug=false
    exact_search=false
    gallery=false
    gallery_background_trans=false
    gallery_compact_thumbs=false
    gallery_delete_images=false
    lightning_mode=false
    links_only=false
    output_colour=true
    output_verbose=true
    random_image=false
    reindex_rename=false
    safesearch_on=true
    save_links=false
    show_help=false
    skip_no_size=false

    # user-variable strings
    exclude_links_pathfile=''
    exclude_words=''
    gallery_user_title=''
    input_links_pathfile=''
    input_phrases_pathfile=''
    output_path=''
    search_phrase=''
    sites=''
    user_phrase=''

    # user-variable presets
    aspect_ratio=''
    image_colour=''
    image_format=''
    image_type=''
    min_pixels=''
    recent=''
    usage_rights=''

    BuildWorkPaths || return 1

    DebugScriptEntry
    DebugScriptNow
    DebugScriptVal version "$SCRIPT_VERSION"
    DebugScriptVal PID "$$"

    FindLauncher
    FindPackageManager || return 1
    FindGNUUtils || return 1

    user_parameters=$($GETOPT_BIN -o d,E,G,h,L,q,s,S,z,a:,b:,i:,l:,m:,n:,o:,p:,P:,r:,R:,t:,T:,u: -l debug,exact-search,help,lightning,links-only,no-colour,no-color,safesearch-off,quiet,random,reindex-rename,save-links,skip-no-size,aspect-ratio:,border-pixels:,colour:,color:,exclude-links:,exclude-words:,format:,gallery:,input-links:,input-phrases:,lower-size:,minimum-pixels:,number:,output:,parallel:,phrase:,recent:,retries:,sites:,thumbnails:,timeout:,title:,type:,upper-size:,usage-rights: -n "$LAUNCHER" -- "$@")
    user_parameters_result=$?
    # shellcheck disable=SC2034
    user_parameters_raw=$*

    # shellcheck disable=SC2119
    WhatAreMyArgs
    ShowHelp || return 1
    ShowTitle
    [[ $output_verbose = true ]] && echo
    ValidateScriptParameters || return 1

    if [[ $errorcode -eq 0 ]]; then
        DebugFuncComment 'runtime parameters after validation and adjustment'
        DebugFuncVar aspect_ratio
        DebugFuncVar debug
        DebugFuncVar exact_search
        DebugFuncVar exclude_links_pathfile
        DebugFuncVar exclude_words
        DebugFuncVar image_colour
        DebugFuncVar image_format
        DebugFuncVar image_type
        DebugFuncVar input_links_pathfile
        DebugFuncVar input_phrases_pathfile
        DebugFuncVar gallery
        DebugFuncVar gallery_background_trans
        DebugFuncVar gallery_border_pixels
        DebugFuncVar gallery_compact_thumbs
        DebugFuncVar gallery_delete_images
        DebugFuncVar gallery_images_required
        DebugFuncVar gallery_thumbnail_dimensions
        DebugFuncVar gallery_user_title
        DebugFuncVar lightning_mode
        DebugFuncVar links_only
        DebugFuncVar lower_size_bytes
        DebugFuncVar min_pixels
        DebugFuncVar output_colour
        DebugFuncVar output_path
        DebugFuncVar output_verbose
        DebugFuncVar parallel_limit
        DebugFuncVar random_image
        DebugFuncVar recent
        DebugFuncVar reindex_rename
        DebugFuncVar retries
        DebugFuncVar safesearch_on
        DebugFuncVar save_links
        DebugFuncVar sites
        DebugFuncVar skip_no_size
        DebugFuncVar timeout_seconds
        DebugFuncVar upper_size_bytes
        DebugFuncVar user_phrase
        DebugFuncVar usage_rights
        DebugFuncVar user_images_requested
        DebugFuncComment 'internal parameters'
        DebugFuncVar BING_RESULTS_MAX
        DebugFuncVar GOOGLE_RESULTS_MAX
        DebugFuncVar ORIGIN
        DebugFuncVar OSTYPE
        DebugFuncVar TEMP_PATH

        FindDownloader || return 1
        FindImageMagick || return 1

        trap CTRL_C_Captured INT
    fi

    return 0

    }

BuildWorkPaths()
    {

    # $? = 0 if OK, 1 if not

    local OK=false

    while true; do      # yes, it's a single-run loop - easier to abort when things go wrong
        TEMP_PATH=$(mktemp -d "/tmp/${SCRIPT_FILE%.*}.$$.XXX") || break

        page_run_count_path=$TEMP_PATH/pages.running.count
        mkdir -p "$page_run_count_path" || break

        page_success_count_path=$TEMP_PATH/pages.success.count
        mkdir -p "$page_success_count_path" || break

        page_fail_count_path=$TEMP_PATH/pages.fail.count
        mkdir -p "$page_fail_count_path" || break

        page_abort_count_path=$TEMP_PATH/pages.abort.count
        mkdir -p "$page_abort_count_path" || break

        image_run_count_path=$TEMP_PATH/images.running.count
        mkdir -p "$image_run_count_path" || break

        image_success_count_path=$TEMP_PATH/images.success.count
        mkdir -p "$image_success_count_path" || break

        image_fail_count_path=$TEMP_PATH/images.fail.count
        mkdir -p "$image_fail_count_path" || break

        image_abort_count_path=$TEMP_PATH/images.abort.count
        mkdir -p "$image_abort_count_path" || break

        image_sizetest_pathfile=$TEMP_PATH/test-image-size
        pages_pathfile=$TEMP_PATH/page.html
        gallery_title_pathfile=$TEMP_PATH/gallery.title.png
        gallery_thumbnails_pathfile=$TEMP_PATH/gallery.thumbnails.png
        gallery_background_pathfile=$TEMP_PATH/gallery.background.png
        image_links_pathfile=$TEMP_PATH/$image_links_file
        debug_pathfile=$TEMP_PATH/$DEBUG_FILE

        OK=true
        break
    done

    if [[ $OK = false ]]; then
        ShowFail 'Unable to create a temporary build directory'
        errorcode=7
        return 1
    fi

    return 0

    }

WhatAreMyArgs()
    {

    DebugFuncVar user_parameters_raw

    eval set -- "$user_parameters"

    while true; do
        case $1 in
            --aspect-ratio|-a)
                aspect_ratio=$2
                shift 2
                ;;
            --border-pixels|-b)
                gallery_border_pixels=$2
                gallery=true
                shift 2
                ;;
            --colour|--color)
                image_colour=$2
                shift 2
                ;;
            --debug|-d)
                debug=true
                shift
                ;;
            --exact-search|-E)
                exact_search=true
                shift
                ;;
            --exclude-links)
                exclude_links_pathfile=$2
                shift 2
                ;;
            --exclude-words)
                exclude_words=$2
                shift 2
                ;;
            --format)
                image_format=$2
                shift 2
                ;;
            -G)
                gallery=true
                shift
                ;;
            --gallery)
                case $2 in
                    background-trans)
                        gallery_background_trans=true
                        ;;
                    compact)
                        gallery_compact_thumbs=true
                        ;;
                    delete-after)
                        gallery_delete_images=true
                        ;;
                esac
                gallery=true
                shift 2
                ;;
            --help|-h)
                show_help=true
                errorcode=2
                return 1
                ;;
            --input-links)
                input_links_pathfile=$2
                shift 2
                ;;
            --input-phrases|-i)
                input_phrases_pathfile=$2
                shift 2
                ;;
            --lightning|-z)
                lightning_mode=true
                shift
                ;;
            --links-only|-L)
                links_only=true
                shift
                ;;
            --lower-size|-l)
                lower_size_bytes=$2
                shift 2
                ;;
            --minimum-pixels|-m)
                min_pixels=$2
                shift 2
                ;;
            --no-colour|--no-color)
                output_colour=false
                shift
                ;;
            --number|-n)
                user_images_requested=$2
                shift 2
                ;;
            --output|-o)
                output_path=$2
                shift 2
                ;;
            --parallel|-P)
                parallel_limit=$2
                shift 2
                ;;
            --phrase|-p)
                user_phrase=$2
                shift 2
                ;;
            --quiet|-q)
                output_verbose=false
                shift
                ;;
            --random)
                random_image=true
                shift
                ;;
            --recent|-R)
                recent=$2
                shift 2
                ;;
            --reindex-rename)
                reindex_rename=true
                shift
                ;;
            --retries|-r)
                retries=$2
                shift 2
                ;;
            --safesearch-off)
                safesearch_on=false
                shift
                ;;
            --save-links|-s)
                save_links=true
                shift
                ;;
            --sites)
                sites=$2
                shift 2
                ;;
            --skip-no-size|-S)
                skip_no_size=true
                shift
                ;;
            --thumbnails)
                gallery_thumbnail_dimensions=$2
                shift 2
                ;;
            --timeout|-t)
                timeout_seconds=$2
                shift 2
                ;;
            --title|-T)
                if [[ $(Lowercase "$2") = none ]]; then
                    gallery_user_title=none
                else
                    gallery_user_title=$2
                fi
                shift 2
                ;;
            --type)
                image_type=$2
                shift 2
                ;;
            --upper-size|-u)
                upper_size_bytes=$2
                shift 2
                ;;
            --usage-rights)
                usage_rights=$2
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

ShowHelp()
    {

    # $? = 0 if OK, 1 if not

    if [[ $user_parameters_result -ne 0 || $user_parameters = ' --' ]]; then
        ShowBasicHelp
        errorcode=2
        return 1
    fi

    if [[ $show_help = true ]]; then
        if (command -v less >/dev/null); then
            ShowExtendedHelp | LESSSECURE=1 less -rMK -PM' use arrow-keys to scroll up-down left-right, press Q to quit'
        elif (command -v more >/dev/null); then
            ShowExtendedHelp | more -d
        else
            ShowExtendedHelp
        fi
        return 1
    fi

    return 0

    }

ShowBasicHelp()
    {

    ShowTitle

    echo
    echo " Search '$(ShowGoogle) $(ColourTextBrightBlue images)' then download a number of images matching a phrase"
    echo
    echo " Usage: $(ColourTextBold "$LAUNCHER") -p [TEXT] -dEGhLqsSz [PARAMETERS] FILE,PATH,TEXT,INTEGER,PRESET ..."

    }

ShowExtendedHelp()
    {

    local SAMPLE_USER_PHRASE=cows

    ShowBasicHelp

    echo
    echo " External requirements: Wget or cURL"
    echo " and optionally: identify, montage & convert (from ImageMagick)"
    echo
    echo " Questions or comments? teracow@gmail.com"
    echo
    echo " Mandatory arguments for long options are mandatory for short options too."
    echo
    FormatHelpSection Required
    FormatHelpLine p phrase string "Search for images Google identifies with this phrase. Enclose whitespace in quotes. A sub-directory will be created with this name, unless '--output' is specified."
    echo
    FormatHelpSection Optional
    FormatHelpLine a aspect-ratio preset 'Search for images with this aspect-ratio.'
    FormatHelpLine example '--aspect-ratio square'
    FormatHelpLine 'presets:'
    FormatHelpLine preset tall
    FormatHelpLine preset square
    FormatHelpLine preset wide
    FormatHelpLine preset panoramic
    FormatHelpLine b border-pixels integer 'Thickness of border surrounding gallery image in pixels.'
    FormatHelpLine default "$GALLERY_BORDER_PIXELS_DEFAULT"
    FormatHelpLine disable 0
    FormatHelpLine 'colour|color' preset 'The dominant image colour.'
    FormatHelpLine example '--colour green'
    FormatHelpLine 'presets:'
    FormatHelpLine preset any
    FormatHelpLine preset 'full (colour images only)'
    FormatHelpLine preset black-white
    FormatHelpLine preset bw
    FormatHelpLine preset transparent
    FormatHelpLine preset clear
    FormatHelpLine preset red
    FormatHelpLine preset orange
    FormatHelpLine preset yellow
    FormatHelpLine preset green
    FormatHelpLine preset teal
    FormatHelpLine preset cyan
    FormatHelpLine preset blue
    FormatHelpLine preset purple
    FormatHelpLine preset magenta
    FormatHelpLine preset pink
    FormatHelpLine preset white
    FormatHelpLine preset gray
    FormatHelpLine preset grey
    FormatHelpLine preset black
    FormatHelpLine preset brown
    FormatHelpLine d debug option "Save the runtime debug log [$DEBUG_FILE] into output directory."
    FormatHelpLine E exact-search option 'Perform an exact-phrase search only. Disregard Google suggestions and loose matches.'
    FormatHelpLine default 'loose search'
    FormatHelpLine exclude-links file "The URLs for images successfully downloaded will be appended to this file (if specified). Specify this file again to ensure these URLs are not reused."
    FormatHelpLine exclude-words string 'A comma-separated list (without spaces) of words that you want to exclude from the search.'
    FormatHelpLine format preset 'Only download images encoded in this file format.'
    FormatHelpLine example '--format svg'
    FormatHelpLine 'presets:'
    FormatHelpLine preset jpg
    FormatHelpLine preset png
    FormatHelpLine preset gif
    FormatHelpLine preset bmp
    FormatHelpLine preset svg
    FormatHelpLine preset webp
    FormatHelpLine preset ico
    FormatHelpLine preset craw
    FormatHelpLine G gallery option 'Download images, then create a thumbnail gallery.'
    FormatHelpLine gallery= preset 'As above, and apply one of the following modifiers:'
    FormatHelpLine '--gallery=background-trans   (use a transparent background in the gallery image)'
    FormatHelpLine '--gallery=compact            (create a condensed thumbnail gallery - no tile-padding between thumbnails)'
    FormatHelpLine '--gallery=delete-after       (remove all downloaded images after building thumbnail gallery)'
    FormatHelpLine h help option 'Display this help.'
    FormatHelpLine input-links file 'Download each URL as listed in this text-file, one URL per line. A Google search will not be performed.'
    FormatHelpLine i input-phrases file 'A text file containing a list of phrases to download, one phrase per line.'
    FormatHelpLine l lower-size integer 'Only download images that are larger than this many bytes.'
    FormatHelpLine default "$LOWER_SIZE_BYTES_DEFAULT"
    FormatHelpLine L links-only option "Compile a list of image URLs, but don't download any images."
    FormatHelpLine m minimum-pixels preset 'Images must contain at least this many pixels.'
    FormatHelpLine example '-m 8mp'
    FormatHelpLine 'presets:'
    FormatHelpLine preset icon
    FormatHelpLine preset medium
    FormatHelpLine preset large
    FormatHelpLine preset 'qsvga (400 x 300)'
    FormatHelpLine preset 'vga   (640 x 480)'
    FormatHelpLine preset 'svga  (800 x 600)'
    FormatHelpLine preset 'xga   (1024 x 768)'
    FormatHelpLine preset '2mp   (1600 x 1200)'
    FormatHelpLine preset '4mp   (2272 x 1704)'
    FormatHelpLine preset '6mp   (2816 x 2112)'
    FormatHelpLine preset '8mp   (3264 x 2448)'
    FormatHelpLine preset '10mp  (3648 x 2736)'
    FormatHelpLine preset '12mp  (4096 x 3072)'
    FormatHelpLine preset '15mp  (4480 x 3360)'
    FormatHelpLine preset '20mp  (5120 x 3840)'
    FormatHelpLine preset '40mp  (7216 x 5412)'
    FormatHelpLine preset '70mp  (9600 x 7200)'
    FormatHelpLine n number integer 'Number of images to download.'
    FormatHelpLine default "$IMAGES_REQUESTED_DEFAULT"
    FormatHelpLine maximum "$GOOGLE_RESULTS_MAX"
    FormatHelpLine no-colour option 'Runtime display will be in boring, uncoloured text. :('
    FormatHelpLine safesearch-off option "Disable Google's SafeSearch content-filtering."
    FormatHelpLine default on
    FormatHelpLine o output path "The image output directory. Enclose whitespace in quotes."
    FormatHelpLine default phrase
    FormatHelpLine P parallel integer 'How many parallel image downloads?'
    FormatHelpLine default "$PARALLEL_LIMIT_DEFAULT"
    FormatHelpLine maximum "$PARALLEL_MAX"
    FormatHelpLine q quiet option 'Suppress stdout. stderr is still shown.'
    FormatHelpLine random option 'Download a single, random image.'
    FormatHelpLine R recent preset 'Only get images published this far back in time.'
    FormatHelpLine example '--recent month'
    FormatHelpLine 'presets:'
    FormatHelpLine preset any
    FormatHelpLine preset hour
    FormatHelpLine preset day
    FormatHelpLine preset week
    FormatHelpLine preset month
    FormatHelpLine preset year
    FormatHelpLine reindex-rename option 'Reindex and rename downloaded image files into a contiguous block.'
    FormatHelpLine r retries integer 'Retry each image download this many times.'
    FormatHelpLine default "$RETRIES_DEFAULT"
    FormatHelpLine maximum "$RETRIES_MAX"
    FormatHelpLine s save-links option "Save image URL list to file [$image_links_file] into the output directory."
    FormatHelpLine sites string 'A comma separated list (without spaces) of sites or domains from which you want to search the images.'
    FormatHelpLine S skip-no-size option "Don't download any image if its size cannot be determined before fetching from server."
    FormatHelpLine thumbnails string 'Ensure each gallery thumbnail is not larger than: width x height.'
    FormatHelpLine example '--thumbnails 200x100'
    FormatHelpLine default "$GALLERY_THUMBNAIL_DIMENSIONS_DEFAULT"
    FormatHelpLine t timeout integer 'Number of seconds before aborting each image download.'
    FormatHelpLine default "$TIMEOUT_SECONDS_DEFAULT"
    FormatHelpLine maximum "$TIMEOUT_SECONDS_MAX"
    FormatHelpLine T title string 'Title for thumbnail gallery image. Enclose whitespace in quotes.'
    FormatHelpLine default phrase
    FormatHelpLine disable none
    FormatHelpLine type preset 'Image category type.'
    FormatHelpLine example '--type clipart'
    FormatHelpLine 'presets:'
    FormatHelpLine preset face
    FormatHelpLine preset photo
    FormatHelpLine preset clipart
    FormatHelpLine preset lineart
    FormatHelpLine preset animated
    FormatHelpLine u upper-size integer 'Only download images that are smaller than this many bytes.'
    FormatHelpLine default "$UPPER_SIZE_BYTES_DEFAULT"
    FormatHelpLine unlimited 0
    FormatHelpLine usage-rights preset 'Original image usage-rights.'
    FormatHelpLine example '--usage-rights reuse'
    FormatHelpLine 'presets:'
    FormatHelpLine preset reuse
    FormatHelpLine preset reuse-with-mod
    FormatHelpLine preset noncomm-reuse
    FormatHelpLine preset noncomm-reuse-with-mod
    FormatHelpLine z lightning option "Download images even faster by using an optimised set of parameters. For when you really can't wait!"
    echo
    echo " example:"
    echo
    ColourTextBold " $ $LAUNCHER -p '$SAMPLE_USER_PHRASE'"; echo
    echo
    echo " This will download the first $IMAGES_REQUESTED_DEFAULT images available for the phrase '$SAMPLE_USER_PHRASE'."

    }

ValidateScriptParameters()
    {

    # $? = 0 if OK, 1 if not

    local OK=false

    if [[ $links_only = true ]]; then
        gallery=false
        save_links=true
    fi

    if [[ $gallery_compact_thumbs = true || $gallery_background_trans = true || $gallery_delete_images = true ]]; then
        gallery=true
    fi

    if [[ $lightning_mode = true ]]; then
        # Yeah!
        timeout_seconds=1
        retries=0
        skip_no_size=true
        parallel_limit=$PARALLEL_MAX
        links_only=false
        gallery=false
    fi

    while true; do
        if [[ -n $input_links_pathfile && $links_only = true && $save_links = true ]]; then
            echo " Let's review. Your chosen options will:"
            echo " 1. use an input file with a list of URL links,"
            echo " 2. don't download any images,"
            echo " 3. save the URL links list to file."
            echo " So... I've nothing to do. Might be time to (R)ead-(T)he-(M)anual. ;)"
            break
        fi

        case ${user_images_requested#[-+]} in
            *[!0-9]*)
                DebugScriptFail 'specified $user_images_requested is invalid'
                ShowFailInvalidInteger '-n, --number'
                break
                ;;
            *)
                if [[ $user_images_requested -lt 1 ]]; then
                    user_images_requested=1
                    DebugFuncVarAdjust '$user_images_requested TOO LOW so set to a sensible minimum' "$user_images_requested"
                fi

                if [[ $user_images_requested -gt $GOOGLE_RESULTS_MAX ]]; then
                    user_images_requested=$GOOGLE_RESULTS_MAX
                    DebugFuncVarAdjust '$user_images_requested TOO HIGH so set as $GOOGLE_RESULTS_MAX' "$user_images_requested"
                fi
                ;;
        esac

        if [[ $random_image = true ]]; then
            gallery_images_required=1
        else
            gallery_images_required=$user_images_requested
        fi

        if [[ -n $input_links_pathfile ]]; then
            if [[ ! -e $input_links_pathfile ]]; then
                DebugScriptFail '$input_links_pathfile was not found'
                ShowFailMissingFile '--input-links'
                break
            fi
        fi

        if [[ -n $input_phrases_pathfile ]]; then
            if [[ ! -e $input_phrases_pathfile ]]; then
                DebugScriptFail '$input_phrases_pathfile was not found'
                ShowFailMissingFile '-i, --input-phrases'
                break
            fi
        fi

        if [[ -n $exclude_links_pathfile ]]; then
            [[ ! -e $exclude_links_pathfile ]] && touch "$exclude_links_pathfile"
        fi

        case ${parallel_limit#[-+]} in
            *[!0-9]*)
                DebugScriptFail 'specified $parallel_limit is invalid'
                ShowFailInvalidInteger '-P, --parallel'
                break
                ;;
            *)
                if [[ $parallel_limit -lt 1 ]]; then
                    parallel_limit=$PARALLEL_MAX
                    DebugFuncVarAdjust '$parallel_limit SET TO MAX' "$parallel_limit"
                fi

                if [[ $parallel_limit -gt $PARALLEL_MAX ]]; then
                    parallel_limit=$PARALLEL_MAX
                    DebugFuncVarAdjust '$parallel_limit TOO HIGH so set as' "$parallel_limit"
                fi
                ;;
        esac

        case ${timeout_seconds#[-+]} in
            *[!0-9]*)
                DebugScriptFail 'specified $timeout_seconds is invalid'
                ShowFailInvalidInteger '-t, --timeout'
                break
                ;;
            *)
                if [[ $timeout_seconds -lt 1 ]]; then
                    timeout_seconds=1
                    DebugFuncVarAdjust '$timeout_seconds TOO LOW so set as' "$timeout_seconds"
                fi

                if [[ $timeout_seconds -gt $TIMEOUT_SECONDS_MAX ]]; then
                    timeout_seconds=$TIMEOUT_SECONDS_MAX
                    DebugFuncVarAdjust '$timeout_seconds TOO HIGH so set as' "$timeout_seconds"
                fi
                ;;
        esac

        case ${retries#[-+]} in
            *[!0-9]*)
                DebugScriptFail 'specified $retries is invalid'
                ShowFailInvalidInteger '-r, --retries'
                break
                ;;
            *)
                if [[ $retries -lt 0 ]]; then
                    retries=0
                    DebugFuncVarAdjust '$retries TOO LOW so set as' "$retries"
                fi

                if [[ $retries -gt $RETRIES_MAX ]]; then
                    retries=$RETRIES_MAX
                    DebugFuncVarAdjust '$retries TOO HIGH so set as' "$retries"
                fi
                ;;
        esac

        case ${upper_size_bytes#[-+]} in
            *[!0-9]*)
                DebugScriptFail 'specified $upper_size_bytes is invalid'
                ShowFailInvalidInteger '-u, --upper-size'
                break
                ;;
            *)
                if [[ $upper_size_bytes -lt 0 ]]; then
                    upper_size_bytes=0
                    DebugFuncVarAdjust '$upper_size_bytes TOO LOW so set as' "$upper_size_bytes (unlimited)"
                fi
                ;;
        esac

        case ${lower_size_bytes#[-+]} in
            *[!0-9]*)
                DebugScriptFail 'specified $lower_size_bytes is invalid'
                ShowFailInvalidInteger '-l, --lower-size'
                break
                ;;
            *)
                if [[ $lower_size_bytes -lt 0 ]]; then
                    lower_size_bytes=0
                    DebugFuncVarAdjust '$lower_size_bytes TOO LOW so set as' "$lower_size_bytes"
                fi

                if [[ $upper_size_bytes -gt 0 && $lower_size_bytes -gt $upper_size_bytes ]]; then
                    lower_size_bytes=$((upper_size_bytes-1))
                    DebugFuncVarAdjust "\$lower_size_bytes larger than \$upper_size_bytes ($upper_size_bytes) so set as" "$lower_size_bytes"
                fi
                ;;
        esac

        case ${gallery_border_pixels#[-+]} in
            *[!0-9]*)
                DebugScriptFail 'specified $gallery_border_pixels is invalid'
                ShowFailInvalidInteger '-b, --border-pixels'
                break
                ;;
            *)
                if [[ $gallery_border_pixels -lt 0 ]]; then
                    gallery_border_pixels=0
                    DebugFuncVarAdjust '$gallery_border_pixels TOO LOW so set as' "$gallery_border_pixels"
                fi
                ;;
        esac

        OK=true
        break
    done

    if [[ $OK = false ]]; then
        errorcode=2
        return 1
    fi

    return 0

    }

ValidateGoogleParameters()
    {

    # all elements of Google's URL syntax should be validated and calculated here, except for 'start page' and 'result index'. These will be added later.
    # $? = 0 if OK, 1 if not

    compiled_query_parameters=''           # query string without 'start page' and 'result index'

    local -r SERVER='https://www.google.com'
    local -r SAFE_SEARCH_QUERY="&q=$safe_search_phrase"
    local -r SEARCH_TYPE='&tbm=isch'        # search for images
    local -r SEARCH_LANGUAGE='&hl=en'       # language
    local -r SEARCH_STYLE='&site=imghp'     # result layout style
    local -r SEARCH_SIMILAR='&filter=0'     # don't omit similar results

    local aspect_ratio_type=''
    local aspect_ratio_search=''
    local image_colour_type=''
    local image_colour_search=''
    local image_type_search=''
    local image_format_search=''
    local min_pixels_type=''
    local min_pixels_search=''
    local recent_type=''
    local recent_search=''
    local usage_rights_type=''
    local usage_rights_search=''

    local search_match_type='&nfpr='        # exact or loose (suggested) search
    local OK=false

    if [[ $exact_search = true ]]; then
        search_match_type+=1
    else
        search_match_type+=0
    fi

    local safesearch_flag='&safe='          # Google's SafeSearch content filter

    if [[ $safesearch_on = true ]]; then
        safesearch_flag+=active
    else
        safesearch_flag+=inactive
    fi

    while true; do
        if [[ -n $min_pixels ]]; then
            case "$min_pixels" in
                qsvga|vga|svga|xga|2mp|4mp|6mp|8mp|10mp|12mp|15mp|20mp|40mp|70mp)
                    min_pixels_type=lt,islt:$min_pixels
                    ;;
                large)
                    min_pixels_type=l
                    ;;
                medium)
                    min_pixels_type=m
                    ;;
                icon)
                    min_pixels_type=i
                    ;;
                *)
                    DebugScriptFail 'specified $min_pixels is invalid'
                    ShowFailInvalidPreset '-m, --minimum-pixels'
                    break
                    ;;
            esac
            [[ -n $min_pixels_type ]] && min_pixels_search=isz:$min_pixels_type
        fi

        if [[ -n $aspect_ratio ]]; then
            case "$aspect_ratio" in
                tall)
                    aspect_ratio_type=t
                    ;;
                square)
                    aspect_ratio_type=s
                    ;;
                wide)
                    aspect_ratio_type=w
                    ;;
                panoramic)
                    aspect_ratio_type=xw
                    ;;
                *)
                    DebugScriptFail 'specified $aspect_ratio is invalid'
                    ShowFailInvalidPreset '-a, --aspect-ratio'
                    break
                    ;;
            esac
            [[ -n $aspect_ratio_type ]] && aspect_ratio_search=iar:$aspect_ratio_type
        fi

        if [[ -n $image_type ]]; then
            case "$image_type" in
                face|photo|clipart|lineart|animated)
                    image_type_search=itp:$image_type
                    ;;
                *)
                    DebugScriptFail 'specified $image_type is invalid'
                    ShowFailInvalidPreset '--type'
                    break
                    ;;
            esac
        fi

        if [[ -n $image_format ]]; then
            case "$image_format" in
                png|jpg|gif|bmp|svg|ico|webp|craw)
                    image_format_search=ift:$image_format
                    ;;
                *)
                    DebugScriptFail 'specified $image_format is invalid'
                    ShowFailInvalidPreset '--format'
                    break
                    ;;
            esac
        fi

        if [[ -n $usage_rights ]]; then
            case "$usage_rights" in
                reuse-with-mod)
                    usage_rights_type=fmc
                    ;;
                reuse)
                    usage_rights_type=fc
                    ;;
                noncomm-reuse-with-mod)
                    usage_rights_type=fm
                    ;;
                noncomm-reuse)
                    usage_rights_type=f
                    ;;
                *)
                    DebugScriptFail 'specified $usage_rights is invalid'
                    ShowFailInvalidPreset '--usage-rights'
                    break
                    ;;
            esac
            [[ -n $usage_rights_type ]] && usage_rights_search=sur:$usage_rights_type
        fi

        if [[ -n $recent ]]; then
            case "$recent" in
                any)
                    recent_type=''
                    ;;
                hour)
                    recent_type=h
                    ;;
                day)
                    recent_type=d
                    ;;
                week)
                    recent_type=w
                    ;;
                month)
                    recent_type=m
                    ;;
                year)
                    recent_type=y
                    ;;
                *)
                    DebugScriptFail 'specified $recent is invalid'
                    ShowFailInvalidPreset '--recent'
                    break
                    ;;
            esac
            [[ -n $recent_type ]] && recent_search=qdr:$recent_type
        fi

        if [[ -n $image_colour ]]; then
            case "$image_colour" in
                any)
                    image_colour_type=''
                    ;;
                full)
                    image_colour_type=color
                    ;;
                black-white|bw)
                    image_colour_type=gray
                    ;;
                transparent|clear)
                    image_colour_type=trans
                    ;;
                red|orange|yellow|green|teal|blue|purple|pink|white|gray|black|brown)
                    image_colour_type=specific,isc:$image_colour
                    ;;
                cyan)
                    image_colour_type=specific,isc:teal
                    ;;
                magenta)
                    image_colour_type=specific,isc:purple
                    ;;
                grey)
                    image_colour_type=specific,isc:gray
                    ;;
                *)
                    DebugScriptFail 'specified $image_colour is invalid'
                    ShowFailInvalidPreset '--colour, --color'
                    break
                    ;;
            esac
            [[ -n $image_colour_type ]] && image_colour_search=ic:$image_colour_type
        fi

        if [[ -n $min_pixels_search || -n $aspect_ratio_search || -n $image_type_search || -n $image_format_search || -n $usage_rights_search || -n $recent_search || -n $image_colour_search ]]; then
            advanced_search="&tbs=$min_pixels_search,$aspect_ratio_search,$image_type_search,$image_format_search,$usage_rights_search,$recent_search,$image_colour_search"
        fi

        compiled_query_parameters="$SERVER/search?${SEARCH_TYPE}${search_match_type}${SEARCH_SIMILAR}${SAFE_SEARCH_QUERY}${SEARCH_LANGUAGE}${SEARCH_STYLE}${advanced_search}${safesearch_flag}"

        OK=true
        break
    done

    if [[ $OK = false ]]; then
        errorcode=2
        return 1
    fi

    return 0

    }

FinalizeSearchPhrase()
    {

    search_phrase=$1

    IFS=',' read -r -a array <<< "$exclude_words"
    for element in "${array[@]}"
    do
        search_phrase+=" -${element}"
    done

    if [[ -n "$sites" ]]
    then
        IFS=',' read -r -a array <<< "$sites"
        for element in "${array[@]}"
        do
        search_phrase+=" -site:${element} OR"
        done
        search_phrase=${search_phrase%???}
    fi

    }

ProcessPhrase()
    {

    # this function:
    #   searches for a phrase,
    #   creates a URL list,
    #   downloads each image from URL list,
    #   builds a gallery from these downloaded images if requested.

    # $1 = phrase to search for. Enclose whitespace in quotes.
    # $? = 0 if OK, 1 if not

    DebugFuncEntry

    local func_startseconds=$(date +%s)

    DebugFuncComment 'user phrase parameters'

    if [[ -z $1 ]]; then
        DebugFuncFail phrase unspecified
        ShowFail 'search phrase (-p, --phrase) unspecified'
        errorcode=2
        return 1
    fi

    FinalizeSearchPhrase "$1"
    safe_search_phrase=${search_phrase// /+}  # replace whitepace with '+' to suit curl/wget
    DebugFuncVar safe_search_phrase

    if [[ -z $output_path ]]; then
        target_path=$current_path/$1
    else
        if [[ -n $input_phrases_pathfile ]]; then
            target_path=$output_path/$1
        else
            target_path=$output_path
        fi
    fi

    DebugFuncVar target_path

    ValidateGoogleParameters
    CreateTargetPath
    GetGooglePages
    ScrapeGoogleForLinks
    ExamineLinks || errorcode=4
    GetImages || errorcode=5
    ReindexRename
    RenderGallery || errorcode=6
    SaveLinks

    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return 0

    }

ProcessLinkList()
    {

    # This function:
    #   downloads each image from URL list,
    #   builds a gallery from these downloaded images if requested.

    DebugFuncEntry

    local func_startseconds=$(date +%s)
    image_links_pathfile=$input_links_pathfile

    [[ $output_verbose = true ]] && echo

    if [[ -n $output_path ]]; then
        target_path=$output_path
    else
        if [[ -n $gallery_user_title && $gallery_user_title != none ]]; then
            target_path=$gallery_user_title
        elif [[ -n $user_phrase ]]; then
            target_path=$user_phrase
        else
            target_path=$(date +%s)
        fi
    fi

    DebugFuncVar target_path

    CreateTargetPath
    GetImages || errorcode=5
    ReindexRename
    RenderGallery || errorcode=6

    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return 0

    }

CreateTargetPath()
    {

    # ensure target path exists

    if [[ -e $target_path ]]; then
        DebugFuncSuccess 'target path already exists'
    else
        mkdir -p "$target_path"
        result=$?
        if [[ $result -gt 0 ]]; then
            DebugFuncFail 'create target path' "failed! mkdir returned: ($result)"
            ShowFail 'Unable to create target path'
            errorcode=3
            return 1
        else
            DebugFuncSuccess 'create target path'
            target_path_created=true
        fi
    fi

    return 0

    }

GetGooglePages()
    {

    [[ $errorcode -ne 0 ]] && return 0

    DebugFuncEntry

    local func_startseconds=$(date +%s)
    local pages_max=$((GOOGLE_RESULTS_MAX/100))
    local run_count=0
    local success_count=0
    local fail_count=0
    local abort_count=0
    local max_run_count=0
    local page=0
    local page_index=0

    [[ $output_verbose = true ]] && echo -n "   $(ShowGoogle): "

    InitProgress
    ResetPageCounts

    for ((page=1; page<=pages_max; page++)); do
        # wait here until a download slot becomes available
        while [[ $run_count -eq $parallel_limit ]]; do
            sleep 0.5

            RefreshPageCounts; ShowAcquisitionProgress 'web pages' $pages_max $pages_max
        done

        page_index=$(printf "%02d" $page)

        # create run file here as it takes too long to happen in background function
        touch "$page_run_count_path/$page_index"
        { GetGooglePage_ "$page" "$page_index" & } 2>/dev/null

        RefreshPageCounts; ShowAcquisitionProgress 'web pages' $pages_max $pages_max
    done

    # wait here while all running downloads finish
    wait 2>/dev/null

    RefreshPageCounts; ShowAcquisitionProgress 'web pages' $pages_max $pages_max; [[ $output_verbose = true ]] && echo

    DebugFuncVal 'pages OK' "$success_count"
    DebugFuncVal 'pages failed' "$fail_count"
    DebugFuncVal 'pages aborted' "$abort_count"

    # build all pages into a single file
    cat "$pages_pathfile".* > "$pages_pathfile"

    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return 0

    }

GetGooglePage_()
    {

    # * This function runs as a forked process *
    # $1 = page to load           e.g. 0, 1, 2, 3, etc...
    # $2 = debug index identifier       e.g. (02)

    :DownloadGooglePage()
        {

        # echo = downloader stdout & stderr
        # $? = downloader return code

        local compiled_query="${compiled_query_parameters}&ijn=$((page-1))&start=$(((page-1)*100))"
        local runcmd=''

        if [[ $(basename "$DOWNLOADER_BIN") = wget ]]; then
            runcmd="$DOWNLOADER_BIN --timeout $timeout_seconds --tries $((retries+1)) \"${compiled_query}\" $USERAGENT --output-document \"${targetpage_pathfile}\""
        elif [[ $(basename "$DOWNLOADER_BIN") = curl ]]; then
            runcmd="$DOWNLOADER_BIN --max-time $timeout_seconds --retry $retries \"${compiled_query}\" $USERAGENT --output \"${targetpage_pathfile}\""
        else
            DebugFuncFail 'unknown downloader' 'out-of-ideas'
            return 1
        fi

        DebugChildExec "get page" "$runcmd"

        eval "$runcmd" 2>&1

        }

    local page=$1
    local page_index=$2
    _forkname_=$(FormatFuncSearch "${FUNCNAME[0]}" "$page_index")      # global: used by various debug logging functions
    local response=''
    local section=''
    local action=''
    local download_ok=''
    local get_page_result=0
    local func_startseconds=$(date +%s)

    DebugChildForked

    local run_pathfile=$page_run_count_path/$page_index
    local success_pathfile=$page_success_count_path/$page_index
    local fail_pathfile=$page_fail_count_path/$page_index

    local targetpage_pathfile="$pages_pathfile.$page"

    section='mid-download'
    action='download page'
    response=$(:DownloadGooglePage)
    get_page_result=$?
    UpdateRunLog "$section" "$action" "$response" "$get_page_result" "$(DownloaderReturnCodes "$get_page_result")"

    if [[ $get_page_result -eq 0 ]]; then
        download_ok=true
        DebugChildSuccess 'get page'
    else
        download_ok=false
        MoveToFail
        DebugChildFail "downloader returned \"$get_page_result: $(DownloaderReturnCodes "$get_page_result")\""
    fi

    section='post-download'

    if [[ $download_ok = true ]]; then
        action='check local page file size'
        actual_size=$(wc -c < "$targetpage_pathfile"); actual_size=${actual_size##* }

        DebugChildVal "$section" "$(DisplayThousands "$actual_size") bytes"

        if [[ $actual_size -eq 0 ]]; then
            UpdateRunLog "$section" "$action" '0' '1' 'empty file'
            MoveToFail
            DebugChildFail "$action = zero bytes"
        else
            UpdateRunLog "$section" "$action" "$actual_size" '0' 'OK'
            MoveToSuccess
            DebugChildSuccess "$action"
        fi
    else
        MoveToFail
    fi

    DebugChildElapsedTime "$func_startseconds"
    DebugChildEnded

    return 0

    }

GetImages()
    {

    [[ $errorcode -ne 0 || $links_only = true ]] && return

    DebugFuncEntry

    local func_startseconds=$(date +%s)
    local result_index=0
    local run_count=0
    local success_count=0
    local fail_count=0
    local abort_count=0
    local max_run_count=0
    local imagelink=''
    local download_bytes=0

    [[ $output_verbose = true ]] && echo -n " download: "

    InitProgress
    ResetImageCounts

    while read -r imagelink; do
        while true; do
            RefreshImageCounts; ShowAcquisitionProgress 'images' $gallery_images_required $parallel_limit

            [[ $success_count -ge $gallery_images_required ]] && break 2

            # don't proceed until a download slot becomes available
            [[ $run_count -eq $parallel_limit ]] && continue

            if [[ $((success_count+run_count)) -lt $gallery_images_required ]] || [[ $success_count -lt $gallery_images_required ]]; then
                # fork a new downloader
                ((result_index++))
                local link_index=$(printf "%04d" $result_index)

                # create the fork runfile here as it takes too long to happen in background function
                touch "$image_run_count_path/$link_index"
                { GetImage_ "$imagelink" "$link_index" & } 2>/dev/null

                break
            fi
        done
    done < "$image_links_pathfile"

    while [[ $run_count -gt 0 ]]; do
        if [[ $success_count -ge $gallery_images_required ]]; then
            DebugFuncSuccess 'enough images received'
            AbortImages
        fi
        RefreshImageCounts; ShowAcquisitionProgress 'images' $gallery_images_required $parallel_limit
    done

    wait 2>/dev/null;                   # wait here until all forked download jobs have exited

    if [[ $success_count -gt $gallery_images_required ]]; then      # overrun can occur, so trim back successful downloads to that required
        for existing_pathfile in $(ls "$image_success_count_path"/* | tail -n +$((gallery_images_required+1))); do
            existing_file=$(basename "$existing_pathfile")
            mv "$existing_pathfile" "$image_abort_count_path"
            rm -f "$target_path/$IMAGE_FILE_PREFIX($existing_file)".*
        done
    fi

    RefreshImageCounts; ShowAcquisitionProgress 'images' $gallery_images_required $parallel_limit

    if [[ $result_index -eq $link_count ]]; then
        DebugFuncFail 'links list exhausted' "$result_index/$link_count"
        ColourTextBrightRed 'links list exhausted!'; echo
    else
        [[ $output_verbose = true ]] && echo
    fi

    DebugFuncVal 'downloads OK' "$success_count"
    DebugFuncVal 'downloads failed' "$fail_count"
    DebugFuncVal 'downloads aborted' "$abort_count"
    DebugFuncVal 'highest concurrent downloads' "$max_run_count/$parallel_limit"

    if [[ $success_count -gt 0 ]]; then
        download_bytes=$($DU_BIN "$target_path/$IMAGE_FILE_PREFIX"* -cb | tail -n1 | cut -f1)
        DebugFuncVal 'downloaded bytes' "$(DisplayThousands "$download_bytes")"

        download_seconds=$(($(date +%s)-func_startseconds))
        if [[ $download_seconds -lt 1 ]]; then
            download_seconds=1
            DebugFuncVarAdjust "\$download_seconds TOO LOW so set to a usable minimum" "$download_seconds"
        fi

        DebugFuncVal 'average download speed' "$(DisplayISO "$((download_bytes/download_seconds))")B/s"
    fi

    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return 0

    }

GetImage_()
    {

    # * This function runs as a forked process *
    # $1 = URL to download
    # $2 = debug index identifier e.g. "0026"

    :DownloadHeader()
        {

        # $1 = URL to check
        # $2 = temporary filename to download to (only used by Wget)
        # stdout = header string
        # $? = downloader return code

        local URL=$1
        local output_pathfile=$2
        local runcmd=''

        if [[ $(basename "$DOWNLOADER_BIN") = wget ]]; then
            runcmd="$DOWNLOADER_BIN --spider --server-response --max-redirect 0 --no-check-certificate --timeout $timeout_seconds --tries $((retries+1)) $USERAGENT --output-document \"$output_pathfile\" \"$URL\""
        elif [[ $(basename "$DOWNLOADER_BIN") = curl ]]; then
            runcmd="$DOWNLOADER_BIN --silent --head --insecure --max-time $timeout_seconds --retry $retries $USERAGENT \"$URL\""
        else
            DebugFuncFail "$_forkname_" 'unknown downloader'
            return 1
        fi

        DebugChildExec "get image size" "$runcmd"

        eval "$runcmd" 2>&1

        }

    :DownloadImage()
        {

        # $1 = URL to check
        # $2 = filename to download to
        # stdout = downloader stdout & stderr
        # $? = downloader return code

        local URL=$1
        local output_pathfile=$2
        local runcmd=''

        if [[ $(basename "$DOWNLOADER_BIN") = wget ]]; then
            runcmd="$DOWNLOADER_BIN --max-redirect 0 --no-check-certificate --timeout $timeout_seconds --tries $((retries+1)) $USERAGENT --output-document \"$output_pathfile\" \"$URL\""
        elif [[ $(basename "$DOWNLOADER_BIN") = curl ]]; then
            runcmd="$DOWNLOADER_BIN --silent --insecure --max-time $timeout_seconds --retry $retries $USERAGENT --output \"$output_pathfile\" \"$URL\""
        else
            DebugFuncFail 'unknown downloader' 'out-of-ideas'
            return 1
        fi

        DebugChildExec "get image" "$runcmd"

        eval "$runcmd" 2>&1

        }

    local URL=$1
    local link_index=$2
    _forkname_=$(FormatFuncLink "${FUNCNAME[0]}" "$link_index")     # global: used by various debug logging functions
    local pre_download_ok=''
    local size_ok=''
    local download_ok=''
    local response=''
    local result=0
    local download_speed=''
    local estimated_size=0
    local actual_size=0
    local func_startseconds=$(date +%s)
    local section=''
    local action=''
    local get_remote_size_result=0
    local get_image_result=0
    local get_type_result=0

    DebugChildForked

    local run_pathfile=$image_run_count_path/$link_index
    local success_pathfile=$image_success_count_path/$link_index
    local fail_pathfile=$image_fail_count_path/$link_index

    # extract file extension by checking only last 5 characters of URL (to handle .jpeg as worst case)
    local ext=$(echo "${1:(-5)}" | $SED_BIN "s/.*\(\.[^\.]*\)$/\1/")

    [[ ! "$ext" = *"."* ]] && ext='.jpg' # if URL did not have a file extension then choose jpg as default

    local targetimage_pathfileext="$target_path/$IMAGE_FILE_PREFIX($link_index)$ext"

    section='pre-download'

    if [[ $upper_size_bytes -gt 0 || $lower_size_bytes -gt 0 ]]; then
        action='request remote image file size'
        response=$(:DownloadHeader "$URL" "$image_sizetest_pathfile($link_index)$ext")
        get_remote_size_result=$?
        UpdateRunLog "$section" "$action" "$response" "$get_remote_size_result" "$(DownloaderReturnCodes "$get_remote_size_result")"

        if [[ $get_remote_size_result -eq 0 ]]; then
            action='check remote image file size'
            estimated_size=$(grep -i 'content-length:' <<< "$response" | $SED_BIN 's|^.*: ||;s|\r||')
            [[ -z $estimated_size || $estimated_size = unspecified ]] && estimated_size=unknown

            DebugChildVal "$section" "$(DisplayThousands "$estimated_size") bytes"

            if [[ $estimated_size = unknown ]]; then
                [[ $skip_no_size = true ]] && pre_download_ok=false || pre_download_ok=true
                UpdateRunLog "$section" "$action" "$(DisplayThousands "$estimated_size") bytes" '1' 'unknown'
            else
                if [[ $estimated_size -lt $lower_size_bytes ]]; then
                    pre_download_ok=false
                    UpdateRunLog "$section" "$action" "$estimated_size" '1' 'too small'
                    DebugChildFail "$action < $(DisplayThousands "$lower_size_bytes") bytes"
                elif [[ $upper_size_bytes -gt 0 && $estimated_size -gt $upper_size_bytes ]]; then
                    pre_download_ok=false
                    UpdateRunLog "$section" "$action" "$estimated_size" '1' 'too large'
                    DebugChildFail "$action > $(DisplayThousands "$upper_size_bytes") bytes"
                else
                    pre_download_ok=true
                    UpdateRunLog "$section" "$action" "$estimated_size" '0' 'OK'
                    DebugChildSuccess "$action"
                fi
            fi
        else
            pre_download_ok=false
            MoveToFail
            DebugChildFail "$section returned: \"$get_remote_size_result: $(DownloaderReturnCodes "$get_remote_size_result")\""
        fi
    else
        pre_download_ok=true
    fi

    section='mid-download'

    if [[ $pre_download_ok = true ]]; then
        action='download image'
        response=$(:DownloadImage "$URL" "$targetimage_pathfileext")
        get_image_result=$?
        UpdateRunLog "$section" "$action" "$response" "$get_image_result" "$(DownloaderReturnCodes "$get_image_result")"

        if [[ $get_image_result -eq 0 && -e $targetimage_pathfileext ]]; then
            download_ok=true
            DebugChildSuccess "$action"
        else
            download_ok=false
            MoveToFail
            DebugChildFail "$action"
        fi
    else
        download_ok=false
        MoveToFail
    fi

    section='post-download'

    if [[ $download_ok = true ]]; then
        action='check local image file size'
        actual_size=$(wc -c < "$targetimage_pathfileext"); actual_size=${actual_size##* }

        # http://stackoverflow.com/questions/36249714/parse-download-speed-from-wget-output-in-terminal
        download_speed=$(tail -n1 <<< "$response" | grep -o '\([0-9.]\+ [KM]B/s\)'); download_speed=${download_speed/K/k}

        DebugChildVal "$section" "$(DisplayThousands "$actual_size") bytes"
        DebugChildVal 'average download speed' "$download_speed"

        if [[ $actual_size -lt $lower_size_bytes ]]; then
            UpdateRunLog "$section" "$action" "$actual_size" '1' 'too small'
            size_ok=false
            MoveToFail
            DebugChildFail "$action < $lower_size_bytes"
        elif [[ $upper_size_bytes -gt 0 && $actual_size -gt $upper_size_bytes ]]; then
            UpdateRunLog "$section" "$action" "$actual_size" '1' 'too large'
            size_ok=false
            MoveToFail
            DebugChildFail "$action > $upper_size_bytes"
        else
            UpdateRunLog "$section" "$action" "$actual_size" '0' 'OK'
            size_ok=true
            DebugChildSuccess "$action"
        fi
    else
        size_ok=false
        MoveToFail
    fi

    if [[ $size_ok = true ]]; then
        response=$(RenameExtAsType "$targetimage_pathfileext")
        get_type_result=$?
        action='confirm local image file type'
        UpdateRunLog "$section" "$action" "$response" "$get_type_result" ''

        if [[ $get_type_result -eq 0 ]]; then
            MoveToSuccess
            DebugChildSuccess "$action"
        else
            MoveToFail
            DebugChildFail "$action"
        fi
    fi

    [[ -n $exclude_links_pathfile ]] && echo "$URL" >> "$exclude_links_pathfile"

    DebugChildElapsedTime "$func_startseconds"
    DebugChildEnded

    return 0

    }

ExamineLinks()
    {

    # $? = 0 if OK, 1 if not

    :GetLinkCount()
        {

        # get link count
        link_count=$(wc -l < "$image_links_pathfile"); link_count=${link_count##* }

        }

    [[ $errorcode -ne 0 ]] && return 0

    DebugFuncEntry

    link_count=0
    local returncode=0

    [[ $output_verbose = true ]] && echo -n "    links: "

    InitProgress

    if [[ -e $image_links_pathfile ]]; then
        :GetLinkCount
        DebugFuncVar link_count

        local -r allowed_file_types=(jpg jpeg png gif bmp svg ico webp raw)
        local allowed_file_type=''

        # remove duplicate URLs, but retain current order
        cat -n "$image_links_pathfile" | sort -uk2 | sort -nk1 | cut -f2 > "$image_links_pathfile.tmp"
        [[ -e $image_links_pathfile.tmp ]] && mv "$image_links_pathfile.tmp" "$image_links_pathfile"
        :GetLinkCount
        DebugFuncVarAdjust 'after removing duplicate URLs' "$link_count"

        # store a count of permitted image file-types
        DebugFuncComment 'stats for file types in search results'
        for allowed_file_type in "${allowed_file_types[@]}"; do
            result=$(grep -icE ".${allowed_file_type}$" "$image_links_pathfile")
            [[ $result -gt 0 ]] && DebugFuncVal "found file type '$allowed_file_type'" "$result"
        done
        local old_link_count=$link_count

        # check against allowable file types
        ends_with=$(printf '.%s$|' "${allowed_file_types[@]}"); ends_with=${ends_with%?}              # remove last pipe char
        grep -iE "$ends_with" "$image_links_pathfile" > "$image_links_pathfile.tmp" 2>/dev/null
        [[ -e $image_links_pathfile.tmp ]] && mv "$image_links_pathfile.tmp" "$image_links_pathfile"
        :GetLinkCount
        DebugFuncVal 'unrecognised file types' "$((old_link_count-link_count))"

        DebugFuncComment 'stats complete'
        DebugFuncVarAdjust 'after removing unrecognised file types' "$link_count"

        # remove previously downloaded URLs
        if [[ -n $exclude_links_pathfile ]]; then
            [[ -e $exclude_links_pathfile ]] && grep -axvFf "$exclude_links_pathfile" "$image_links_pathfile" > "$image_links_pathfile.tmp"
            [[ -e $image_links_pathfile.tmp ]] && mv "$image_links_pathfile.tmp" "$image_links_pathfile"
            :GetLinkCount
            DebugFuncVarAdjust 'after removing previously downloaded URLs' "$link_count"
        fi
    fi

    if [[ $output_verbose = true ]]; then
        UpdateProgress "$(ColourTextBrightGreen "$link_count")"; echo

        if [[ $link_count -lt $user_images_requested && $safesearch_on = true ]]; then
            echo
            echo " Try your search again with additional options:"
            echo "    - disable SafeSearch: '--safesearch-off'"
            echo
        fi
    fi

    if [[ -e $image_links_pathfile && $random_image = true ]]; then
        local op='shuffle links'
        shuf "$image_links_pathfile" -o "$image_links_pathfile" && DebugFuncSuccess "$op" || DebugFuncFail "$op"
    fi

    if [[ $errorcode -eq 0 && $gallery_images_required -gt $link_count ]]; then
        gallery_images_required=$link_count
        DebugFuncVarAdjust '$gallery_images_required TOO HIGH so set as $link_count' "$link_count"
    fi

    if [[ $link_count -eq 0 ]]; then
        DebugFuncVal 'zero links?' 'Oops...'
        returncode=1
    fi

    DebugFuncExit

    return $returncode

    }

RenderGallery()
    {

    # $? = 0 if OK, 1 if not

    [[ $errorcode -ne 0 && $errorcode -ne 5 ]] && return 0
    [[ $gallery = false ]] && return 0

    DebugFuncEntry

    local func_startseconds=$(date +%s)
    local GALLERY_FILE_PREFIX=googliser-gallery
    local reserve_for_border="-border $gallery_border_pixels"
    local TITLE_HEIGHT_PIXELS=100
    local stage_description=''
    local include_background=''
    local include_title=''
    local runcmd=''
    local runmsg=''
    local gallery_title=''
    local gallery_target_pathname=''
    local stage=0
    local stages=4

    [[ $output_verbose = true ]] && echo -n "  gallery: "

    InitProgress

    # set gallery title
    if [[ $gallery_user_title = none ]]; then
        ((stages--))

        if [[ -n $user_phrase ]]; then
            gallery_target_pathname="$target_path/$GALLERY_FILE_PREFIX-($user_phrase).png"
        else
            gallery_target_pathname="$target_path/$GALLERY_FILE_PREFIX-($(date +%s)).png"
        fi
    else
        if [[ -n $gallery_user_title ]]; then
            gallery_title=$gallery_user_title
        else
            if [[ -n $user_phrase ]]; then
                gallery_title=$user_phrase
            elif [[ -n $output_path ]]; then
                gallery_title=$(basename "$output_path")
            elif [[ -n $input_links_pathfile ]]; then
                gallery_title=$(date +%s)
            fi
            DebugFuncVarAdjust 'gallery title unspecified so set as' "'$gallery_title'"
        fi
        gallery_target_pathname="$target_path/$GALLERY_FILE_PREFIX-($gallery_title).png"
    fi

    DebugFuncVar gallery_title
    DebugFuncVar gallery_target_pathname

    # build thumbnails image overlay
    stage_description='render thumbnails'; ((stage++)); ShowStage

    if [[ $gallery_user_title = none ]]; then
        reserve_for_title=''
    else
        reserve_for_title="-gravity north -splice 0x$((TITLE_HEIGHT_PIXELS+gallery_border_pixels+10))"
    fi

    if [[ $gallery_compact_thumbs = true ]]; then
        runcmd="$CONVERT_BIN \"$target_path/*[0]\" -define jpeg:size=$gallery_thumbnail_dimensions -thumbnail ${gallery_thumbnail_dimensions}^ -gravity center -extent $gallery_thumbnail_dimensions miff:- | $MONTAGE_BIN - -background none -geometry +0+0 miff:- | $CONVERT_BIN - -background none $reserve_for_title -bordercolor none $reserve_for_border $gallery_thumbnails_pathfile"
    else
        runcmd="$MONTAGE_BIN \"$target_path/*[0]\" -background none -shadow -geometry $gallery_thumbnail_dimensions miff:- | $CONVERT_BIN - -background none $reserve_for_title -bordercolor none $reserve_for_border $gallery_thumbnails_pathfile"
    fi

    DebugFuncExec "$stage_description" "$runcmd"

    runmsg=$(eval "$runcmd" 2>&1)
    result=$?

    if [[ $result -eq 0 ]]; then
        DebugFuncSuccess "$stage_description"
    else
        DebugFuncFail "$stage_description" "($result)"
        DebugFuncVar runmsg
    fi

    if [[ $result -eq 0 ]]; then
        # build background image
        stage_description='render background'; ((stage++)); ShowStage

        # get image dimensions
        read -r width height <<< "$($CONVERT_BIN -ping "$gallery_thumbnails_pathfile" -format "%w %h" info:)"

        if [[ $gallery_background_trans = true ]]; then
            include_background='xc:none'                            # transparent
        else
            include_background='radial-gradient:WhiteSmoke-gray10'  # dark image with light sphere in centre
        fi

        runcmd="$CONVERT_BIN -size ${width}x${height} $include_background $gallery_background_pathfile"

        DebugFuncExec "$stage_description" "$runcmd"

        runmsg=$(eval "$runcmd" 2>&1)
        result=$?

        if [[ $result -eq 0 ]]; then
            DebugFuncSuccess "$stage_description"
        else
            DebugFuncFail "$stage_description" "($result)"
            DebugFuncVar runmsg
        fi
    fi

    if [[ $result -eq 0 && $gallery_user_title != none ]]; then
        # build title image overlay
        stage_description='render title'; ((stage++)); ShowStage

        # create title image
        runcmd="$CONVERT_BIN -size x$TITLE_HEIGHT_PIXELS -font $(FirstPreferredFont) -background none -stroke black -strokewidth 10 label:\"\\ \\ $gallery_title\\ \" -blur 0x5 -fill goldenrod1 -stroke none label:\"\\ \\ $gallery_title\\ \" -flatten $gallery_title_pathfile"

        DebugFuncExec "$stage_description" "$runcmd"

        runmsg=$(eval "$runcmd" 2>&1)
        result=$?

        if [[ $result -eq 0 ]]; then
            DebugFuncSuccess "$stage_description"
        else
            DebugFuncFail "$stage_description" "($result)"
            DebugFuncVar runmsg
        fi
    fi

    if [[ $result -eq 0 ]]; then
        # compose thumbnail and title images onto background image
        stage_description='combine images'; ((stage++)); ShowStage

        if [[ $gallery_user_title = none ]]; then
            include_title=''
        else
            include_title="-colorspace sRGB -composite $gallery_title_pathfile -gravity north -geometry +0+$((gallery_border_pixels+10))"
        fi

        # compose thumbnails image on background image, then title image on top
        runcmd="$CONVERT_BIN $gallery_background_pathfile $gallery_thumbnails_pathfile -gravity center $include_title -colorspace sRGB -composite \"$gallery_target_pathname\""

        DebugFuncExec "$stage_description" "$runcmd"

        runmsg=$(eval "$runcmd" 2>&1)
        result=$?

        if [[ $result -eq 0 ]]; then
            DebugFuncSuccess "$stage_description"
        else
            DebugFuncFail "$stage_description" "($result)"
            DebugFuncVar runmsg
        fi
    fi

    [[ -e $gallery_thumbnails_pathfile ]] && rm -f "$gallery_thumbnails_pathfile"
    [[ -e $gallery_background_pathfile ]] && rm -f "$gallery_background_pathfile"
    [[ -e $gallery_title_pathfile ]] && rm -f "$gallery_title_pathfile"

    if [[ $result -eq 0 && -e $gallery_target_pathname ]]; then
        [[ $output_verbose = true ]] && UpdateProgress "$(ColourTextBrightGreen 'done!')"
    else
        UpdateProgress "$(ColourTextBrightRed 'failed!')"
        echo
        ShowFail 'Unable to render a thumbnail gallery image'
    fi

    [[ $result -eq 0 && $gallery_delete_images = true ]] && rm -f "$target_path/$IMAGE_FILE_PREFIX"*

    [[ $output_verbose = true ]] && echo

    DebugFuncElapsedTime "$func_startseconds"
    DebugFuncExit

    return $result

    }

Finish()
    {

    if [[ $output_verbose = true ]]; then
        case $errorcode in
            [1-2])
                if [[ $show_help != true ]]; then
                    echo
                    echo " Type '-h' or '--help' to display the complete parameter list"
                fi
                ;;
            [3-6])
                echo
                ShowFail 'Done - with errors'
                ;;
            *)
                ;;
        esac
    fi

    DebugScriptNow
    DebugScriptElapsedTime "$SCRIPT_STARTSECONDS"
    DebugScriptExit

    SaveDebug

    [[ $show_help = true ]] && errorcode=0

    exit $errorcode

    }

MoveToSuccess()
    {

    # move runfile to the successes directory

    [[ -n $run_pathfile && -e $run_pathfile ]] && mv "$run_pathfile" "$success_pathfile"

    }

MoveToFail()
    {

    # move runfile to the failures directory

    [[ -n $run_pathfile && -e $run_pathfile ]] && mv "$run_pathfile" "$fail_pathfile"

    # ... and delete temp file if one was created
    [[ -n $targetimage_pathfileext && -e $targetimage_pathfileext ]] && rm -f "$targetimage_pathfileext"

    }

UpdateRunLog()
    {

    # $1 = section
    # $2 = action
    # $3 = stdout from function (optional)
    # $4 = resultcode
    # $5 = extended description of resultcode (optional)

    [[ -z $1 || -z $2 || -z $4 || -z $run_pathfile || ! -f $run_pathfile ]] && return 1

    printf "> section: %s\n= action: %s\n= stdout: '%s'\n= resultcode: %s\n= description: '%s'\n\n" "$1" "$2" "$3" "$4" "$5" >> "$run_pathfile"

    }

FindLauncher()
    {

    if [[ $ORIGIN = /usr/local/bin/googliser ]]; then
        readonly LAUNCHER=$(basename "$ORIGIN")
    else
        readonly LAUNCHER="$ORIGIN"
    fi

    DebugFuncVar LAUNCHER

    }

FindPackageManager()
    {

    # $? = 0 if OK, 1 if not

    local managers=()
    local manager=''

    managers+=(brew)
    managers+=(apt)
    managers+=(yum)
    managers+=(pacman)
    managers+=(opkg)
    managers+=(ipkg)

    for manager in "${managers[@]}"; do
        PACKAGER_BIN=$(command -v "$manager") && break
    done

    [[ -z $PACKAGER_BIN ]] && PACKAGER_BIN=unknown
    readonly PACKAGER_BIN

    DebugFuncVar PACKAGER_BIN

    return 0

    }

FindGNUUtils()
    {

    # $? = 0 if OK, 1 if not

    case $OSTYPE in
        darwin*)
            readonly SED_BIN=gsed
            readonly DU_BIN=gdu
            readonly GETOPT_BIN=$(brew --prefix gnu-getopt)/bin/getopt   # based upon https://stackoverflow.com/a/47542834/6182835
            ;;
        *)
            readonly SED_BIN=sed
            readonly DU_BIN=du
            readonly GETOPT_BIN=getopt
            ;;
    esac

    return 0

    }

FindDownloader()
    {

    # $? = 0 if OK, 1 if not

    local stage_description=''
    local runcmd=''
    local runmsg=''
    local result=0

    if ! DOWNLOADER_BIN=$(command -v curl); then
        if ! DOWNLOADER_BIN=$(command -v wget); then
            SuggestInstall wget
            errorcode=1
            return 1
        fi
    fi

    DebugFuncVar DOWNLOADER_BIN

    if [[ $(basename "$DOWNLOADER_BIN") = wget ]]; then
        runcmd="$DOWNLOADER_BIN --spider --quiet --server-response --timeout 5 --max-redirect 0 --no-check-certificate $USERAGENT 'https://www.google.com'"
    elif [[ $(basename "$DOWNLOADER_BIN") = curl ]]; then
        runcmd="$DOWNLOADER_BIN --silent --head --max-time 5 --insecure $USERAGENT 'https://www.google.com'"
    fi

    stage_description='test Internet access'
    DebugFuncExec "$stage_description" "$runcmd"

    # shellcheck disable=SC2034
    runmsg=$(eval "$runcmd" 2>&1)
    result=$?

    if [[ $result -eq 0 ]]; then
        DebugFuncSuccess "$stage_description"
    else
        DebugFuncFail "$stage_description" "($result)"
        DebugFuncVar runmsg
        echo
        ShowFail 'Unable to access the Internet'
        errorcode=8
        return 1
    fi

    return 0

    }

FindImageMagick()
    {

    # $? = 0 if OK, 1 if not

    if [[ $gallery = true && $show_help = false ]]; then
        if ! MONTAGE_BIN=$(command -v montage); then
            SuggestInstall montage imagemagick
            errorcode=1
            return 1
        elif ! CONVERT_BIN=$(command -v convert); then
            SuggestInstall convert imagemagick
            errorcode=1
            return 1
        fi
        DebugFuncVar MONTAGE_BIN
        DebugFuncVar CONVERT_BIN
    fi

    if [[ $links_only = false ]]; then
        if ! IDENTIFY_BIN=$(command -v identify); then
            DebugScriptWarn "no recognised 'identify' binary was found"
        else
            DebugFuncVar IDENTIFY_BIN
        fi
    fi

    return 0

    }

ReindexRename()
    {

    local targetfile=''
    local reindex=0

    [[ $errorcode -ne 0 && $errorcode -ne 5 ]] && return

    if [[ $reindex_rename = true && -n $target_path ]]; then
        DebugFuncOpr 'reindexing and renaming downloaded files'
        for targetfile in "$target_path/"*; do
            ((reindex++))
            mv "$targetfile" "$target_path/$IMAGE_FILE_PREFIX($(printf "%04d" $reindex)).${targetfile##*.}"
        done
    fi

    return 0

    }

SaveLinks()
    {

    # copy links file into target directory if possible. If not, then copy to current directory.

    [[ $errorcode -ne 0 ]] && return

    if [[ $save_links = true ]]; then
        DebugFuncOpr 'saving URL links file'
        if [[ $target_path_created = true ]]; then
            cp -f "$image_links_pathfile" "$target_path/$image_links_file"
        else
            cp -f "$image_links_pathfile" "$current_path/$image_links_file"
        fi
    fi

    return 0

    }

SaveDebug()
    {

    # copy debug file into target directory if possible. If not, or searched for multiple terms, then copy to current directory.

    if [[ $debug = true ]]; then
        DebugFuncOpr 'saving debug file'
        if [[ -n $input_phrases_pathfile || $target_path_created = false ]]; then
            [[ -e $current_path/$DEBUG_FILE ]] && echo "" >> "$current_path/$DEBUG_FILE"
            cat "$debug_pathfile" >> "$current_path/$DEBUG_FILE"
        else
            [[ -e $target_path/$DEBUG_FILE ]] && echo "" >> "$target_path/$DEBUG_FILE"
            cp -f "$debug_pathfile" "$target_path/$DEBUG_FILE"
        fi
    fi

    }

SuggestInstall()
    {

    # $1 = executable name missing
    # $2 (optional) = package to install. Only specify this if different to $1

    [[ -n $1 ]] && executable=$1 || return 1
    [[ -n $2 ]] && package=$2 || package=$executable

    DebugFuncFail "no recognised '$executable' executable found" 'unable to suggest'
    echo -e "\n '$executable' executable not found!"
    if [[ $PACKAGER_BIN != unknown ]]; then
        echo -e "\n try installing with:"
        echo " $ $(basename $PACKAGER_BIN) install $package"
    else
        echo " no local package manager found!"
        echo " well, I'm out of ideas..."
    fi

    }

ShowAcquisitionProgress()
    {

    # $1 = 'images' or 'pages' ?
    # $2 = total to download
    # $3 = parallel limit

    [[ -z $1 || $2 -eq 0 || $3 -eq 0 ]] && return 1

    local progress_message=''

    if [[ $output_verbose = true ]]; then
        progress_message=$(ColourTextBrightGreen "$(Display2to1 "$success_count" "$2")")
        progress_message+=" $1 OK"

        [[ $run_count -gt 0 ]] && progress_message+=", $(ColourTextBrightOrange "$run_count/$3") are in progress"

        if [[ $fail_count -gt 0 ]]; then
            progress_message+=" and $(ColourTextBrightRed "$fail_count")"
            [[ $run_count -gt 0 ]] && progress_message+=' have'
            progress_message+=' failed'
        fi

        UpdateProgress "$progress_message"
    fi

    }

InitProgress()
    {

    # needs to be called prior to first call of UpdateProgress

    previous_length=0
    previous_msg=''

    }

UpdateProgress()
    {

    # $1 = message to display

    local temp=''
    local current_length=0
    local appended_length=0

    if [[ $1 != "$previous_msg" ]]; then
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
        previous_msg=$1
    fi

    }

ResetPageCounts()
    {

    # clears paths used to count search result pages

    [[ -d $page_run_count_path ]] && rm -f "$page_run_count_path"/*
    [[ -d $page_success_count_path ]] && rm -f "$page_success_count_path"/*
    [[ -d $page_fail_count_path ]] && rm -f "$page_fail_count_path"/*
    [[ -d $page_abort_count_path ]] && rm -f "$page_abort_count_path"/*

    max_run_count=0

    RefreshPageCounts

    }

RefreshPageCounts()
    {

    run_count=$(ls -1 "$page_run_count_path" | wc -l); run_count=${run_count##* }                    # remove leading space in 'wc' output on macOS
    success_count=$(ls -1 "$page_success_count_path" | wc -l); success_count=${success_count##* }    # remove leading space in 'wc' output on macOS
    fail_count=$(ls -1 "$page_fail_count_path" | wc -l); fail_count=${fail_count##* }                # remove leading space in 'wc' output on macOS
    abort_count=$(ls -1 "$page_abort_count_path" | wc -l); abort_count=${abort_count##* }            # remove leading space in 'wc' output on macOS

    [[ $run_count -gt $max_run_count ]] && max_run_count=$run_count

    }

ResetImageCounts()
    {

    # clears paths used to count downloaded images

    [[ -d $image_run_count_path ]] && rm -f "$image_run_count_path"/*
    [[ -d $image_success_count_path ]] && rm -f "$image_success_count_path"/*
    [[ -d $image_fail_count_path ]] && rm -f "$image_fail_count_path"/*
    [[ -d $image_abort_count_path ]] && rm -f "$image_abort_count_path"/*

    max_run_count=0

    RefreshImageCounts

    }

RefreshImageCounts()
    {

    run_count=$(ls -1 "$image_run_count_path" | wc -l); run_count=${run_count##* }                   # remove leading space in 'wc' output on macOS
    success_count=$(ls -1 "$image_success_count_path" | wc -l); success_count=${success_count##* }   # remove leading space in 'wc' output on macOS
    fail_count=$(ls -1 "$image_fail_count_path" | wc -l); fail_count=${fail_count##* }               # remove leading space in 'wc' output on macOS
    abort_count=$(ls -1 "$image_abort_count_path" | wc -l); abort_count=${abort_count##* }           # remove leading space in 'wc' output on macOS

    [[ $run_count -gt $max_run_count ]] && max_run_count=$run_count

    }

Display2to1()
    {

    if [[ $1 -eq $2 ]]; then
        echo "$1"
    else
        echo "$1/$2"
    fi

    }

FormatHelpSection()
    {

    # $1 = description

    [[ -n $1 ]] && { ColourTextBrightOrange " * $1 *"; echo ;}

    }

FormatHelpLine()
    {

    # $1 = short specifier (optional)
    # $2 = long specifier (optional)
    # $3 = type: integer, string, path, boolean, etc... (optional)
    # $4 = description

    if [[ -n $1 && -z $2 && -z $3 && -z $4 ]]; then
        printf "%36s%s\n" '' "$1"
    elif [[ -n $1 && -n $2 && -z $3 && -z $4 ]]; then
        case $1 in
            preset)
                printf "%40s%s\n" '' "$2"
                ;;
            *)
                printf "%36s%s: %s\n" '' "$1" "$2"
                ;;
        esac
    elif [[ -n $1 && -n $2 && -n $3 && -z $4 ]]; then
        printf "  %-1s  --%-15s % -8s %s\n" '' "$1" "$(Uppercase "$2")" "$3"
    else
        printf " -%-1s, --%-15s % -8s %s\n" "$1" "$2" "$(Uppercase "$3")" "$4"
    fi

    }

RenameExtAsType()
    {

    # checks output of 'identify -format "%m"' and ensures provided file extension matches
    # $1 = image filename. Is it really a valid image?
    # stdout = image type
    # $? = 0 if it IS an image, 1 if not an image

    local returncode=0

    if [[ -n $IDENTIFY_BIN ]]; then
        [[ -z $1 || ! -e $1 ]] && returncode=1

        if [[ $returncode -eq 0 ]]; then
            rawtype=$($IDENTIFY_BIN -format "%m" "$1")
            returncode=$?
        fi

        if [[ $returncode -eq 0 ]]; then
            # only want first 4 chars
            imagetype=${rawtype:0:4}

            # exception to handle identify's output for animated gifs i.e. "GIFGIFGIFGIFGIF"
            [[ $imagetype = GIFG ]] && imagetype=GIF

            # exception to handle identify's output for BMP i.e. "BMP3"
            [[ $imagetype = BMP3 ]] && imagetype=BMP

            # exception to handle identify's output for RAW i.e. "CRAW"
            [[ $imagetype = CRAW ]] && imagetype=RAW

            case "$imagetype" in
                PNG|JPEG|GIF|BMP|SVG|ICO|WEBP|RAW)
                    # move file into temp file
                    mv "$1" "$1".tmp

                    # then back but with new extension created from $imagetype
                    mv "$1".tmp "${1%.*}.$(Lowercase "$imagetype")"
                    echo "$imagetype"
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

ScrapeGoogleForLinks()
    {

    #-------------------------- "These are the regexes you're looking for" --------------------------------
    # Turns a single file of Google HTML, CSS and Javascript into a neat textfile, one URL per row,
    # and each pointing to an original image address found by the Google image search engine.
    #------------------------------------------------------------------------------------------------------
    #
    # sed   1. delete all lines without 'b-GRID_STATE0',
    #       2. remove everything from the start of each line until ',["http'
    #
    # grep  3. only list lines with 'http',
    #
    # sed   4. remove from '"' until end of line.
    #
    #------------------------------------------------------------------------------------------------------

    [[ $errorcode -ne 0 ]] && return 0

    # shellcheck disable=SC2002
    cat "$pages_pathfile" \
    | $SED_BIN '/b-GRID_STATE0/,$!d' \
    | $SED_BIN 's|^\,\[\"http|\nhttp|' \
    | grep '^http' \
    | $SED_BIN 's|\".*$||' \
    > "$image_links_pathfile"

    }

ScrapeBingForLinks()
    {

    #-------------------------- "These are the regexes you're looking for" --------------------------------
    # Turns a single file of Bing HTML, CSS and Javascript into a neat textfile, one URL per row,
    # and each pointing to an original image address found by the Bing image search engine.
    #------------------------------------------------------------------------------------------------------

    [[ $errorcode -ne 0 ]] && return 0

    # shellcheck disable=SC2002
    cat "$pages_pathfile" \
    | $SED_BIN 's|murl&quot;:&quot;http|\n&|g' \
    | $SED_BIN 's|turl|\n&|g' \
    | grep murl \
    | $SED_BIN 's|^murl&quot;:&quot;||' \
    | $SED_BIN '/&amp/d' \
    | $SED_BIN '/^var /d' \
    | $SED_BIN 's|&quot.*||' \
    > "$image_links_pathfile"

    }

CTRL_C_Captured()
    {

    DebugFuncEntry

    echo
    echo " $(ColourTextBrightRed '[SIGINT]') aborting ..."

    AbortPages
    AbortImages

    DebugFuncExit
    Finish

    }

AbortPages()
    {

    # remove any files where processing by [GetGooglePage_] was incomplete

    DebugFuncEntry

    local existing_pathfile=''
    local existing_file=''

    kill $(jobs -rp) 2>/dev/null
    wait $(jobs -rp) 2>/dev/null

    for existing_pathfile in "$page_run_count_path"/*; do
        existing_file=$(basename "$existing_pathfile")
        [[ -e "$existing_pathfile" ]] && mv "$existing_pathfile" "$page_abort_count_path"/
        DebugFuncSuccess "$(FormatSearch "$existing_file")"
    done

    DebugFuncExit

    return 0

    }

AbortImages()
    {

    # remove any image files where processing by [GetImage_] was incomplete

    DebugFuncEntry

    local existing_pathfile=''
    local existing_file=''

    sleep 1         # hopefully prevent the race-condition affecting execution on macOS Catalina. Prevents 'terminated' message appearing.
    kill $(jobs -rp) 2>/dev/null
    wait $(jobs -rp) 2>/dev/null

    for existing_pathfile in "$image_run_count_path"/*; do
        existing_file=$(basename "$existing_pathfile")
        [[ -e "$existing_pathfile" ]] && mv "$existing_pathfile" "$image_abort_count_path"/
        rm -f "$target_path/$IMAGE_FILE_PREFIX($existing_file)".*
        DebugFuncSuccess "$(FormatLink "$existing_file")"
    done

    DebugFuncExit

    return 0

    }

FirstPreferredFont()
    {

    local preferred_fonts=()
    local available_fonts=()
    local preferred_font=''
    local available_font=''

    preferred_fonts+=(Century-Schoolbook-L-Bold-Italic)
    preferred_fonts+=(Droid-Serif-Bold-Italic)
    preferred_fonts+=(FreeSerif-Bold-Italic)
    preferred_fonts+=(Nimbus-Roman-No9-L-Medium-Italic)
    preferred_fonts+=(Times-BoldItalic)
    preferred_fonts+=(URW-Palladio-L-Bold-Italic)
    preferred_fonts+=(Utopia-Bold-Italic)
    preferred_fonts+=(Bitstream-Charter-Bold-Italic)

    if (command -v mapfile >/dev/null); then
        mapfile -t available_fonts < <($CONVERT_BIN -list font | grep 'Font:' | $SED_BIN 's|^.*Font: ||')
    else            # macOS's ancient BASH doesn't have 'mapfile' or 'readarray', so have to do things the old way
        while read -r available_font; do
            available_fonts+=("$available_font")
        done < <($CONVERT_BIN -list font | grep 'Font:' | $SED_BIN 's|^.*Font: ||')
    fi

    for preferred_font in "${preferred_fonts[@]}"; do
        for available_font in "${available_fonts[@]}"; do
            [[ $preferred_font = "$available_font" ]] && break 2
        done
    done

    echo "$preferred_font"

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

    [[ -n $1 && -n $2 ]] && DebugVal "$(FormatScript)" "$1: $2"

    }

DebugScriptVar()
    {

    [[ -n $1 ]] && DebugVar "$(FormatScript)" "$1"

    }

DebugScriptElapsedTime()
    {

    [[ -n $1 ]] && DebugElapsedTime "$(FormatScript)" "$1"

    }

DebugScriptFail()
    {

    [[ -n $1 ]] && DebugFail "$(FormatScript)" "$1"

    }

DebugScriptWarn()
    {

    [[ -n $1 ]] && DebugWarn "$(FormatScript)" "$1"

    }

DebugFuncEntry()
    {

    DebugEntry "$(FormatFunc "${FUNCNAME[1]}")"

    }

DebugFuncExit()
    {

    DebugExit "$(FormatFunc "${FUNCNAME[1]}")"

    }

DebugFuncElapsedTime()
    {

    [[ -n $1 ]] && DebugElapsedTime "$(FormatFunc "${FUNCNAME[1]}")" "$1"

    }

DebugFuncVarAdjust()
    {

    [[ -n $1 && -n $2 ]] && DebugVarAdjust "$(FormatFunc "${FUNCNAME[1]}")" "$1" "$2"

    }

DebugFuncSuccess()
    {

    DebugSuccess "$(FormatFunc "${FUNCNAME[1]}")" "$1"

    }

DebugFuncFail()
    {

    DebugFail "$(FormatFunc "${FUNCNAME[1]}")" "$1" "$2"

    }

DebugFuncVar()
    {

    [[ -n $1 ]] && DebugVar "$(FormatFunc "${FUNCNAME[1]}")" "$1"

    }

DebugFuncExec()
    {

    [[ -n $1 && -n $2 ]] && DebugExec "$(FormatFunc "${FUNCNAME[1]}")" "$1" "$2"

    }

DebugFuncOpr()
    {

    [[ -n $1 ]] && DebugOpr "$(FormatFunc "${FUNCNAME[1]}")" "$1"

    }

DebugFuncVal()
    {

    [[ -n $1 && -n $2 ]] && DebugVal "$(FormatFunc "${FUNCNAME[1]}")" "$1" "$2"

    }

DebugFuncComment()
    {

    [[ -n $1 ]] && DebugComment "$(FormatFunc "${FUNCNAME[1]}")" "$1"

    }

DebugChildForked()
    {

    [[ -n $_forkname_ ]] && DebugThis '>' "$_forkname_" 'fork'

    }

DebugChildEnded()
    {

    [[ -n $_forkname_ ]] && DebugThis '<' "$_forkname_" 'exit'

    }

DebugChildExec()
    {

    [[ -n $_forkname_ && -n $1 && -n $2 ]] && DebugExec "$_forkname_" "$1" "$2"

    }

DebugChildSuccess()
    {

    [[ -n $_forkname_ && -n $1 ]] && DebugSuccess "$_forkname_" "$1"

    }

DebugChildFail()
    {

    [[ -n $_forkname_ && -n $1 ]] && DebugFail "$_forkname_" "$1"

    }

DebugChildVal()
    {

    [[ -n $_forkname_ && -n $1 && -n $2 ]] && DebugVal "$_forkname_" "$1" "$2"

    }

DebugChildElapsedTime()
    {

    [[ -n $_forkname_ && -n $1 ]] && DebugElapsedTime "$_forkname_" "$1"

    }

DebugEntry()
    {

    [[ -n $1 ]] && DebugThis '\' "$1" 'entry'

    }

DebugExit()
    {

    [[ -n $1 ]] && DebugThis '/' "$1" 'exit'

    }

DebugSuccess()
    {

    [[ -n $1 && -n $2 ]] && DebugThis '$' "$1" "$2" 'OK'

    }

DebugWarn()
    {

    # $1 = section
    # $2 = operation
    # $3 = reason (optional)

    [[ -z $1 ]] && return 1

    if [[ -n $3 ]]; then
        DebugThis 'x' "$1" "$2" "$3" 'warning'
    else
        DebugThis 'x' "$1" "$2" 'warning'
    fi

    }

DebugFail()
    {

    # $1 = section
    # $2 = operation
    # $3 = reason (optional)

    [[ -z $1 ]] && return 1

    if [[ -n $3 ]]; then
        DebugThis '!' "$1" "$2" "$3" 'failed'
    else
        DebugThis '!' "$1" "$2" 'failed'
    fi

    }

DebugExec()
    {

    # $1 = process name (function/child/link/search)
    # $2 = command description
    # $3 = command string to be executed

    [[ -n $1 && -n $2 && -n $3 ]] && DebugThis '=' "$1" "$2" "'$3'"

    }

DebugOpr()
    {

    # $1 = process name (function/child/link/search)
    # $2 = operation description

    [[ -n $1 && -n $2 ]] && DebugThis '-' "$1" "$2 ..."

    }

DebugNow()
    {

    [[ -n $1 ]] && DebugVal "$1" "it's now" "$(date)"

    }

DebugVar()
    {

    # Generally, values are output as provided.
    # if a value contains whitespace, surround it with single-quotes.
    # If it's a number from 1000 up, then insert commas as thousands group separators and surround it with double-quotes.

    # $1 = scope
    # $2 = variable name to log the value of

    local displayvalue=''

    if [[ -n ${!2} ]]; then
        value=${!2}

        if [[ $value = *" "* ]]; then
            displayvalue="'$value'"
        elif [[ $value =~ ^[0-9]+$ ]]; then
            if [[ $value -ge 1000 ]]; then
                displayvalue="\"$(DisplayThousands "$value")\""
            else
                displayvalue=$value
            fi
        else
            displayvalue=$value
        fi

        DebugThis 'V' "$1" "\$$2" "$displayvalue"
    else
        DebugThis 'V' "$1" "\$$2" "''"
    fi

    }

DebugVarAdjust()
    {

    # make a record of name and value in debug log
    # $1 = section
    # $2 = name
    # $3 = value (optional)

    [[ -z $1 || -z $2 ]] && return 1

    if [[ -n $3 ]]; then
        DebugThis '~' "$1" "$2" "$3"
    else
        DebugThis '~' "$1" "$2"
    fi

    }

DebugVal()
    {

    # make a record of name and value in debug log
    # $1 = section
    # $2 = name
    # $3 = value (optional)

    [[ -z $1 || -z $2 ]] && return 1

    if [[ -n $3 ]]; then
        DebugThis '?' "$1" "$2" "$3"
    else
        DebugThis '?' "$1" "$2"
    fi

    }

DebugComment()
    {

    [[ -n $1 && -n $2 ]] && DebugThis '#' "$1" "*** $2 ***"

    }

DebugElapsedTime()
    {

    [[ -n $1 && -n $2 ]] && DebugThis 'T' "$1" "elapsed time" "$(ConvertSecs "$(($(date +%s)-$2))")"

    }

DebugThis()
    {

    # $1 = symbol
    # $2 = item
    # $3 = value
    # $4 = value (optional)
    # $5 = value (optional)

    [[ -z $1 || -z $2 || -z $3 ]] && return 1

    { if [[ -n $5 ]]; then
        echo "$1$1 $2: $3: $4: $5"
    elif [[ -n $4 ]]; then
        echo "$1$1 $2: $3: $4"
    else
        echo "$1$1 $2: $3"
    fi } >> "$debug_pathfile"

    }

FormatFuncSearch()
    {

    [[ -n $1 && -n $2 ]] && echo "$(FormatFunc "$1"): $(FormatSearch "$2")"

    }

FormatFuncLink()
    {

    [[ -n $1 && -n $2 ]] && echo "$(FormatFunc "$1"): $(FormatLink "$2")"

    }

FormatScript()
    {

    [[ -n $SCRIPT_FILE ]] && echo "($SCRIPT_FILE)"

    }

FormatFunc()
    {

    [[ -n $1 ]] && echo "($1)"

    }

FormatSearch()
    {

    [[ -n $1 ]] && echo "search ($1)"

    }

FormatLink()
    {

    [[ -n $1 ]] && echo "link ($1)"

    }

DownloaderReturnCodes()
    {

    # $1 = downloader return code
    # echo = return code description

    if [[ $(basename "$DOWNLOADER_BIN") = wget ]]; then
        WgetReturnCodes "$1"
    elif [[ $(basename "$DOWNLOADER_BIN") = curl ]]; then
        CurlReturnCodes "$1"
    else
        DebugFuncFail 'no return codes available for this downloader' 'unable to decode'
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
            echo "Fail in receiving network data"
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

ColourTextBrightGreen()
    {

    if [[ $output_colour = true ]]; then
        echo -en '\033[1;32m'"$(ColourReset "$1")"
    else
        echo -n "$1"
    fi

    }

ColourTextBrightOrange()
    {

    if [[ $output_colour = true ]]; then
        echo -en '\033[1;38;5;214m'"$(ColourReset "$1")"
    else
        echo -n "$1"
    fi

    }

ColourTextBrightRed()
    {

    if [[ $output_colour = true ]]; then
        echo -en '\033[1;31m'"$(ColourReset "$1")"
    else
        echo -n "$1"
    fi

    }

ColourTextBrightBlue()
    {

    if [[ $output_colour = true ]]; then
        echo -en '\033[1;34m'"$(ColourReset "$1")"
    else
        echo -n "$1"
    fi

    }

ColourTextBold()
    {

    if [[ $output_colour = true ]]; then
        echo -en '\033[1m'"$(ColourReset "$1")"
    else
        echo -n "$1"
    fi

    }

ColourReset()
    {

    echo -en "$1"'\033[0m'

    }

RemoveColourCodes()
    {

    # http://www.commandlinefu.com/commands/view/3584/remove-color-codes-special-characters-with-sed
    echo -n "$1" | $SED_BIN "s,\x1B\[[0-9;]*[a-zA-Z],,g"

    }

ShowTitle()
    {

    [[ $output_verbose = true ]] && echo " $(ColourTextBold "$SCRIPT_FILE") $SCRIPT_VERSION_PID"

    }

ShowGoogle()
    {

    echo -n "$(ColourTextBrightBlue 'G')$(ColourTextBrightRed 'o')$(ColourTextBrightOrange 'o')$(ColourTextBrightBlue 'g')$(ColourTextBrightGreen 'l')$(ColourTextBrightRed 'e')"

    }

ShowBing()
    {

    echo -n "$(ColourTextBrightGreen 'Bing')"

    }

ShowStage()
    {

    [[ $output_verbose = true ]] && UpdateProgress "$(ColourTextBrightOrange "stage $stage/$stages") ($stage_description)"

    }

ShowFailInvalidPreset()
    {

    ShowFail "Value specified after ($1) must be a valid preset"

    }

ShowFailInvalidInteger()
    {

    ShowFail "Value specified after ($1) must be a valid integer"

    }

ShowFailMissingFile()
    {

    ShowFail "File specified after ($1) was not found"

    }

ShowFail()
    {

    # $1 = message to show in colour if colour is set

    if [[ $output_colour = true ]]; then
        ColourTextBrightRed " $1"; echo
    else
        echo " $1"
    fi

    }

Lowercase()
    {

    # $1 = some text to convert to lowercase

    tr 'A-Z' 'a-z' <<< "$1"

    }

Uppercase()
    {

    # $1 = some text to convert to uppercase

    tr 'a-z' 'A-Z' <<< "$1"

    }

DisplayISO()
    {

    # show $1 formatted with 'k', 'M', 'G'

    echo "$1" | awk 'BEGIN{ u[0]=""; u[1]=" k"; u[2]=" M"; u[3]=" G"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } '

    }

DisplayThousands()
    {

    # show $1 formatted with thousands separator

    printf "%'.f\n" "$1"

    }

if InitOK "$@"; then
    if [[ -n $input_phrases_pathfile ]]; then
        while read -r file_phrase; do
            [[ -n $file_phrase && $file_phrase != \#* ]] && ProcessPhrase "$file_phrase"
        done < "$input_phrases_pathfile"
    elif [[ -n $input_links_pathfile ]]; then
        ProcessLinkList
    else
        ProcessPhrase "$user_phrase"
    fi
fi

Finish
