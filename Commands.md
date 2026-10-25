# DOCKER STEPS

### Before u run anything download hadoop-3.3.6.tar.gz using wget
wget https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz

### Download Ubuntu Image for Linux machines
docker pull ubuntu:20.04

### Build Master Image
docker build -t master -f Dockerfile.master .

### Build Slave Image
docker build -t slave -f Dockerfile.slave .

docker-compose -p hadoop_cluster up -d

### first time only (format namenode) => initialize the storage directories and metadata structures for the HDFS NameNode before launching the cluster for the first time.
hdfs namenode -format

# Run the Name Node for "hdfs dfs -ls" commands.
cd /opt/hadoop/etc/hadoop
hadoop-daemon.sh start namenode  

### In Master Node - Edit Workers (hdfs@slave) Manually
apt install nano iputils-ping --fix-missing

### Install SSH key on Master Node
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa

### Copy the SSH Key for all Slaves, to make Master connect to them automatically later (password: hdfs)
ssh-copy-id hdfs@slave1
ssh-copy-id hdfs@slave2
ssh-copy-id hdfs@slave3
jps



# Add Slaves to the Workers File (Ignore it, already handled in DockerFile.master)
<!-- cd /opt/hadoop/etc/hadoop/
nano workers  => copy the workers file into it. -->


### 🔴 Execute Example in Master Node 🔴
1. <Copy the input file to HDFS>

docker cp "input.csv" master:/home/hdfs/input.csv
hdfs dfs -ls .
hdfs dfs -mkdir -p /user/hdfs/input/ <!-- If -p failed, then -mkdir folder by folder -->
hdfs dfs -put input.csv /user/hdfs/input/
hdfs dfs -ls /user/hdfs/input

<!-- Copy the WordCount Jar to Master HDFS -->
docker cp Assets\Example\WordCount.jar master:/home/hdfs/WordCount.jar


2. <Run the Job>
/opt/hadoop-3.3.6/bin/hadoop jar  \
   /home/hdfs/WordCount.jar \
   WordCount \
   /user/hdfs/input/input.csv \
   /user/hdfs/output 

3. <Copy the output to local device to be readable>
cd /home/hdfs/
hdfs dfs -get /user/hdfs/output/ ./output
hdfs dfs -rm -r /user/hdfs/output

docker cp  master:/home/hdfs/output ./output <!-- Copy Folder to local device-->
   

### Stop the Docker Containers 
docker compose -p hadoop_cluster stop

<Note: 🔴 If you want to stop and completely remove the containers, networks, and volumes created by that file, use:>
docker compose [-p hadoop_cluster] down               => <[] means it's optional>



#### Import & Export Images/Containers ####
### Image  <Note: tag: means the version for example :latest>
docker save -o output_image.tar image:tag 

docker import output_image.tar new_image_name:tag
<OR> 
docker load -i output_image.tar 

### Container
docker export -o container.tar <container_id>
docker import container.tar new_container_name:tag    => <imports this container as image>
docker run -d ew_container_name:tag                   => <To use this container again, you need to create new container from this image>


### Enter the Container's Terminal
docker exec -it <container_name> /bin/bash



`##########################################################################`
`####################            HIVE SCRIPT           ####################`
`##########################################################################`
*NOTE:* Before every restart to the Hive Script Run this Command first: 
```bash
  docker exec hive-server rm -f /opt/hive/conf/hiveserver2.pid
  docker restart hive-server
```
# STEPS TO CREATE HIVE CONTAINER AND CONNECT TO HADOOP CLUSTER 
1. ### Create Hive Container and make it shared in the same hadoop_cluster Network
<!-- docker run -d --name hive-server `
--label "com.docker.compose.project=hadoop_cluster" `
--network hadoop_cluster_hadoop_network_2 `
-p 10000:10000 -p 10002:10002 apache/hive:standalone-metastore-nightly -->
docker run -d `
  --name hive-server `
  --network hadoop_cluster_hadoop_network_2 `
  --label "com.docker.compose.project=hadoop_cluster" `
  --env SERVICE_NAME=hiveserver2 `
  -p 10000:10000 -p 10002:10002 `
  -e HADOOP_CONF_DIR=/opt/hive/conf -e HIVE_CONF_DIR=/opt/hive/conf -e TEZ_CONF_DIR=/opt/hive/conf `
  apache/hive:4.0.1


NOTE:
1.  hadoop_cluster_hadoop_network_2 <!-- is <Network Name>, you can get it from command [docker network ls]-->
2. apache/hive:tag <!-- apache/hive -> <image_name> -->
3. --label <!-- OPTIONAL: Hadoop group to make the container under it with other hadoop containers -->



2. ## Copy Hadoop Configuration Files to Hive 
<!-- Hive needs to know where your Hadoop Master (NameNode) is. You must copy the configuration files from your running Hadoop Master container to your Hive container. -->
<!-- docker cp ./core-site.xml hive-server:/opt/hive/conf/ 
docker cp ./hdfs-site.xml hive-server:/opt/hive/conf/
docker cp ./hive-site.xml hive-server:/opt/hive/conf/
docker cp ./tez-site.xml hive-server:/opt/hive/conf/
docker cp ./yarn-site.xml hive-server:/opt/hive/conf/
docker cp ./mapred-site.xml hive-server:/opt/hive/conf/ -->
```bash
$files = @(
    "core-site.xml",
    "hdfs-site.xml",
    "hive-site.xml",
    "tez-site.xml",
    "yarn-site.xml",
    "mapred-site.xml"
)

foreach ($file in $files) {
    docker cp "./$file" "hive-server:/opt/hive/conf/"
}
```

3. ## Create HDFS Warehouse direcoty in 🔴Master Container🔴
docker exec -it master /bin/bash

<!-- Create Warehouse for the Databases/Tables of hive on HDFS -->
hdfs dfs -mkdir -p /user/hive/warehouse <!-- If -p failed, then -mkdir folder by folder -->
hdfs dfs -mkdir -p /user/hive/external
hdfs dfs -mkdir -p /tmp/hive
hdfs dfs -chmod -R 777 /user/hive
hdfs dfs -chmod -R 777 /tmp


<!-- Give the directories Full Access by Hive user -->
hdfs dfs -chown -R hive:hadoop_cluster /user/hive

<!-- Copy the file from local to hive-server container -->
docker cp .\apache-tez-0.10.4-bin.tar.gz master:/opt/
tar xzf apache-tez-0.10.4-bin.tar.gz 

<!-- Upload the file to HDFS through master Node -->
hdfs dfs -mkdir /apps
hdfs dfs -put /opt/apache-tez-0.10.4-bin/share/tez.tar.gz /apps/
hdfs dfs -chmod -R 777 /apps

4. ## Configure the Hive Metastore (Inside Hive Container)
docker exec -it hive-server bash
<!-- docker exec -it hive-server beeline -u "jdbc:hive2://localhost:10000"  -->


5. ##  Initialize the Schema and Run
<!-- Before starting Hive for the first time, you must initialize its metadata store (Derby is used by default for testing: -->
schematool -dbType derby -initSchema --verbose

*NOTE*: if the command above Failed, then you need to remove the log files of hive_metastore and try again.
rm -rf /opt/hive/metastore_db
rm -f /opt/hive/derby.log

6. ## Start the Metastore Service (Run HiveQL Queries)
/opt/hive/bin/beeline -u "jdbc:hive2://localhost:10000"



7. ## Check the table on HDFS
Open URL => http://localhost:9870/explorer.html#/


8. ## Connect Hive using DBeaver UI
    1. Open DBeaver
    2. Add New Connection
    3. Search for `Apache Hive 4+`
    4. Add the Following Configs:
        1. Host: localhost
        2. Port: 10000
        3. username: hive
        4. Password: <empty>
        5. Test Connection






`##########################################################################`
`##################             Spark SCRIPT            ###################`
`##########################################################################`
# Step 1: Download and Extract Spark (On master)
<!-- Attach to master container if you haven't already:
docker exec -it master /bin/bash -->

1. Use `hdfs` user for all upcoming installations
su - hdfs

<!-- Download Spark built with Hadoop support (adjust versions as needed) -->
cd /opt
wget https://archive.apache.org/dist/spark/spark-3.2.1/spark-3.2.1-bin-hadoop3.2.tgz

<!-- Extract it to your preferred installation directory -->
tar -xvf spark-3.2.1-bin-hadoop3.2.tgz -C /opt/
mv /opt/spark-3.2.1-bin-hadoop3.2 /opt/spark


# Step 2: Configure Environment Variables (🔴 All Nodes 🔴)
1. Install pip + pyspark Module to run pyspark jobs using Python
apt-get update
apt-get install -y python3-pip <!--Install python3 if not installed-->
pip install pyspark==3.2.1 --force-reinstall

2. Add Spark_Home configs
<!-- Spark needs to know where Hadoop and its configurations live. Add these lines to /etc/profile, ~/.bashrc, or your existing Hadoop environment script on all nodes (master and slaves): -->
<!--Global Env-->
export SPARK_HOME=/opt/spark 
echo "export SPARK_HOME=/opt/spark" >> /etc/profile && \
echo "export SPARK_HOME=/opt/spark" >> ~/.bashrc

echo "export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin" >> /etc/profile && \
echo "export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin" >> ~/.bashrc
echo "export PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-*.zip"  >> ~/.bashrc

<!-- *NOTE:* If got Permission error for /etc/profile, then use `root` user and give it write access
chmod 777 -R /etc
chmod 777 -R /root -->

3. Save the Changes
<!-- Run source ~/.bashrc (or your respective file) to apply changes immediately. -->
source ~/.bashrc




*Check Spark Version* <!--⚠️ Works for Master Node only for now-->
spark-submit --version


# Step 3: Configure Spark Environment (`spark-env.sh`)
1. On the *master node*, configure Spark to communicate with your YARN cluster.
cd /opt/spark/conf
cp spark-env.sh.template spark-env.sh


2. Open *spark-env.sh* and append the following configurations:
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 # Adjust to your actual Java path
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop      # Adjust to your actual Hadoop config path
export YARN_CONF_DIR=/opt/hadoop/etc/hadoop        # Adjust to your actual YARN config path


# 3. Step 4: Configure Spark Defaults (`spark-defaults.conf`) - YARN Mode
1. Copy the Default Conf file
cd /opt/spark/conf
cp spark-defaults.conf.template spark-defaults.conf

2. Add these properties to `spark-defaults.conf`:
spark.master                     yarn
spark.submit.deployMode          client
spark.history.fs.logDirectory    hdfs://master:9000/spark-history
spark.eventLog.enabled           true
spark.eventLog.dir               hdfs://master:9000/spark-history

*Note:* Replace `hdfs://master:9000` with your active HDFS NameNode URI if it uses a different port or hostname



# Step 5: Sync Spark to All Slave Containers
<!-- Since Spark on YARN requires the Spark binaries/configurations to be present on all the worker nodes if running in certain deployment modes, copy the configured directory from master to your slave containers. -->

*Copy the Spark Directory to all Slaves*

`1. Download the folder from the master container to your local directory`
docker cp master:/opt/spark .\Assets\

`2. Loop through the slave names to upload the local folder to each container`
```powershell
"slave1", "slave2", "slave3" | ForEach-Object {
    docker cp .\Assets\spark "${_}:/opt/spark"
}
```

*Check Spark Version* <!--Works for All Nodes-->
spark-submit --version



# Step 6: Create HDFS Directories `Master Node`
<!-- Ensure your HDFS cluster is active, then create the history directory defined in Step 4 so Spark jobs don't crash when writing logs: -->

hdfs dfs -mkdir /spark-history
hdfs dfs -chmod 777 /spark-history



# Step 7: Test Your Spark on YARN Installation
<!-- You can test the deployment by running the included Spark Pi example in YARN client mode. Run this command on your master node: -->
```bash
su - hdfs

spark-submit \
  --class org.apache.spark.examples.SparkPi \
  --master yarn \
  --deploy-mode client \
  --executor-memory 1G \
  --num-executors 3 \
  /opt/spark/examples/jars/spark-examples_2.12-3.2.1.jar \
  10
```

*Verification*
• If successful, the terminal will print Pi is roughly 3.14....
• You can navigate to your Hadoop YARN ResourceManager Web UI (usually http://localhost:8088 mapped from your master container) to verify that the Spark application was successfully tracked and distributed across slave1, slave2, and slave3.


# Step 7 - Grant Ownership to the hdfs User
<!-- Still as root, hand over full ownership of the Spark installation folder and the log directories to the hdfs user: -->
`Change ownership of the entire spark folder to hdfs`
chown -R hdfs:hdfs /opt/spark

`Make sure permissions allow hdfs to read, write, and execute`
chmod -R 777 /opt/spark



# Step 8: Start the History Server Daemon `Spark History UI`
<!-- On your master node, execute the built-in start script: -->

`Start The service`
/opt/spark/sbin/start-history-server.sh 

`Stop the Service` <!--if required-->
/opt/spark/sbin/stop-history-server.sh

*NOTE:* To verify the process is actively running, type `jps`. You should see `HistoryServer` listed among the running Java processes.

# Step 9: Open Spark History UI: 
http://localhost:18080

*NOTE:* If the URL not working, then it might be the port 18080 is not mapped from master node to local host, then run this command: 
1. Find the Master Network Name
```bash
docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' master
```

2. Run the Command with new Network Name
```bash
docker run -d `
--name spark-bridge `
--network=<Master_Network_Name> `
-p 18080:18080 `
nginx:alpine ash -c "echo 'server { listen 18080; location / { proxy_pass http://master:18080; proxy_read_timeout 300s; } }' > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
```

3. Test the Port Connection on PowerShell
```bash
curl.exe -I http://localhost:18080
```
*NOTE:* It should return something like this `HTTP/1.1 200 OK`






`##########################################################################`
`##################             KAFKA SCRIPT            ###################`
`##########################################################################`
*NOTE:* Newer versions of Apache Kafka (V4.x) utilize KRaft (Kafka Raft metadata mode), completely removing the dependency on an external ZooKeeper cluster
# HOW TO DO IT? 
In the 1-master, 3-slave Hadoop topology, the standard way to architect this without ZooKeeper is to assign roles based on our nodes
* *Master node:* Configured exclusively as a `Controller` (manages cluster metadata, similar to what ZooKeeper used to do).
* *slave1, slave2, slave3 nodes:* Configured exclusively as `Brokers` (handle the actual data storage, producing, and consuming).

# Step 1: Download and Extract Kafka on All Nodes (`Master` + `Slaves`)
  <!-- Run this on all 4 nodes (master, slave1, slave2, slave3): -->
  cd /opt
  wget https://dlcdn.apache.org/kafka/4.2.2/kafka_2.13-4.2.2.tgz
  tar -xvzf kafka_2.13-4.2.2.tgz
  mv kafka_2.13-4.2.2 kafka
  mkdir -p /var/log/kafka-logs
  chown -R hdfs:hdfs /opt/kafka /var/log/kafka-logs


# Step 2: Configure the `Master Node` (Dedicated Controller)
  <!-- 
  Instead of editing the old server.properties, KRaft configurations are stored in the /opt/kafka/config/kraft/ folder. 
  -->
  On the master node, open `/opt/kafka/config/kraft/controller.properties` and ensure the following properties are configured:

  mkdir -p /opt/kafka/config/kraft
  nano /opt/kafka/config/kraft/controller.properties

  ```bash
  # The role of this server. It is strictly a controller.
  process.roles=controller
  node.id=1
  # The quorum voters map. ID 1 is our master node.
  controller.quorum.voters=1@master:9093
  # Add Controller listener name
  controller.listener.names=CONTROLLER
  # The port the controller listening socket binds to
  listeners=CONTROLLER://master:9093

  # Log directories for metadata
  log.dirs=/var/log/kafka-logs
  ```

# Step 3: Configure the `3 Slave Nodes` (Dedicated Brokers)
  On each slave node, you will modify `/opt/kafka/config/kraft/broker.properties`. 
  Every slave needs a unique node.id

  mkdir -p /opt/kafka/config/kraft/
  nano /opt/kafka/config/kraft/broker.properties

  ## ON *Slave 1*
  ```bash
  process.roles=broker
  node.id=2
  controller.listener.names=CONTROLLER
  controller.quorum.voters=1@master:9093
  listeners=PLAINTEXT://slave1:9092
  advertised.listeners=PLAINTEXT://slave1:9092
  log.dirs=/var/log/kafka-logs
  ```

  ## ON *Slave 2*
  ```bash
  process.roles=broker
  node.id=3
  controller.listener.names=CONTROLLER
  controller.quorum.voters=1@master:9093
  listeners=PLAINTEXT://slave2:9092
  advertised.listeners=PLAINTEXT://slave2:9092
  log.dirs=/var/log/kafka-logs
  ```

  ## ON *Slave 3*
  ```bash
  process.roles=broker
  node.id=4
  controller.listener.names=CONTROLLER
  controller.quorum.voters=1@master:9093
  listeners=PLAINTEXT://slave3:9092
  advertised.listeners=PLAINTEXT://slave3:9092
  log.dirs=/var/log/kafka-logs
  ```



# Step 4: Initialize the `KRaft Cluster ID`
KRaft requires all participating nodes to be formatted with a matching, unique Cluster UUID

## 1. Generate a unique UUID (run this command `only once` on the *master node*):
  /opt/kafka/bin/kafka-storage.sh random-uuid

  *NOTE:* This will output a `random string` (e.g., 4L62ydkiT96061-beSg9vA). Copy this string.

## 2. Format the storage directories `on ALL 4 nodes` using that exact UUID:
  ### 2.1 On the `Master Node`:
    /opt/kafka/bin/kafka-storage.sh format -t <YOUR_GENERATED_UUID> -c /opt/kafka/config/kraft/controller.properties


  ### 2.2 On `Slave 1, 2, and 3`:
    /opt/kafka/bin/kafka-storage.sh format -t <YOUR_GENERATED_UUID> -c /opt/kafka/config/kraft/broker.properties



# Step 5: Start the Cluster
  ## 1. Start the Controller on the `master node`:
    /opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/kraft/controller.properties

  ## 2. Start the Brokers on `All Slaves`
    /opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/kraft/broker.properties


*NOTE:* To verify execution, typing `jps` on any node should show the `Kafka` process running



