FROM confluentinc/cp-kafka-connect
MAINTAINER Chris Egerton <chrise@confluent.io>

# Install the Cassandra connector onto the plugin path
# TODO: Remove this once the confluent-hub install script is available in our cp-kafka-connect image
RUN apt-get update && apt-get install --assume-yes unzip
RUN wget -O /tmp/cassandra-connector.zip http://plugin-registry-staging.us-west-1.elasticbeanstalk.com/api/plugins/jcustenborder/kafka-connect-cassandra/versions/0.1.9/archive
RUN unzip /tmp/cassandra-connector.zip -d /usr/share/java
