#!/bin/sh
make prepare
make clean
dpkg-buildpackage -aarm64 -d
