FROM zalando/openjdk:8u45-b14-3

MAINTAINER Zalando <team-mop@zalando.de>

# Storage Port, JMX, Jolokia Agent, Thrift, CQL Native, OpsCenter Agent
# Left out: SSL
EXPOSE 7000 7199 8778 9042 9160 61621

ENV DEBIAN_FRONTEND=noninteractive
RUN echo "deb http://debian.datastax.com/community stable main" | tee -a /etc/apt/sources.list.d/datastax.community.list
RUN curl -sL https://debian.datastax.com/debian/repo_key | apt-key add -
RUN apt-get -y update && apt-get -y -o Dpkg::Options::='--force-confold' dist-upgrade
RUN apt-get -y install curl libjna-java python wget jq datastax-agent sysstat python-pip supervisor && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#Needed for transferring snapshots
RUN pip install awscli

ENV CASSIE_VERSION=2.1.11
ADD http://ftp.halifax.rwth-aachen.de/apache/cassandra/${CASSIE_VERSION}/apache-cassandra-${CASSIE_VERSION}-bin.tar.gz /tmp/
# COPY apache-cassandra-${CASSIE_VERSION}-bin.tar.gz /tmp/

RUN tar -xzf /tmp/apache-cassandra-${CASSIE_VERSION}-bin.tar.gz -C /opt && ln -s /opt/apache-cassandra-${CASSIE_VERSION} /opt/cassandra
RUN rm -f /tmp/apache-cassandra-${CASSIE_VERSION}-bin.tar.gz

RUN mkdir -p /var/cassandra/data
RUN mkdir -p /opt/jolokia/

ADD http://search.maven.org/remotecontent?filepath=org/jolokia/jolokia-jvm/1.3.1/jolokia-jvm-1.3.1-agent.jar /opt/jolokia/jolokia-jvm-agent.jar
ADD cassandra_template.yaml /opt/cassandra/conf/
#Slightly modified in order to run jolokia
ADD cassandra-env.sh /opt/cassandra/conf/

RUN rm -f /opt/cassandra/conf/cassandra.yaml && chmod 0777 /opt/cassandra/conf/
RUN ln -s /opt/cassandra/bin/nodetool /usr/bin && ln -s /opt/cassandra/bin/cqlsh /usr/bin

ADD https://bintray.com/artifact/download/lmineiro/maven/cassandra-etcd-seed-provider-1.0.jar /opt/cassandra/lib/

COPY cassandraSnapshotter.sh /opt/cassandra/bin/cassandraSnapshotter.sh
COPY snapshotScheduler.sh /opt/cassandra/bin/snapshotScheduler.sh
COPY seedHeartBeat.sh /opt/cassandra/bin/seedHeartBeat.sh

COPY stups-cassandra.sh /opt/cassandra/bin/

# Create supervisor log folder
RUN mkdir -p /var/log/supervisor && chmod 0777 /var/log/supervisor
RUN touch /var/log/snapshot_cron.log && chmod 0777 /var/log/snapshot_cron.log

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

CMD ["/usr/bin/supervisord"]
