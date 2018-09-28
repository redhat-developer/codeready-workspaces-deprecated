FROM docker-registry.default.svc:5000/openshift/rhel-base-jdk8
ENV GOPATH=/projects/.che/gopath \
    GOLANG_LS_VERSION="0.1.7" \
    NPM_CONFIG_PREFIX=$HOME/.npm-global \
    PATH=$HOME/node_modules/.bin/:$HOME/.npm-global/bin/:/opt/rh/rh-nodejs8/root/usr/bin:$PATH \
    LD_LIBRARY_PATH=/opt/rh/rh-nodejs8/root/usr/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}} \
    PYTHONPATH=/opt/rh/rh-nodejs8/root/usr/lib/python2.7/site-packages${PYTHONPATH:+:${PYTHONPATH}} \
    MANPATH=/opt/rh/rh-nodejs8/root/usr/share/man:$MANPATH

RUN sudo subscription-manager repos --enable=rhel-7-server-optional-rpms && \
    sudo yum install yum-utils golang -y && \
    sudo prepare-yum-repositories rhel-server-rhscl-7-rpms && \
    sudo yum remove -y rh-nodejs6\* && \
    INSTALL_PKGS="rh-nodejs8 rh-nodejs8-npm rh-nodejs8-nodejs-nodemon nss_wrapper" && \
    sudo ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    sudo yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    sudo rpm -V $INSTALL_PKGS && \
    sudo yum clean all -y && \
    mkdir -p ${HOME}/che/ls-golang /projects/.che/gopath && \
    echo -e "if [ ! -d "/projects/.che/gopath/src" ]; then\necho "Copying GO LS Deps"\nmkdir -p /projects/.che/gopath\n cp -R /tmp/gopath/* /projects/.che/gopath\nfi" \
    > ${HOME}/gopath.sh && \
    chmod +x ${HOME}/gopath.sh && \
    cd ${HOME}/che/ls-golang && \
    npm i go-language-server@${GOLANG_LS_VERSION} && \
    export GOPATH=/tmp/gopath && \
    go get -v github.com/nsf/gocode && \
    go get -v github.com/uudashr/gopkgs/cmd/gopkgs && \
    go get -v github.com/ramya-rao-a/go-outline && \
    go get -v github.com/acroca/go-symbols && \
    go get -v golang.org/x/tools/cmd/guru && \
    go get -v golang.org/x/tools/cmd/gorename && \
    go get -v github.com/fatih/gomodifytags && \
    go get -v github.com/haya14busa/goplay/cmd/goplay && \
    go get -v github.com/josharian/impl && \
    go get -v github.com/tylerb/gotype-live && \
    go get -v github.com/rogpeppe/godef && \
    go get -v golang.org/x/tools/cmd/godoc && \
    go get -v github.com/zmb3/gogetdoc && \
    go get -v golang.org/x/tools/cmd/goimports && \
    go get -v sourcegraph.com/sqs/goreturns && \
    go get -v github.com/golang/lint/golint && \
    go get -v github.com/cweill/gotests/... && \
    go get -v github.com/alecthomas/gometalinter && \
    go get -v honnef.co/go/tools/... && \
    go get -v github.com/sourcegraph/go-langserver && \
    go get -v github.com/derekparker/delve/cmd/dlv && \
    mkdir -p ${HOME}/.cache && \
    for f in "${HOME}/che" "${HOME}/.cache"; do \
        sudo chgrp -R 0 ${f} && \
        sudo chmod -R g+rwX ${f}; \
    done && \
    sudo ln -s /opt/rh/rh-nodejs8/root/usr/bin/node /usr/local/bin/nodejs
CMD ${HOME}/gopath.sh & tail -f /dev/null
