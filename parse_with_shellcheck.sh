#!/usr/bin/env bash

{

#shellcheck --shell=bash googliser.sh
shellcheck --shell=bash --exclude=1003,1117,2002,2012,2015,2016,2018,2019,2034,2046,2076,2119,2120,2155 googliser.sh

} && echo 'passed!' || echo 'failed!'
