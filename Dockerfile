FROM ubuntu:24.04 AS ruby-builder

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates gnupg build-essential pkg-config libssl-dev zlib1g-dev libffi-dev libyaml-dev \
    autoconf bison libreadline-dev libncurses5-dev libgdbm-dev libdb-dev \
    libbrotli-dev libexpat1-dev libxml2-dev libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*

ARG RUBY_VERSION=3.3.0
WORKDIR /tmp
RUN curl -fsSL "https://cache.ruby-lang.org/pub/ruby/3.3/ruby-${RUBY_VERSION}.tar.gz" -o ruby.tar.gz \
    && tar -xzf ruby.tar.gz \
    && cd ruby-${RUBY_VERSION} \
    && ./configure --disable-install-doc \
    && make -j"$(nproc)" \
    && make install \
    && cd .. \
    && rm -rf ruby-${RUBY_VERSION} ruby.tar.gz

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# Install all required packages in one go, no recommends, then cleanup.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git vim nano build-essential gcc g++ make \
    apt-transport-https ca-certificates gnupg lsb-release \
    pkg-config libssl-dev zlib1g-dev jq yq htop ncdu zip unzip tree tmux \
    fd-find fzf ripgrep libffi-dev libyaml-dev \
    python3 python3-pip python3-venv \
    autoconf bison libreadline-dev libncurses5-dev libgdbm-dev libdb-dev \
    libbrotli-dev libexpat1-dev libxml2-dev libxslt1-dev \
    nmap net-tools traceroute tcpdump neovim \
    iputils-ping dnsutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash \
    && echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.bashrc \
    && echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc

ENV BUN_INSTALL="/root/.bun"
ENV PATH="/root/.bun/bin:${PATH}"

# Install Node.js 20 (via NodeSource)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Go 1.22
ARG GO_VERSION=1.22.10
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o go.tar.gz \
    && tar -C /usr/local -xzf go.tar.gz \
    && rm go.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Install Rust (stable)
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup default stable

# Copy Ruby from builder stage
COPY --from=ruby-builder /usr/local/ /usr/local/

# Install Bundler
RUN gem install bundler && bundle --version

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

WORKDIR /app
COPY verify.sh /usr/local/bin/verify
RUN chmod +x /usr/local/bin/verify

CMD ["bash"]
