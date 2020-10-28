###############################################################################################
# OpenConnect Builder
###############################################################################################
FROM alpine:3 AS openConnectBuilder

RUN apk add --no-cache \
	automake \
	autoconf \
	curl \
	gcc \
	gettext \
	git \
	libtool \
	libproxy-dev \
	libxml2-dev \
	lz4-dev \
	make \
	musl-dev \
	openssl-dev \
	linux-headers

ENV VPNC_SCRIPT_PATH=/usr/local/sbin/vpnc-script

RUN mkdir -p /usr/local/sbin \
	&& curl -s -o ${VPNC_SCRIPT_PATH} http://git.infradead.org/users/dwmw2/vpnc-scripts.git/blob_plain/HEAD:/vpnc-script \
	&& chmod +x ${VPNC_SCRIPT_PATH}

ENV OPENCONNECT_VERSION=v8.10
ENV OPENCONNECT_REPO=https://gitlab.com/openconnect/openconnect.git

RUN cd /tmp \
	&& git clone -b "${OPENCONNECT_VERSION}" --single-branch --depth=1 ${OPENCONNECT_REPO} \
	&& cd openconnect \
	&& ./autogen.sh \
	&& ./configure --without-gnutls --with-vpnc-script=${VPNC_SCRIPT_PATH} \
	&& make check \
	&& make \
	&& make install

###############################################################################################
# App Builder
###############################################################################################
FROM python:3.8-alpine as appBuilder

WORKDIR /app

RUN apk add --no-cache \
	gcc \
	libc-dev \
	libxslt \
	libxslt-dev \
	py3-lxml

COPY requirements.txt .

RUN pip wheel \
	--no-cache-dir \
	--no-deps \
	--wheel-dir /app/wheels \
	-r requirements.txt

###############################################################################################
# Final image
###############################################################################################
FROM python:3.8-alpine

COPY --from=openConnectBuilder /usr/local/sbin/openconnect /usr/local/sbin/
COPY --from=openConnectBuilder /usr/local/sbin/vpnc-script /usr/local/sbin/

WORKDIR /app

COPY --from=appBuilder /app/wheels           /wheels
COPY --from=appBuilder /app/requirements.txt .

RUN pip install --no-cache /wheels/*

COPY gp-okta.py .

CMD ["./gp-okta.py", "/config/gp-okta.conf"]
