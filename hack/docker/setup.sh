#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

GOPATH=$(go env GOPATH)
SRC=$GOPATH/src
BIN=$GOPATH/bin
ROOT=$GOPATH
REPO_ROOT=$GOPATH/src/github.com/k8sdb/postgres

source "$REPO_ROOT/hack/libbuild/common/lib.sh"
source "$REPO_ROOT/hack/libbuild/common/public_image.sh"

APPSCODE_ENV=${APPSCODE_ENV:-dev}
IMG=k3pc

DIST=$GOPATH/src/github.com/k8sdb/postgres/dist
mkdir -p $DIST
if [ -f "$DIST/.tag" ]; then
	export $(cat $DIST/.tag | xargs)
fi

clean() {
    pushd $GOPATH/src/github.com/k8sdb/postgres/hack/docker
    rm k3pc Dockerfile
    popd
}

build_binary() {
    pushd $GOPATH/src/github.com/k8sdb/postgres
    ./hack/builddeps.sh
    ./hack/make.py build k3pc
    detect_tag $DIST/.tag
    popd
}

build_docker() {
    pushd $GOPATH/src/github.com/k8sdb/postgres/hack/docker
    cp $DIST/k3pc/k3pc-linux-amd64 k3pc
    chmod 755 k3pc

    cat >Dockerfile <<EOL
FROM alpine

COPY k3pc /k3pc

USER nobody:nobody
ENTRYPOINT ["/k3pc"]
EOL
    local cmd="docker build -t appscode/$IMG:$TAG ."
    echo $cmd; $cmd

    rm k3pc Dockerfile
    popd
}

build() {
    build_binary
    build_docker
}

docker_push() {
    if [ "$APPSCODE_ENV" = "prod" ]; then
        echo "Nothing to do in prod env. Are you trying to 'release' binaries to prod?"
        exit 0
    fi

    if [[ "$(docker images -q appscode/$IMG:$TAG 2> /dev/null)" != "" ]]; then
        docker_up $IMG:$TAG
    fi
}

docker_release() {
    if [ "$APPSCODE_ENV" != "prod" ]; then
        echo "'release' only works in PROD env."
        exit 1
    fi
    if [ "$TAG_STRATEGY" != "git_tag" ]; then
        echo "'apply_tag' to release binaries and/or docker images."
        exit 1
    fi

    if [[ "$(docker images -q appscode/$IMG:$TAG 2> /dev/null)" != "" ]]; then
        docker push appscode/$IMG:$TAG
    fi
}

source_repo $@
