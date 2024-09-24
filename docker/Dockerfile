ARG ARCH=
FROM debian:bookworm
LABEL authors="Rob Thomas <xrobau@gmail.com>"

ENV DEBIAN_FRONTEND noninteractive
RUN echo "dash dash/sh boolean false" | debconf-set-selections &&  dpkg-reconfigure dash
COPY 01-apt-norecommends /etc/apt/apt.conf.d/01norecommends

RUN apt-get update && apt-get install -y dialog apt-utils locales

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen
ENV LANG en_US.utf8

RUN apt-get update && apt-get install -y \
	vim vim-autopep8 nano git curl sudo mc build-essential pbuilder zip \
	devscripts lsb-release libtool libapt-pkg-dev pkg-config debhelper \
	jq unzip autotools-dev autoconf automake libncurses5-dev flex bison \
	cmake bc libssl-dev zip unzip uuid-dev iasl binutils-dev dahdi-source \
	default-libmysqlclient-dev freetds-dev libasound2-dev libavcodec-dev \
	libavdevice-dev libbluetooth-dev libc-client2007e-dev libcap-dev \
	libcurl4-openssl-dev libedit-dev libradcli-dev libopus-dev quilt \
	libgmime-3.0-dev libgsm1-dev libical-dev libiksemel-dev libjack-dev \
	libldap-dev liblua5.1-0-dev libneon27-gnutls-dev libnewt-dev less \
	libopusfile-dev libpopt-dev libpq-dev libpri-dev libreadline-dev \
	libresample1-dev libsdl-image1.2-dev libsnmp-dev libspeex-dev \
	libspeexdsp-dev libsrtp2-dev libss7-dev libsystemd-dev libswscale-dev \
	libtonezone-dev libunbound-dev liburiparser-dev libvpb-dev libxslt1-dev \
	portaudio19-dev unixodbc-dev libtiff-dev libsndfile1-dev libpcap-dev \
	doxygen xsltproc openssl libxml2-dev sqlite3 libsqlite3-dev \
	libjansson-dev

RUN apt-get install -y cmark-gfm libcodec2-dev libfftw3-dev libjwt-dev \
	libneon27-dev libopencore-amrnb-dev libopencore-amrwb-dev libopenr2-dev \
	libopusenc-dev libvo-amrwbenc-dev

# dpatch
COPY *deb /tmp
RUN dpkg -i /tmp/*deb

RUN apt-get install -y ccache
ENV CCACHEROOT /usr/local/build/ccache
ENV CCACHE_DIR $CCACHEROOT/cachedir
ENV CCACHE_MAXSIZE 10G
ENV CCACHE_STATSLOG $CCACHEROOT/ccache.statslog
RUN ln -s /usr/bin/ccache /usr/local/bin/gcc
RUN ln -s /usr/bin/ccache /usr/local/bin/g++
RUN ln -s /usr/bin/ccache /usr/local/bin/x86_64-linux-gnu-gcc
RUN ln -s /usr/bin/ccache /usr/local/bin/x86_64-linux-gnu-g++
ENV CC /usr/local/bin/gcc
ENV CXX /usr/local/bin/g++

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
