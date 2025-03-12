ARG TRINO_VERSION
ARG JMX_AGENT_VERSION=${JMX_AGENT_VERSION}

FROM trinodb/trino:${TRINO_VERSION}
USER root
# jmx prometheus exporter jar
RUN curl -L https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar -o /usr/lib/trino/lib/jmx_prometheus_javaagent.jar

COPY docker/jmx.config.yaml /usr/lib/trino/lib/jmx.config.yaml

USER trino
