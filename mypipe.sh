#!/bin/sh

mypath=`dirname $0`

tag="mypipe[$$]"
(
	cd $mypath
	for y in *.yml
	do
		echo "### $y"
		plagger -c $y
	done
) 2>&1 | logger -s -t $tag

