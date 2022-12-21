FROM crystallang/crystal

# make dir opt/app
RUN mkdir -p /opt/app

# copy src to /app
COPY . /opt/app

# set workdir to /app
WORKDIR /opt/app

RUN shards install
RUN shards build --release --no-debug
ENTRYPOINT [ "/opt/app/bin/monitor" ]