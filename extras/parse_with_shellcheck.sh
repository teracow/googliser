#!/usr/bin/env bash

targets=()
targets+=(../googliser.sh)
targets+=(../install.sh)

for target in "${targets[@]}"; do
    {

    echo -n "checking $target "

    #shellcheck --shell=bash "$target"
    shellcheck --shell=bash --exclude=1003,1117,2012,2015,2016,2018,2019,2046,2120,2155,2209 "$target"

    } && echo 'passed!' || echo 'failed!'
done
