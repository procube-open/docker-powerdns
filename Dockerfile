FROM alpine:latest AS builder

ENV BUILDER_VERSION 4.2.1

# For latest build deps, see https://github.com/nginxinc/docker-nginx/blob/master/mainline/alpine/Dockerfile
RUN apk add --no-cache --virtual .build-deps \
  g++ make mariadb-dev postgresql-dev sqlite-dev curl boost-dev autoconf automake libtool curl-dev file \
  bison flex ragel yaml-cpp yaml-cpp-dev openldap-dev krb5-dev lua-dev unixodbc-dev git py-virtualenv
# Download sources
RUN curl -L -o /tmp/powerdns.tar.gz "https://github.com/PowerDNS/pdns/archive/auth-${BUILDER_VERSION}.tar.gz"
# unarchive source codes
RUN mkdir -p /usr/src
WORKDIR /usr/src
RUN tar -zxf /tmp/powerdns.tar.gz
WORKDIR /usr/src/pdns-auth-${BUILDER_VERSION}

# Reuse same cli arguments as the nginx:alpine image used to build
RUN autoreconf -vi && \
    ./configure --prefix=/usr --sysconfdir=/etc/pdns --mandir=/usr/share/man --infodir=/usr/share/info \
        --localstatedir=/var --libdir=/usr/lib/pdns --with-modules= \
        --with-dynmodules='bind geoip ldap lua mydns gmysql godbc pipe gpgsql random remote gsqlite3' \
        --enable-lua-records --enable-tools --enable-unit-tests --disable-static CC=gcc \
        CFLAGS='-Os -fomit-frame-pointer' LDFLAGS=-'Wl,--as-needed' CPPFLAGS='-Os -fomit-frame-pointer' \
        CXXFLAGS='-Os -fomit-frame-pointer' && \
    make && make install
WORKDIR /

FROM alpine:latest

# install pdns-backend-mysql first, its cause isntall pdns by dependency.
RUN apk add pdns-backend-mysql libcurl

# and then override new pdns from builder.
RUN mkdir -p /usr/lib/pdns/pdns
RUN mkdir -p /etc/pdns
COPY --from=builder /usr/lib/pdns/pdns/* /usr/lib/pdns/pdns/
RUN mkdir -p /usr/share/doc/pdns
COPY --from=builder /usr/bin/pdns_control /usr/bin
COPY --from=builder /usr/bin/pdnsutil /usr/bin
COPY --from=builder /usr/bin/zone2sql /usr/bin
COPY --from=builder /usr/bin/zone2json /usr/bin
COPY --from=builder /usr/bin/dnsgram /usr/bin
COPY --from=builder /usr/bin/dnspcap2calidns /usr/bin
COPY --from=builder /usr/bin/dnsreplay /usr/bin
COPY --from=builder /usr/bin/dnsscan /usr/bin
COPY --from=builder /usr/bin/dnsscope /usr/bin
COPY --from=builder /usr/bin/dnswasher /usr/bin
COPY --from=builder /usr/bin/dumresp /usr/bin
COPY --from=builder /usr/bin/pdns_notify /usr/bin
COPY --from=builder /usr/bin/nproxy /usr/bin
COPY --from=builder /usr/bin/nsec3dig /usr/bin
COPY --from=builder /usr/bin/saxfr /usr/bin
COPY --from=builder /usr/bin/stubquery /usr/bin
COPY --from=builder /usr/bin/ixplore /usr/bin
COPY --from=builder /usr/bin/sdig /usr/bin
COPY --from=builder /usr/bin/calidns /usr/bin
COPY --from=builder /usr/bin/dnsbulktest /usr/bin
COPY --from=builder /usr/bin/dnstcpbench /usr/bin
COPY --from=builder /usr/bin/zone2ldap /usr/bin
COPY --from=builder /usr/sbin/pdns_server /usr/sbin
COPY --from=builder /etc/pdns/pdns.conf-dist /etc/pdns
RUN mkdir -p /usr/share/man/man1
COPY --from=builder /usr/share/man/man1/* /usr/share/man/man1/

# setup as container
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY pdns.conf /etc/pdns
RUN chmod +x /docker-entrypoint.sh
EXPOSE 53/tcp
EXPOSE 53/udp
EXPOSE 8081/tcp
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["pdns_server"]
