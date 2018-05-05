0. (Only do this once) Build the Docker image
```bash
$ docker build -t kafka-connect-cassandra .
# This creates a new docker image based off of Confluent's cp-kafka-connect image
# It downloads and extracts the Cassandra sink connector onto the plugin path for Kafka connect
```

1. Start ZooKeeper, Kafka, Schema Registry, Kafka Connect, and Cassandra, each in their own Docker
container:
```bash
$ docker-compose up -d
```

1.5 Wait for Schema Registry to start:
```bash
$ docker-compose logs -f schema-registry | grep started
# Look for a line like this:
# schema-registry            | [2018-05-04 02:05:12,593] INFO Server started, listening for requests... (io.confluent.kafka.schemaregistry.rest.SchemaRegistryMain
# ^C to stop viewing logs once you see it.
```

2. Create and populate a topic for the connector to consume from
```bash
$ java -jar arg.jar -c -i 10 -f value.avsc |
    docker-compose exec -T kafka-connect \
      kafka-avro-console-producer \
        --broker-list localhost:29092 \
        --topic cassandra-connector-quickstart \
        --property schema.registry.url=http://localhost:28081 \
        --property value.schema="$(cat value.avsc)"
```

2.5 Wait for connect to start
```bash
$ docker-compose logs -f kafka-connect| grep 'Kafka Connect started'
# Look for a line like this:
# kafka-connect-cassandra    | [2016-08-25 18:25:19,676] INFO Kafka Connect started (org.apache.kafka.connect.runtime.Connect)
# ^C to stop viewing logs once you see it.
```

3. Start the Cassandra connector
```bash
$ docker-compose exec kafka-connect curl \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d "$(cat cassandra-sink.json)" \
    localhost:28082/connectors
```

3.5. Verify that the Avro data made it into Kafka
```bash
$ docker-compose exec kafka-connect kafka-avro-console-consumer \
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

4. Verify that the Kafka data made it into Cassandra
```bash
$ docker-compose exec cassandra cqlsh \
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

?. If you need/want to poke around inside things, enter the Docker container for Kafka Connect:
```bash
$ docker-compose exec kafka-connect bash
```
or for Cassandra:
```bash
$ docker-compose exec cassandra bash
```