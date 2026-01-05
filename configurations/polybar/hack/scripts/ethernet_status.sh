#!/bin/sh

echo "%{F#2495e7}󰈀 %{F#ffffff}$(/usr/sbin/ip a show ens33 | grep "inet " | awk '{print $2}' | awk -F/ '{print $1}')%{u-}"
