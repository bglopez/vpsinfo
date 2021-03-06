#!/bin/bash

# part of VPSinfo https://github.com/claude-ws01/vpsinfo
#
# Compile & setuid beanc, a C program to read Virtuozzo 3.0 & openVZ user_beancounters
#
# Concept & bean.c source by mkhs. Thanks!
# Installation script by Douglas Robbins.
#
# Modified 12 Aug 2006 to remove dependency on 'which' utility.
# modified 2014-15, Claude Nadon.

if [ ! -e '/proc/user_beancounters' ]; then
    echo 'Sorry, no bean counters here'
    exit 0
fi

beans=`beanc 2> /dev/null`
if [ "$beans" ]
	then
		echo "beanc is already installed."
		exit 0
fi
cc > /dev/null 2>&1
if [ "$?" -ne "1" ]; then
		echo "C compiler not found, cannot continue."
		exit 1
else
	if [ ! -f beanc.c ]; then
			echo "beanc.c not found, cannot continue."
			exit 1
	fi
	cc beanc.c -o /bin/beanc
	if [ $? = 0 ]
		then
			chmod 4755 /bin/beanc
			echo "beanc compiled successfully. Type 'beanc' to test."
			exit 0
	else
		echo "beanc failed to compile."
		exit 1
	fi
fi
