FROM confluentinc/cp-kafka-connect
MAINTAINER Chris Egerton <chrise@confluent.io>

# Install Cassandra (following instructions found at http://cassandra.apache.org/download/)
RUN echo "deb http://www.apache.org/dist/cassandra/debian 311x main" >> /etc/apt/sources.list.d/cassandra.sources.list
RUN curl https://www.apache.org/dist/cassandra/KEYS | apt-key add -
RUN apt-get update
RUN apt-get install --assume-yes cassandra

# Install the Cassandra connector onto the plugin path
RUN apt-get install --assume-yes unzip
RUN wget -O /tmp/cassandra-connector.zip http://plugin-registry-staging.us-west-1.elasticbeanstalk.com/api/plugins/jcustenborder/kafka-connect-cassandra/versions/0.1.9/archive
RUN unzip /tmp/cassandra-connector.zip -d /usr/share/java
