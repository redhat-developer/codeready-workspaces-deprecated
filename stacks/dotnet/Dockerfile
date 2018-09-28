FROM docker-registry.default.svc:5000/openshift/rhel-base-jdk8
ENV PATH="/opt/rh/rh-dotnet20/root/usr/bin:/opt/rh/rh-dotnet20/root/usr/sbin${PATH:+:${PATH}}" \
    CPATH="/opt/rh/rh-dotnet20/root/usr/include${CPATH:+:${CPATH}}" \
    LD_LIBRARY_PATH="/opt/rh/rh-dotnet20/root/usr/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
    MANPATH="/opt/rh/rh-dotnet20/root/usr/share/man:${MANPATH:-}" \
    PKG_CONFIG_PATH="/opt/rh/rh-dotnet20/root/usr/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}" \
    PYTHONPATH=/opt/rh/rh-nodejs8/root/usr/lib/python2.7/site-packages${PYTHONPATH:+:${PYTHONPATH}}:/opt/rh/rh-dotnet20/root${PYTHONPATH:+:${PYTHONPATH}} \
    XDG_DATA_DIRS=/opt/rh/rh-dotnet20/root/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share} \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    OMNISHARP_LS_VERSION=1.31.1 \
    LS_DIR=${HOME}/che/ls-csharp \
    DOTNET_SDK_PATH=/opt/rh/rh-dotnet20/root/usr/lib64/dotnet/sdk \
    NPM_CONFIG_PREFIX=$HOME/.npm-global \
    MANPATH=/opt/rh/rh-nodejs8/root/usr/share/man:$MANPATH

RUN INSTALL_PKGS="rh-dotnet20-dotnet-sdk-2.0 rh-dotnet20-dotnet-runtime-2.0 rh-dotnet20-dotnet-sdk-2.0" && \
    sudo yum install -y --setopt=tsflags=nodocs --disablerepo=\* \
      --enablerepo=rhel-7-server-rpms,rhel-server-rhscl-7-rpms,rhel-7-server-dotnet-rpms \
    $INSTALL_PKGS && \
    sudo rpm -V $INSTALL_PKGS && \
    sudo yum clean all -y  && \
# install Omnisharp Language server
    mkdir -p ${LS_DIR} && \
    cd ${LS_DIR} && \
    wget https://github.com/OmniSharp/omnisharp-roslyn/releases/download/v${OMNISHARP_LS_VERSION}/omnisharp-linux-x64.tar.gz && \
    tar -xvf omnisharp-linux-x64.tar.gz && \
    rm omnisharp-linux-x64.tar.gz && \
    echo "${LS_DIR}/run -lsp" > ${LS_DIR}/launch.sh && \
    chmod +x ${LS_DIR}/launch.sh && \
    chgrp -R 0 ${LS_DIR}  && \
    chmod -R g+rwX ${LS_DIR} && \
    # workaround for RHEL to make sure Language Server from OnmiSharp works fine
    sudo ln -s ${DOTNET_SDK_PATH}/2.0.3/Sdks/Microsoft.NET.Sdk/tools/netcoreapp1.0 ${DOTNET_SDK_PATH}/2.0.3/Sdks/Microsoft.NET.Sdk/tools/net46
