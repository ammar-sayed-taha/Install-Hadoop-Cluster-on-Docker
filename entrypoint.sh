#!/bin/bash

# Start SSH Service
echo "Starting SSH service..."
/usr/sbin/sshd -D &

# Ensure correct ownership of HDFS directories
echo "Setting ownership for HDFS directories..."
chown -R hdfs:hadoop /opt/hadoop/hdfs

# Ensure Java is available
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# Start Hadoop Services as hdfs user
echo "Starting HDFS..."
su - hdfs -c "/opt/hadoop/sbin/start-dfs.sh"

echo "Starting YARN..."
su - hdfs -c "/opt/hadoop/sbin/start-yarn.sh"

# Keep the container running while monitoring logs
echo "Hadoop services are running. Keeping container alive..."
exec tail -f /opt/hadoop/logs/*.log
