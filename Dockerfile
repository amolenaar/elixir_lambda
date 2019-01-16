FROM lambci/lambda-base:build

ARG ERLANG_VERSION
ARG ELIXIR_VERSION

WORKDIR /work

ADD https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/Precompiled.zip /work/
ADD http://erlang.org/download/otp_src_${ERLANG_VERSION}.tar.gz /work/


RUN tar xf otp_src_${ERLANG_VERSION}.tar.gz && \
  cd /work/otp_src_${ERLANG_VERSION} && \
  ./configure --disable-hipe --without-termcap --without-javac \
    --without-dialyzer --without-diameter --without-debugger --without-edoc \
    --without-eldap --without-erl_docgen --without-mnesia --without-observer \
    --without-odbc --without-tftp --without-wx --without-xmerl --without-otp_mibs \
    --without-reltool --without-snmp --without-tftp \
    --without-common_test --without-eunit --without-ftp --without-hipe \
    --without-megaco --without-sasl  --without-syntax_tools --without-tools \
    --prefix=/opt && \
  make install && \
  cd /opt && unzip /work/Precompiled.zip && \
  rm -r /opt/lib/erlang/lib/*/src /opt/lib/erlang/misc /opt/lib/erlang/usr && \
  rm -r /opt/lib/elixir/lib /opt/lib/eex/lib /opt/lib/logger/lib /opt/man && \
  rm -r /opt/lib/ex_unit/lib /opt/lib/mix/lib /opt/lib/iex

COPY bootstrap /opt/
COPY runtime/ /work/runtime/

RUN cd /work/runtime && \
  mix local.hex --force && \
  mix test && \
  MIX_ENV=prod mix package && \
  rm -r _build/prod/lib/*/.mix _build/prod/lib/runtime/consolidated && \
  cp -r _build/prod/lib/* /opt/lib

# Package
RUN cd /opt && \
  zip -yr /tmp/runtime.zip ./*

  # zip -yr /tmp/runtime.zip bootstrap LICENSE bin/elixir bin/erl lib/eex/ebin lib/exixir/ebin \
  #   lib/jason/ebin lib/logger/ebin lib/runtime/ebin lib/erlang
