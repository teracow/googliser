#!/usr/bin/env bash

shellcheck --shell=bash --exclude=1003,1117,2002,2005,2012,2015,2016,2018,2019,2076,2155,2181,2209 googliser.sh
#shellcheck --shell=bash googliser.sh