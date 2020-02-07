FROM lambci/lambda-base:build

ARG ERLANG_VERSION
ARG ELIXIR_VERSION

LABEL erlang.version=${ERLANG_VERSION} \
      elixir.version=${ELIXIR_VERSION}

WORKDIR /work

RUN curl -SL http://erlang.org/download/otp_src_${ERLANG_VERSION}.tar.gz | tar xz && \
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
  rm -r /opt/lib/erlang/lib/*/src /opt/lib/erlang/misc /opt/lib/erlang/usr /opt/bin/ct_run /opt/bin/dialyzer /opt/bin/typer

RUN curl -SLo /work/Precompiled.zip https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/Precompiled.zip && \
  cd /opt && \
  unzip -q /work/Precompiled.zip && \
  rm -r /opt/lib/elixir/lib /opt/lib/eex/lib /opt/lib/logger/lib /opt/man /opt/lib/ex_unit/lib /opt/lib/iex /opt/bin/*.bat /opt/bin/*.ps1

COPY bootstrap /opt/
COPY runtime/ /work/runtime/

RUN cd /work/runtime && \
  mix local.hex --force && \
  mix deps.get && \
  mix test && \
  MIX_ENV=prod mix package && \
  rm -r _build/prod/lib/*/.mix _build/prod/lib/runtime/consolidated && \
  cp -r _build/prod/lib/* /opt/lib && \
  chmod 555 /opt/bootstrap

# Package
RUN cd /opt && \
  zip -qyr /tmp/runtime.zip ./*
