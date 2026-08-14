FROM zmkfirmware/zmk-dev-arm:4.1.0-0.16.9

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

ENV ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk-${ZEPHYR_SDK_VERSION}
ENV CLAUDE_CONFIG_DIR=/home/${USERNAME}/.claude
ENV DEVCONTAINER=true

RUN apt-get -y update \
    && apt-get -y install --no-install-recommends clangd sudo jq \
    && rm -rf /var/lib/apt/lists/*

# noble pre-creates `ubuntu` at 1000:1000. updateRemoteUserUID silently no-ops
# when the UID is taken. The host then gets root-owned files.
RUN if getent passwd ${USER_UID} >/dev/null; then \
        userdel --remove "$(getent passwd ${USER_UID} | cut -d: -f1)"; \
    fi \
    && if getent group ${USER_GID} >/dev/null; then \
        groupdel "$(getent group ${USER_GID} | cut -d: -f1)"; \
    fi \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

RUN mkdir -p /home/${USERNAME}/.claude /build \
    && chown -R ${USER_UID}:${USER_GID} /home/${USERNAME} /build

USER ${USERNAME}
WORKDIR /workspaces/zmk/zmk-config

ENV PATH=/home/${USERNAME}/.local/bin:${PATH}
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && claude --version

USER root
COPY claude-settings.json /etc/claude-code/managed-settings.json
USER ${USERNAME}
