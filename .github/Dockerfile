FROM docker.elastic.co/logstash/logstash:7.3.0

USER 0

COPY *.gem /plugins/

RUN logstash-plugin install --no-verify /plugins/*.gem

COPY .github/*.test /
