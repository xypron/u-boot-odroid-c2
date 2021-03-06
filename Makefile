# Build U-Boot for Odroid C2
.POSIX:

TAG=2018.03
TAGPREFIX=v
REVISION=002

MESON_TOOLS_TAG=v0.1

MK_ARCH="${shell uname -m}"
ifneq ("aarch64", $(MK_ARCH))
	export ARCH=arm64
	export CROSS_COMPILE=aarch64-linux-gnu-
endif
undefine MK_ARCH

export LOCALVERSION:=-R$(REVISION)

all:
	make prepare
	make build
	make fip_create
	make sign

prepare:
	test -d denx || git clone -v \
	http://git.denx.de/u-boot.git denx
	cd denx && git fetch
	gpg --list-keys 87F9F635D31D7652 || \
	gpg --keyserver keys.gnupg.net --recv-key 87F9F635D31D7652
	test -d hardkernel || git clone -v \
	https://github.com/hardkernel/u-boot.git hardkernel
	cd hardkernel && git fetch
	test -d meson-tools || git clone -v \
	https://github.com/afaerber/meson-tools.git meson-tools
	cd meson-tools && git fetch
	gpg --list-keys FA2ED12D3E7E013F || \
	gpg --keyserver keys.gnupg.net --recv-key FA2ED12D3E7E013F
	test -f ~/.gitconfig || \
	  ( git config --global user.email "somebody@example.com"  && \
	  git config --global user.name "somebody" )

build:
	cd denx && git fetch
	cd denx && git verify-tag $(TAGPREFIX)$(TAG) 2>&1 | \
	grep 'E872 DB40 9C1A 687E FBE8  6336 87F9 F635 D31D 7652'
	cd denx && ( git am --abort || true )
	cd denx && git reset --hard
	cd denx && git checkout master
	cd denx && ( git branch -D build || true )
	cd denx && git checkout $(TAGPREFIX)$(TAG)
	cd denx && git checkout -b build
	test ! -f patch/patch-$(TAG) || ( cd denx && ../patch/patch-$(TAG) )
	cd denx && make distclean
	cp config/config-$(TAG) denx/.config
	cd denx && make oldconfig
	cd denx && make -j6

fip_create:
	cd hardkernel && git fetch
	cd hardkernel && git reset --hard
	cd hardkernel && git checkout f9a34305b098cf3e78d2e53f467668ba51881e91
	cd hardkernel && ( git branch -D build || true )
	cd hardkernel && git checkout -b build
	test ! -f patch/patch-hardkernel || \
	  ( cd hardkernel && ../patch/patch-hardkernel )
	cd hardkernel/tools/fip_create && make
	cp hardkernel/tools/fip_create/fip_create hardkernel/fip
	cp denx/u-boot.bin hardkernel/fip/gxb/bl33.bin
	cd hardkernel/fip/gxb && ../fip_create \
	  --bl30 bl30.bin --bl301 bl301.bin \
	  --bl31 bl31.bin --bl33 bl33.bin fip.bin
	cd hardkernel/fip/gxb && cat bl2.package fip.bin > boot_new.bin

sign:
	cd meson-tools && git fetch
	cd meson-tools && git verify-tag $(MESON_TOOLS_TAG) 2>&1 | \
	grep '174F 0347 1BCC 221A 6175  6F96 FA2E D12D 3E7E 013F'
	cd meson-tools && git reset --hard
	cd meson-tools && git checkout $(MESON_TOOLS_TAG)
	cd meson-tools && make CC=gcc
	meson-tools/amlbootsig hardkernel/fip/gxb/boot_new.bin u-boot.bin

clean:
	test ! -d denx        || ( cd denx && make clean )
	test ! -d hardkernel  || ( cd hardkernel && make clean )
	test ! -d meson-tools || ( cd meson-tools && make clean )
	rm -f u-boot.bin

install:
	mkdir -p $(DESTDIR)/usr/lib/u-boot/odroid-c2/
	dd if=u-boot.bin of=$(DESTDIR)/usr/lib/u-boot/odroid-c2/u-boot.bin skip=96
	cp hardkernel/sd_fuse/bl1.bin.hardkernel $(DESTDIR)/usr/lib/u-boot/odroid-c2/
	cp hardkernel/sd_fuse/sd_fusing.sh $(DESTDIR)/usr/lib/u-boot/odroid-c2/

uninstall:
	rm -rf $(DESTDIR)/usr/lib/u-boot/odroid-c2/
