#!/bin/bash

. `dirname $0`/sdbs.inc

for module in \
    IO::Socket::SSL \
    CPAN::Uploader \
; do
perlmodule $module
done
