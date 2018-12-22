FROM lambci/lambda-base:build

ARG ERLANG_VERSION
ARG ELIXIR_VERSION

WORKDIR /work

COPY bootstrap /opt/

RUN curl -sSL http://erlang.org/download/otp_src_${ERLANG_VERSION}.tar.gz | \
  tar zx

RUN cd /work/otp_src_${ERLANG_VERSION} && \
  ./configure --disable-hipe --without-termcap --without-javac \
    --without-dialyzer --without-diameter --without-debugger --without-edoc \
    --without-eldap --without-jinterface --without-mnesia --without-observer \
    --without-odbc --without-tftp --without-wx --without-xmerl \
    --prefix=/opt && \
  make install

RUN curl -sOL https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/Precompiled.zip && \
  (cd /opt && unzip /work/Precompiled.zip )

RUN curl -sSL https://github.com/michalmuskala/jason/archive/v1.1.2.tar.gz | tar zx
RUN cd /opt && \
  zip -yr /tmp/otp-${ERLANG_VERSION}.zip ./*
