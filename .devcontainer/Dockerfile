FROM erlang:21.3.8.24

# Исходный образ основан на buildpack-deps:buster, 
# а пакеты для этой версии debian уже перемещены в архив,
# поэтому сборка образа без правки репозиториев падает
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i '/buster-updates/d' /etc/apt/sources.list 
    
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl git build-essential netcat iputils-ping jq
    # rm -rf /var/lib/apt/lists/*

# По информации из https://github.com/erlang/docker-erlang-otp/blob/master/21/Dockerfile,
# последняя поддерживаемая версия rebar3 для OTP 21 = 3.15.2
RUN curl -Lo /usr/local/bin/rebar3 https://github.com/erlang/rebar3/releases/download/3.15.2/rebar3 && \
    chmod +x /usr/local/bin/rebar3 && \
    # проверка, что rebar3 видно в контейнере
    rebar3 --version

# Для расширения "pgourlain.erlang@0.8.3" нужен erlang_ls 0.23.1 (последний с поддержкой OTP 21)
# кешируем git clone
RUN --mount=type=cache,target=/tmp/git_cache,sharing=locked \  
    git clone --branch 0.23.1 --depth 1 https://github.com/erlang-ls/erlang_ls.git /tmp/erlang_ls && \
    cd /tmp/erlang_ls && \
    make && \
    make install && \
    rm -rf /tmp/erlang_ls

RUN groupadd -g 1001 vscodegrp && \
    useradd -u 1000 -g vscodegrp -m -s /bin/bash vscode

USER vscode
WORKDIR /workspace