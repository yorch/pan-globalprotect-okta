FROM alpine:3 AS builder

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
	make \
	musl-dev \
	openssl-dev \
	linux-headers

ENV VPNC_SCRIPT_PATH=/usr/local/sbin/vpnc-script

RUN mkdir -p /usr/local/sbin \
	&& curl -o ${VPNC_SCRIPT_PATH} http://git.infradead.org/users/dwmw2/vpnc-scripts.git/blob_plain/HEAD:/vpnc-script \
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
# Final image
###############################################################################################
FROM python:3.8-alpine

COPY --from=builder /usr/local/sbin/openconnect /usr/local/sbin/
COPY --from=builder /usr/local/sbin/vpnc-script /usr/local/sbin/

WORKDIR /app

COPY requirements.txt .

RUN apk add --no-cache --virtual .build-deps gcc libc-dev libxslt-dev \
	&& apk add --no-cache libxslt py3-lxml \
	&& pip install -r requirements.txt --no-cache-dir \
	&& apk del .build-deps

COPY gp-okta.py .

CMD ["./gp-okta.py", "/config/gp-okta.conf"]
