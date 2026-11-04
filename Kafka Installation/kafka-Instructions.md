`##########################################################################`
`##################             KAFKA SCRIPT            ###################`
`##########################################################################`
To Run *Kafka Python* Script on `Master + Slaves`, follow these steps
1. Run *docker-compose.yml* of Kafka Container

docker compose -f kafka-compose.yml -p kafka_cluster up -d

2. Install Python libraries on `Master` + `Slaves` to run python scripts: 

```bash
  # Update and Install kafka libraries on Ubuntu wheels
  apt-get update
  apt-get install -y librdkafka-dev python3-dev build-essential

  # Install Kafka Module on python
  pip install --upgrade pip setuptools wheel
  pip install confluent_kafka
```
