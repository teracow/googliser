#!/usr/bin/env bash

targets=()
targets+=(../googliser.sh)
targets+=(../install.sh)

for target in "${targets[@]}"; do
    {

    echo "checking $target"
    #shellcheck --shell=bash "$target"
    shellcheck --shell=bash --exclude=1003,1117,2002,2012,2015,2016,2018,2019,2034,2046,2120,2155,2209 "$target"

    } && echo 'passed!' || echo 'failed!'
    echo
done
