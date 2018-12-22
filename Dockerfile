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
    --without-eldap --without-erl_docgen --without-jinterface --without-mnesia --without-observer \
    --without-odbc --without-tftp --without-wx --without-xmerl --without-otp_mibs \
    --without-reltool --without-snmp --without-tftp \
    --prefix=/opt && \
  make install && \
  cd /opt && unzip /work/Precompiled.zip

COPY bootstrap /opt/
COPY runtime/ /work/runtime/

RUN cd /work/runtime && \
  mix local.hex --force && \
  mix test && \
  MIX_ENV=prod mix compile && \
  cp -r _build/prod/lib/* /opt/lib

# Package
RUN cd /opt && \
  zip -yr /tmp/runtime.zip ./*

