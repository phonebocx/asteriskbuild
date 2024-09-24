ASTVER=20.9.3
ASTFILE=asterisk-$(ASTVER).tar.gz
ASTURL=http://downloads.asterisk.org/pub/telephony/asterisk/releases/$(ASTFILE)
ASTDEST=$(shell pwd)/src/asterisk-$(ASTVER)
#SPDSPCOMMIT=e08c74db3f0
#SPDSPCOMMIT=9c42d580d97f
SPDSPCOMMIT=530d58364fff
# This is what is in debian/changelog.
SPDSPBUILD=3.0.0-42
SPDSPDEBNAME=libspandsp3_$(SPDSPBUILD)_amd64.deb
SPDSPDEB=build/$(SPDSPDEBNAME)
SPDSPFILE=$(SPDSPCOMMIT).tar.gz
SPDSPURL=https://github.com/phonebocx/spandsp/archive/$(SPDSPFILE)
SPDSPDEST=$(shell pwd)/src/spandsp-$(SPDSPCOMMIT)

FLITECOMMIT=569b2f0101
FLITEVERS=3.0
FLITEFILE=$(FLITECOMMIT).tar.gz
FLITEURL=https://github.com/zaf/Asterisk-Flite/archive/$(FLITEFILE)
FLITEDEST=$(shell pwd)/src/flite-$(FLITECOMMIT)

CCACHEROOT=/usr/local/build/ccache
CCACHE_DIR=$(CCACHEROOT)/cachedir
CCACHE_MAXSIZE=10G
CCACHE_STATSLOG=$(CCACHEROOT)/ccache.statslog
export CCACHE_DIR CCACHE_MAXSIZE CCACHE_STATSLOG

DVOLUMES=-v $(shell pwd)/build:/build -v $(SPDSPDEST):/build/spandsp -v $(ASTDEST):/build/asterisk -v $(FLITEDEST):/build/flite -v $(CCACHEROOT):$(CCACHEROOT)
DPARAMS=$(DVOLUMES)

# This is an extracted and slightly modified version of the debian Asterisk
# build package asterisk_20.9.3~dfsg+~cs6.14.60671435-1.debian.tar.xz from
# https://packages.debian.org/sid/asterisk found at
#
#   http://deb.debian.org/debian/pool/main/a/asterisk/asterisk_20.9.3~dfsg+~cs6.14.60671435-1.debian.tar.xz
ASTDEBSRC=debian

.PHONY: asterisk spandsp

shell: asterisk flite
	@echo dpkg-buildpackage -us -uc
	docker run --rm -it --privileged -w /build/asterisk $(DPARAMS) astbuild bash

astbuild: asterisk
	docker run --rm -it --privileged -w /build/asterisk $(DPARAMS) astbuild dpkg-buildpackage -us -uc

astclean:
	rm -rf $(ASTDEST)

clean:
	rm -rf $(SPDSPDEB) $(shell pwd)/src/spandsp-* $(SPDSPDEST) $(ASTDEST) src/$(ASTFILE) astbuild/*deb src/astdeb.tar.gz src/$(SPDSPFILE) build astbuild/spandsp.tar.gz

asterisk: spandsp build/asterisk_$(ASTVER).orig.tar.gz $(ASTDEST)/debian/control $(ASTDEST)/debian/addons-mp3.tgz | .astbuild

build/asterisk_$(ASTVER).orig.tar.gz: src/$(ASTFILE)
	mkdir -p $(@D) && cp src/$(ASTFILE) $@

src/$(ASTFILE):
	mkdir -p src && wget $(ASTURL) -O $@

$(ASTDEST)/debian/control: $(ASTDEST)/configure.ac src/astdeb.tar.gz
	mkdir -p $(@D) && tar -C $(@D) --strip-components=1 -zxf src/astdeb.tar.gz && touch $@

# addons-mp3 is created by:
#   svn export https://svn.digium.com/svn/thirdparty/mp3/trunk addons/mp3
#   sed -i -e '/#include "asterisk.h"/i#define ASTMM_LIBC ASTMM_REDIRECT' addons/mp3/interface.c
#   tar zcvf addons-mp3.tgz addons
#
# I didn't bother automating it, this code hasn't changed in years
$(ASTDEST)/debian/addons-mp3.tgz: addons-mp3.tgz
	cp $< $@

src/astdeb.tar.gz: $(wildcard $(ASTDEBSRC)/*) $(wildcard $(ASTDEBSRC)/*/*)
	tar -zcf $@ $(ASTDEBSRC)

$(ASTDEST)/configure.ac: |src/$(ASTFILE)
	mkdir -p $(@D) && tar -C $(@D) --strip-components=1 -zxf $|

flite: $(FLITEDEST)/Makefile

$(FLITEDEST)/Makefile: |src/$(FLITEFILE)
	mkdir -p $(@D) && tar -C $(@D) --strip-components=1 -zxf $|

src/$(FLITEFILE):
	mkdir -p src && wget $(FLITEURL) -O $@

spandsp: build/spandsp_3.0.0.orig.tar.gz astbuild/spandsp.tar.gz | .spandspbuild

astbuild/spandsp.tar.gz: $(SPDSPDEB) $(wildcard build/*spandsp*deb)
	tar -zcf $@ build/*spandsp*deb

.PHONY: ss
ss $(SPDSPDEB): $(SPDSPDEST)/configure.ac
	docker run --rm -it --privileged -w /build/spandsp $(DPARAMS) spandspbuild dpkg-buildpackage -us -uc

$(SPDSPDEST)/configure.ac: |src/$(SPDSPFILE)
	mkdir -p $(@D) && tar -C $(@D) --strip-components=1 -zxf $|

# These aren't used, we use dpkg-buildpackage -us -uc instead
$(SPDSPDEST)/Makefile: $(SPDSPDEST)/configure
	docker run --rm -it --privileged -w /spandsp $(DPARAMS) ./configure

$(SPDSPDEST)/configure: $(SPDSPDEST)/configure.ac
	docker run --rm -it --privileged -w /spandsp $(DPARAMS) autoreconf -fi

build/spandsp_3.0.0.orig.tar.gz: src/$(SPDSPFILE)
	mkdir -p $(@D) && cp src/$(SPDSPFILE) $@

src/$(SPDSPFILE):
	mkdir -p src && wget $(SPDSPURL) -O $@

.PHONY: docker
docker: .spandspbuild .astbuild

DPATCHDEB=dpatch_2.0.41_all.deb
DPATCHSRC=http://ftp.au.debian.org/debian/pool/main/d/dpatch/$(DPATCHDEB)

docker/$(DPATCHDEB):
	wget $(DPATCHSRC) -O $@

.spandspbuild: docker/$(DPATCHDEB) $(wildcard docker/*)
	docker build -t spandspbuild docker && touch .spandspbuild

.astbuild: .spandspbuild $(wildcard astbuild/*)
	docker build -t astbuild astbuild && touch .astbuild
