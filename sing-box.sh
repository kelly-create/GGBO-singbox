#!/bin/bash

args=$@
is_sh_ver=v1.0.5

. /etc/sing-box/sh/src/init.sh
load core.sh

if [[ ! $1 ]]; then
    main main
else
    main "$@"
fi