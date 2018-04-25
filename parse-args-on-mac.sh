#!/usr/bin/env bash

###############################################################################
# parse-args-on-mac.sh
#
# (C)opyright 2018 Teracow Software
#
# If you find this script useful, please send me an email to let me know. :)
#   teracow@gmail.com
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

case "$OSTYPE" in
    "darwin"*)
        CMD_READLINK='greadlink'
        CMD_HEAD='ghead'
        CMD_SED='gsed'
        CMD_DU='gdu'
        CMD_LS='gls'
        CMD_GETOPT="$(brew --prefix gnu-getopt)/bin/getopt" # based upon https://stackoverflow.com/a/47542834/6182835
        ;;
    *)
        CMD_READLINK='readlink'
        CMD_HEAD='head'
        CMD_SED='sed'
        CMD_DU='du'
        CMD_LS='ls'
        CMD_GETOPT='getopt'
        ;;
esac

user_parameters=$($CMD_GETOPT -o n:,p: -l number:,phrase: -n $($CMD_READLINK -f -- "$0") -- "$@")
user_parameters_result=$?
user_parameters_raw="$@"

Init()
    {

    local script_date='2018-04-25'
    script_file='parse-args-on-mac.sh'
    script_name="${script_file%.*}"
    local script_details_plain="$script_file - $script_date PID:[$$]"

    # parameter defaults
    images_required_default=25

    # internals
    local script_starttime=$(date)
    script_startseconds=$(date +%s)
    server='www.google.com'
    useragent='Mozilla/5.0 (X11; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0'
    target_path_created=false
    show_help_only=false
    exitcode=0

    # user changable parameters
    user_query=''
    images_required=$images_required_default
    debug=true

    WhatAreMyOptions

    DebugThis '? $script_details' "$script_details_plain"
    DebugThis '? $user_parameters_raw' "$user_parameters_raw"

    DebugThis '= environment' '*** parameters ***'
    DebugThis '? $user_query' "$user_query"
    DebugThis '? $images_required' "$images_required"

    }

WhatAreMyOptions()
    {

    [[ $user_parameters_result -ne 0 ]] && { echo; exitcode=2; return 1 ;}
    [[ $user_parameters = ' --' ]] && { show_help_only=true; exitcode=2; return 1 ;}

    eval set -- "$user_parameters"

    while true; do
        case "$1" in
            -n|--number)
                images_required="$2"
                shift 2
                ;;
            -p|--phrase)
                user_query="$2"
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

DebugThis()
    {

    # $1 = item
    # $2 = value

    echo "$1: '$2'"

    }

Init
