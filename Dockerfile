# syntax=docker/dockerfile:1.3-labs

FROM golang:1.17-alpine3.15 AS ipfs_build

# This is set in the CI as well, be sure to update in both places
ARG IPFS_TAG="v0.11.0"

ENV SRC_DIR /go/src/github.com/ipfs/go-ipfs

RUN apk add --no-cache git make bash gcc musl-dev
  # && go get -u github.com/whyrusleeping/gx

# Fixes an issue with symlinked binaries not playing well with musl
# Thanks https://stackoverflow.com/questions/34729748/installed-go-binary-not-found-in-path-on-alpine-linux-docker
# RUN mkdir /lib64 && ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2

WORKDIR /target

RUN <<EOF
set -ex
git clone --branch $IPFS_TAG https://github.com/ipfs/go-ipfs.git $SRC_DIR
cd $SRC_DIR
make build
cp $SRC_DIR/cmd/ipfs/ipfs /target/ipfs
rm -rf $SRC_DIR
EOF

FROM node:16.13.1-alpine
RUN npm i -g npm@latest

ARG LOGLEVEL
ENV NPM_CONFIG_LOGLEVEL ${LOGLEVEL}

COPY --from=ipfs_build /target /usr/local/bin

WORKDIR /vitalam-ipfs

# Install base dependencies
COPY . .
RUN npm ci --production

ENV IPFS_PATH=/ipfs

# Expose 80 for healthcheck
EXPOSE 80
# Expose 4001 for ipfs swarm
EXPOSE 4001
# expose 5001 for ipfs api
EXPOSE 5001

HEALTHCHECK CMD curl --fail http://localhost:80/health || exit 1

ENTRYPOINT [ "./app/index.js" ]
