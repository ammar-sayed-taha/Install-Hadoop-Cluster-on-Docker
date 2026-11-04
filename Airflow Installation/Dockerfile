FROM apache/airflow:2.10.5-python3.8

USER root
RUN apt-get update && apt-get install -y --no-install-recommends libsasl2-dev gcc && rm -rf /var/lib/apt/lists/*

USER airflow

RUN pip install --no-cache-dir \
    "apache-airflow==2.10.5" \
    "apache-airflow-providers-ssh" \
    "apache-airflow-providers-apache-hive" \
    "apache-airflow-providers-apache-kafka" \
    --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.10.5/constraints-3.8.txt"