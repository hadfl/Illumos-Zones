#!/bin/bash

. `dirname $0`/sdbs.inc

for module in \
    Data::Processor \
    IO::Socket::SSL \
    CPAN::Uploader \
; do
perlmodule $module
done
