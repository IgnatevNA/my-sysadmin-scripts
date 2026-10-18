FROM ubuntu:22.04

RUN apt-get update && apt-get install -y procps && rm -rf /var/lib/apt/lists/*

COPY script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh

WORKDIR /var/log/monitor

CMD ["/usr/local/bin/script.sh"]
