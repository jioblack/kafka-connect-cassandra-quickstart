0. (Only do this once) Build the Docker image
```bash
$ docker build -t kafka-connect-cassandra .
```

1. Start ZooKeeper
```bash
$ docker run -d \
    --net=host \
    --name=zookeeper \
    -e ZOOKEEPER_CLIENT_PORT=32181 \
    confluentinc/cp-zookeeper
```

2. Start Kafka
```bash
$ docker run -d \
    --net=host \
    --name=kafka \
    -e KAFKA_ZOOKEEPER_CONNECT=localhost:32181 \
    -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:29092 \
    -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
    confluentinc/cp-kafka
```

3. Start Schema Registry
```bash
$ docker run -d \
  --net=host \
  --name=schema-registry \
  --hostname=localhost \
  -e SCHEMA_REGISTRY_KAFKASTORE_CONNECTION_URL=localhost:32181 \
  -e SCHEMA_REGISTRY_HOST_NAME=localhost \
  -e SCHEMA_REGISTRY_LISTENERS=http://localhost:28081 \
  confluentinc/cp-schema-registry
```

4. Start Kafka Connect with default key/value converters of AvroConverter
```bash
$ docker run -d \
  --name=kafka-connect-cassandra \
  --net=host \
  --hostname=localhost \
  -e CONNECT_PRODUCER_INTERCEPTOR_CLASSES=io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor \
  -e CONNECT_CONSUMER_INTERCEPTOR_CLASSES=io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor \
  -e CONNECT_BOOTSTRAP_SERVERS=localhost:29092 \
  -e CONNECT_REST_PORT=28082 \
  -e CONNECT_GROUP_ID="quickstart" \
  -e CONNECT_CONFIG_STORAGE_TOPIC="quickstart-config" \
  -e CONNECT_OFFSET_STORAGE_TOPIC="quickstart-offsets" \
  -e CONNECT_STATUS_STORAGE_TOPIC="quickstart-status" \
  -e CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR=1 \
  -e CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR=1 \
  -e CONNECT_STATUS_STORAGE_REPLICATION_FACTOR=1 \
  -e CONNECT_KEY_CONVERTER="io.confluent.connect.avro.AvroConverter" \
  -e CONNECT_KEY_CONVERTER_SCHEMA_REGISTRY_URL="http://localhost:28081" \
  -e CONNECT_VALUE_CONVERTER="io.confluent.connect.avro.AvroConverter" \
  -e CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL="http://localhost:28081" \
  -e CONNECT_INTERNAL_KEY_CONVERTER="org.apache.kafka.connect.json.JsonConverter" \
  -e CONNECT_INTERNAL_VALUE_CONVERTER="org.apache.kafka.connect.json.JsonConverter" \
  -e CONNECT_REST_ADVERTISED_HOST_NAME="localhost" \
  -e CONNECT_LOG4J_ROOT_LOGLEVEL=DEBUG \
  -e CONNECT_LOG4J_LOGGERS=org.reflections=ERROR \
  -e CONNECT_PLUGIN_PATH=/usr/share/java \
  -e CONNECT_REST_HOST_NAME="localhost" \
  kafka-connect-cassandra
```

5. Start Cassandra
```bash
$ docker exec kafka-connect-cassandra bash -c 'cassandra -R > /dev/null 2> /dev/null'
```

6. Create and populate a topic for the connector to consume from
```bash
$ java -jar arg.jar -c -i 10 -f value.avsc |
    docker exec -i kafka-connect-cassandra \
      kafka-avro-console-producer \
        --broker-list localhost:29092 \
        --topic cassandra-connector-quickstart \
        --property schema.registry.url=http://localhost:28081 \
        --property value.schema="$(cat value.avsc)"
```

6.5 Wait for connect to start
```bash
$ docker logs -f kafka-connect-cassandra | grep started
# Look for something like:
# [2016-08-25 18:25:19,665] INFO Herder started (org.apache.kafka.connect.runtime.distributed.DistributedHerder)
# [2016-08-25 18:25:19,676] INFO Kafka Connect started (org.apache.kafka.connect.runtime.Connect)
# ^C to stop viewing logs once you see this.
```

7. Start the Cassandra connector
```bash
$ docker exec kafka-connect-cassandra curl \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d "$(cat cassandra-sink.json)" \
    localhost:28082/connectors
```

7.5. Verify that the Avro data made it into Kafka
```bash
$ docker exec kafka-connect-cassandra kafka-avro-console-consumer \
    --topic cassandra-connector-quickstart \
    --bootstrap-server localhost:29092 \
    --property schema.registry.url=http://localhost:28081 \
    --max-messages 10 \
    --from-beginning
# Wait for something like:
# {"value":"poor","key":1}
# {"value":"good","key":18}
# {"value":"bad","key":35}
# {"value":"bad","key":52}
# {"value":"poor","key":69}
# {"value":"fair","key":86}
# {"value":"bad","key":103}
# {"value":"poor","key":120}
# {"value":"good","key":137}
# {"value":"good","key":154}
# Processed a total of 10 messages
```

8. Verify that the Kafka data made it into Cassandra
```bash
$ docker exec -it kafka-connect-cassandra cqlsh \
    --keyspace=kafka_connector_quickstart_keyspace \
    --execute='SELECT * FROM kafka_connector_quickstart_table;'
# Should see something like:
#  key | value
# -----+-------
#  120 |  poor
#  137 |  good
#    1 |  poor
#   52 |   bad
#   18 |  good
#   69 |  poor
#   86 |  fair
#   35 |   bad
#  154 |  good
#  103 |   bad
#
# (10 rows)
```

?. If you need/want to poke around inside things, enter the Docker container for Kafka Connect
```bash
$ docker exec -it kafka-connect-cassandra bash
```