###############################################################################################
# OpenConnect Builder
###############################################################################################
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
	lz4-dev \
	make \
	musl-dev \
	openssl-dev \
	linux-headers

ENV VPNC_SCRIPT_PATH=/usr/local/sbin/vpnc-script
# ENV VPNC_SCRIPT_URL=http://git.infradead.org/users/dwmw2/vpnc-scripts.git/blob_plain/HEAD:/vpnc-script
ENV VPNC_SCRIPT_URL=https://gitlab.com/openconnect/vpnc-scripts/-/raw/master/vpnc-script

RUN mkdir -p /usr/local/sbin \
	&& curl -s -o "${VPNC_SCRIPT_PATH}" "${VPNC_SCRIPT_URL}" \
	&& chmod +x "${VPNC_SCRIPT_PATH}"

ENV OPENCONNECT_VERSION=v8.10
ENV OPENCONNECT_REPO=https://gitlab.com/openconnect/openconnect.git

RUN cd /tmp \
	&& git clone -b "${OPENCONNECT_VERSION}" --single-branch --depth=1 "${OPENCONNECT_REPO}" \
	&& cd openconnect \
	&& ./autogen.sh \
	&& ./configure --without-gnutls --with-vpnc-script="${VPNC_SCRIPT_PATH}" --prefix=/opt/openconnect \
	&& make check \
	&& make \
	&& make install

ENV HIREPORT_PATH=/opt/hipreport.sh
ENV HIREPORT_URL=https://raw.githubusercontent.com/openconnect/openconnect/master/trojans/hipreport.sh

RUN curl -s -o "${HIREPORT_PATH}" "${HIREPORT_URL}" \
	&& chmod +x "${HIREPORT_PATH}"

###############################################################################################
# Final image
###############################################################################################
FROM python:3.8-alpine

COPY --from=builder /usr/local/sbin/vpnc-script /usr/local/sbin/
COPY --from=builder /opt/openconnect/           /usr/local/
COPY --from=builder /opt/hipreport.sh           /opt/hipreport.sh

WORKDIR /app

COPY requirements.txt .

RUN apk add --no-cache --virtual .build-deps gcc libc-dev libxslt-dev \
	&& apk add --no-cache libxslt py3-lxml libproxy-dev libxml2-dev lz4-dev \
	&& pip install -r requirements.txt --no-cache-dir \
	&& apk del .build-deps

COPY gp-okta.py /usr/local/bin

CMD ["python", "-u", "/usr/local/bin/gp-okta.py", "/etc/gp-okta.conf"]
