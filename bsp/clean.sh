#!/bin/bash

#output -> rm
rm -rf ./output

#uboot -> make clean
cd uboot
make clean
cd ..

#kernel/build -> rm
cd kernel
rm -rf build
cd ..

#rootfs/buildroot-2026.05 make clean -> rm output / dl
cd rootfs/buildroot-2026.05
make clean
rm -rf output
rm -rf dl