ASTVER ?= 20.9.3
ASTBUILDNUM ?= 3
ASTFILE=asterisk-$(ASTVER).tar.gz
ASTURL=http://downloads.asterisk.org/pub/telephony/asterisk/releases/$(ASTFILE)
ASTDEST=$(shell pwd)/src/asterisk-$(ASTVER)
#SPDSPCOMMIT=e08c74db3f0
#SPDSPCOMMIT=9c42d580d97f
SPDSPCOMMIT=530d58364fff
# This is what is in debian/changelog.
SPDSPVERS=3.0.0
SPDSPREL=43
SPDSPBUILD=$(SPDSPVERS)-$(SPDSPREL)
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

# This is where asterisk downloads temporary files to. We keep this to stop
# asterisk redownloading everything every time.
CACHEDIR=$(shell pwd)/src/astcache
DVOLUMES=-v $(shell pwd)/build:/build -v $(SPDSPDEST):/build/spandsp -v $(ASTDEST):/build/asterisk -v $(FLITEDEST):/build/flite -v $(CCACHEROOT):$(CCACHEROOT)
DPARAMS=$(DVOLUMES) -v $(CACHEDIR):/cache -e AST_DOWNLOAD_CACHE=/cache

# This is an extracted and slightly modified version of the debian Asterisk
# build package asterisk_20.9.3~dfsg+~cs6.14.60671435-1.debian.tar.xz from
# https://packages.debian.org/sid/asterisk found at
#
#   http://deb.debian.org/debian/pool/main/a/asterisk/asterisk_20.9.3~dfsg+~cs6.14.60671435-1.debian.tar.xz
ASTDEBSRC=debian

# Temporary changelog files that are used to autogenerate the debian/changelog files
ACHANGELOG=/tmp/achangelog-$(ASTVER)-$(ASTBUILDNUM)
SCHANGELOG=/tmp/schangelog-$(SPDSPBUILD)

.PHONY: shell astclean clean distclean asterisk debs

shell: asterisk flite
	@echo dpkg-buildpackage -us -uc
	docker run --rm -it --privileged -w /build/asterisk $(DPARAMS) astbuild bash

# Display the important debs that can be used by other things to import them
ASTDEBSUFFIX=_$(ASTVER)-$(ASTBUILDNUM)_amd64.deb
ASTDEBPREFIX=build/asterisk
ASTDEBCOMPONENTS=config dahdi modules mp3 mysql
ASTDEBS=$(ASTDEBPREFIX)$(ASTDEBSUFFIX) $(addprefix $(ASTDEBPREFIX)-,$(addsuffix $(ASTDEBSUFFIX),$(ASTDEBCOMPONENTS)))
DEBS=$(SPDSPDEB) $(ASTDEBS)

debs:
	@echo $(DEBS)

ASTDEPS=$(SPDSPDEB) build/asterisk_$(ASTVER).orig.tar.gz $(ASTDEST)/debian/control $(ASTDEST)/debian/addons-mp3.tgz $(CACHEFILE)
.PHONY: astbuild
astbuild $(ASTDEBS): $(ASTDEPS) | .astbuild
	docker run --rm -it --privileged -w /build/asterisk $(DPARAMS) astbuild dpkg-buildpackage -us -uc

astclean clean:
	rm -rf $(ASTDEST)

distclean:
	rm -rf $(SPDSPDEB) $(shell pwd)/src/spandsp-* $(SPDSPDEST) $(ASTDEST) src/$(ASTFILE) astbuild/*deb src/astdeb.tar.gz src/$(SPDSPFILE) build astbuild/spandsp.tar.gz

.PHONY: asterisk
asterisk: $(ASTDEPS) | .astbuild

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

src/astdeb.tar.gz: $(ASTDEBSRC)/changelog $(wildcard $(ASTDEBSRC)/*) $(wildcard $(ASTDEBSRC)/*/*)
	tar -zcf $@ $(ASTDEBSRC)

$(ASTDEBSRC)/changelog: $(ACHANGELOG)
	cp $< $@

$(ACHANGELOG):
	echo "asterisk (1:$(ASTVER)-$(ASTBUILDNUM)) unstable; urgency=medium\n\n  * Autogenerated by PhoneBocx asteriskbuild\n\n -- Autobuild <xrobau@gmail.com>  $(shell date '+%a, %d %b %Y %T -0000' --utc)" > $@

$(SCHANGELOG):
	echo "spandsp ($(SPDSPBUILD)) unstable; urgency=medium\n\n  * Autogenerated by PhoneBocx asteriskbuild\n\n -- Autobuild <xrobau@gmail.com>  $(shell date '+%a, %d %b %Y %T -0000' --utc)" > $@

$(ASTDEST)/configure.ac: |src/$(ASTFILE)
	mkdir -p $(@D) && tar -C $(@D) --strip-components=1 -zxf $|

.PHONY: flite
flite: $(FLITEDEST)/Makefile

$(FLITEDEST)/Makefile: |src/$(FLITEFILE)
	mkdir -p $(@D) && tar -C $(@D) --strip-components=1 -zxf $|

src/$(FLITEFILE):
	mkdir -p src && wget $(FLITEURL) -O $@

spandsp: build/spandsp_3.0.0.orig.tar.gz astbuild/spandsp.tar.gz | .spandspbuild

astbuild/spandsp.tar.gz: $(SPDSPDEB) $(wildcard build/*spandsp*deb)
	tar -zcf $@ build/*spandsp*deb

.PHONY: spandspdeb
spandspdeb $(SPDSPDEB): $(SPDSPDEST)/configure.ac $(SPDSPDEST)/debian/changelog
	docker run --rm -it --privileged -w /build/spandsp $(DPARAMS) spandspbuild dpkg-buildpackage -us -uc

$(SPDSPDEST)/configure.ac: |src/$(SPDSPFILE)
	mkdir -p $(@D) && tar -C $(@D) --strip-components=1 -zxf $|

$(SPDSPDEST)/debian/changelog: $(SCHANGELOG)
	cp $< $@

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

# Preserve the asterisk downloaded cache files
$(CACHEDIR):
	mkdir -p $@