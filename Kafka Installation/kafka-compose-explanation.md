# Kafka KRaft Cluster: Compose File Explanation

This document explains each part of `kafka-compose.yml`, which runs one KRaft controller and three brokers on the Hadoop cluster network.

Start the cluster with:

```bash
docker compose -f kafka-compose.yml up -d
```

## Top-level name

```yaml
name: kafka_cluster
```

This sets the Compose project name. Docker prefixes container names, networks, and volumes with it when it creates them, so the project's resources stay grouped and don't collide with other Compose projects.

## Shared image settings (`x-kafka-common`)

```yaml
x-kafka-common: &kafka-common
  image: confluentinc/cp-kafka:7.8.3
  restart: unless-stopped
  networks:
    - hadoop_cluster_net
```

Keys starting with `x-` are ignored by Compose, so they work as scratch space. The `&kafka-common` part is a YAML anchor, a named block that other places can reuse. Every Kafka node uses the same image version, restarts automatically unless you stop it yourself, and joins the Hadoop network.

## Shared cluster settings (`x-cluster-env`)

```yaml
x-cluster-env: &cluster-env
  CLUSTER_ID: "MkU3OEVBNTcwNTJENDM2Qk"
```

`CLUSTER_ID` identifies the KRaft cluster. Every node must use the same value, or the nodes won't join one cluster.

```yaml
  KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka-controller:9093
```

This tells every node where the controller is. The format is `nodeId@host:port`. The `1` matches the controller's `KAFKA_NODE_ID`, and `kafka-controller` is its container name, which Docker DNS resolves on the shared network.

```yaml
  KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
```

This names the listener that carries controller traffic. It has to match a listener defined in `KAFKA_LISTENERS`.

```yaml
  KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT,CONTROLLER:PLAINTEXT
```

This maps each listener name to a security protocol. Everything here is unencrypted and unauthenticated, which is fine for a local or lab setup. It isn't suitable for production.

```yaml
  KAFKA_INTER_BROKER_LISTENER_NAME: INTERNAL
```

Brokers talk to each other over the `INTERNAL` listener, which is the one on the Docker network.

```yaml
  KAFKA_LOG_DIRS: /var/lib/kafka/data
```

This is where Kafka stores its data and metadata. It points at the path where the volumes are mounted. The original file used `/tmp`, which is wiped when the container is recreated.

```yaml
  KAFKA_DEFAULT_REPLICATION_FACTOR: 3
  KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
  KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 3
  KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 2
  KAFKA_MIN_INSYNC_REPLICAS: 2
```

These settings control durability. Each partition is stored on three brokers by default. A write counts as successful once at least two replicas have it (min ISR 2). With this setup, the cluster keeps working if one broker goes down. Two brokers going down blocks writes that require acknowledgment from two replicas, though reads keep working. Kafka's internal topics (consumer offsets and transaction state) get the same replication.

## The controller service

```yaml
services:
  kafka-controller:
    <<: *kafka-common
    container_name: kafka-controller
```

`<<: *kafka-common` merges the shared image, restart policy, and network into this service. `container_name` sets a fixed name, which the quorum voter address depends on.

```yaml
    environment:
      <<: *cluster-env
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: controller
      KAFKA_LISTENERS: CONTROLLER://0.0.0.0:9093
```

- `<<: *cluster-env` merges in the shared cluster settings.
- `KAFKA_NODE_ID: 1` gives this node the ID listed in the quorum voters.
- `KAFKA_PROCESS_ROLES: controller` means this node only manages cluster metadata. It doesn't store messages or serve clients.
- `KAFKA_LISTENERS` makes the node listen on port 9093 on all interfaces. The controller doesn't advertise a listener, because controller-only nodes aren't meant to be contacted by clients.

```yaml
    volumes:
      - controller-data:/var/lib/kafka/data
```

The controller stores its metadata log in its own named volume. Each node needs its own volume, because nodes don't share disks.

## The broker services

Each broker repeats the same pattern with a few differences.

```yaml
  kafka-broker-1:
    <<: *kafka-common
    container_name: kafka-broker-1
    depends_on:
      - kafka-controller
```

`depends_on` starts the controller first. It only controls startup order, though. It doesn't wait for the controller to be healthy.

```yaml
    ports:
      - "29092:29092"
```

This publishes the broker's `EXTERNAL` listener (port 29092 inside the container) to port 29092 on your machine. Broker 2 maps to 29093 and broker 3 to 29094, because each host port can only be used once.

```yaml
    environment:
      <<: *cluster-env
      KAFKA_NODE_ID: 2
      KAFKA_PROCESS_ROLES: broker
      KAFKA_LISTENERS: INTERNAL://0.0.0.0:9092,EXTERNAL://0.0.0.0:29092
      KAFKA_ADVERTISED_LISTENERS: INTERNAL://kafka-broker-1:9092,EXTERNAL://localhost:29092
```

- `KAFKA_NODE_ID` must be unique across the cluster. Node IDs 2, 3, and 4 are the brokers.
- `KAFKA_PROCESS_ROLES: broker` means this node stores data and serves clients, but doesn't vote on metadata.
- `KAFKA_LISTENERS` defines the sockets the broker binds to. `INTERNAL` is on 9092 for other containers. `EXTERNAL` is on 29092 for your host.
- `KAFKA_ADVERTISED_LISTENERS` is the address clients receive and use to reconnect. This is the most important part:
  - Containers on the Hadoop network get `kafka-broker-1:9092`, which resolves inside Docker.
  - Your host gets `localhost:29092`, which reaches the published port.

Kafka clients connect once to a bootstrap server, then get the full list of broker addresses from it. The advertised addresses decide which address they use afterward. If the advertised address is wrong, clients connect but then fail when they try to reconnect.

```yaml
    volumes:
      - broker-1-data:/var/lib/kafka/data
```

Each broker gets its own volume for partition data.

Broker 2 and broker 3 follow the same pattern, with node IDs 3 and 4, their own host ports (29093 and 29094), and their own advertised host addresses.

## Volumes and networks

```yaml
volumes:
  controller-data:
  broker-1-data:
  broker-2-data:
  broker-3-data:
```

These declare the named volumes Docker manages. Data stored there survives `docker compose down` and is only removed by `docker compose down -v`.

```yaml
networks:
  hadoop_cluster_net:
    name: hadoop_cluster_hadoop_network_2
    external: true
```

This declares the network the services join. `external: true` means Compose won't create it, so it has to exist already, which is why it's the Hadoop cluster's network. `name` is the actual Docker network name. The key `hadoop_cluster_net` is the local alias the services use in this file.

## Verifying the cluster

```bash
docker compose -f kafka-compose.yml ps
docker exec kafka-broker-1 kafka-metadata-quorum --bootstrap-server kafka-broker-1:9092 describe --status
docker exec kafka-broker-1 kafka-topics --bootstrap-server kafka-broker-1:9092 --create --topic test --partitions 3 --replication-factor 3
```

From your host, use `localhost:29092,localhost:29093,localhost:29094` as the bootstrap servers. From other containers on `hadoop_cluster_net`, use `kafka-broker-1:9092,kafka-broker-2:9092,kafka-broker-3:9092`.
