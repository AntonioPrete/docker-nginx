FROM nginx:1.21.6-alpine

ENV OTEL_VERSION 1.0.1

RUN set -x \
    && apkArch="$(cat /etc/apk/arch)" \
    && nginxPackages="nginx-module-geoip nginx-module-image-filter nginx-module-njs nginx-module-xslt" \
    && apk add --no-cache --virtual .checksum-deps \
        openssl \
    && case "$apkArch" in \
        x86_64|aarch64) \
            apk add -X "http://dl-cdn.alpinelinux.org/alpine/v3.14/main" --no-cache $nginxPackages \
            ;; \
        *) \
            set -x \
            && tempDir="$(mktemp -d)" \
            && chown nobody:nobody $tempDir \
            && apk add --no-cache --virtual .build-deps \
                gcc \
                libc-dev \
                make \
                openssl-dev \
                pcre2-dev \
                zlib-dev \
                linux-headers \
                cmake \
                bash \
                alpine-sdk \
                findutils \
                curl \
                xz \
                re2-dev \
                c-ares-dev \
            && su nobody -s /bin/sh -c " \
                export HOME=${tempDir} \
                && cd ${tempDir} \
                && curl -f -L -O https://github.com/nginx/pkg-oss/archive/1.21.6.tar.gz \
                && PKGOSSCHECKSUM=\"sha512-checksum-value *1.21.6.tar.gz\" \
                && if [ \"\$(openssl sha512 -r 1.21.6.tar.gz)\" = \"\$PKGOSSCHECKSUM\" ]; then \
                    echo \"pkg-oss tarball checksum verification succeeded!\"; \
                else \
                    echo \"pkg-oss tarball checksum verification failed!\"; \
                    exit 1; \
                fi \
                && tar xzvf 1.21.6.tar.gz \
                && cd pkg-oss-1.21.6 \
                && cd alpine \
                && make build \
                && apk index --allow-untrusted -o ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz ${tempDir}/packages/alpine/${apkArch}/*.apk \
                && abuild-sign -k ${tempDir}/.abuild/abuild-key.rsa ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz \
                " \
            && cp ${tempDir}/.abuild/abuild-key.rsa.pub /etc/apk/keys/ \
            && apk del --no-network .build-deps \
            && apk add -X ${tempDir}/packages/alpine/ --no-cache $nginxPackages \
            ;; \
    esac \
    && apk del --no-network .checksum-deps \
    && if [ -n "$tempDir" ]; then rm -rf "$tempDir"; fi \
    && if [ -f "/etc/apk/keys/abuild-key.rsa.pub" ]; then rm -f /etc/apk/keys/abuild-key.rsa.pub; fi