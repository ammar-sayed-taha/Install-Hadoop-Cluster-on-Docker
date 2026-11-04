`##########################################################################`
`##################           AIRFLOW SCRIPT            ###################`
`##########################################################################`
To build airflow container follow the below steps: 

## Step 1: Build the Airflow Image
```bash
    docker compose -f airflow-compose.yml build --no-cache airflow
    docker compose -f airflow-compose.yml up -d
```

## Step 2: Make sure Airflow is up and running the services
<!-- We need to check  (Standalone, Scheduler, Triggerer, webserver) services -->
docker logs -f airflow <!-- Search for "Starting" & "webserver" keywords-->


## Step 3: Inside the Container, Check the Providers
<!-- We need to check the airflow version and providers are up and running -->
<!-- You should see 2.10.5 and the ssh, hive, and kafka providers. -->
```bash
    airflow version
    airflow providers list 
```

## Step 4: Test the Webserver
<!-- The response is JSON. Both metadatabase and scheduler should report "status": "healthy". -->
curl http://localhost:8080/health


## Step 5: Get the Password of Airflow UI
<!-- Airflow Standalone sometimes overwrite the UI password you have in the docker-compose, so you need to the the password it overwrites and then change it in the UI settings -->
```bash
    docker exec -it airflow bash
    cd /opt/airflow
    cat standalone_admin_password.txt <!-- Copy the password and login to UI -->
```

*NOTE*: if the file not found, then remove the old username and add new one using terminal
```bash 
    airflow users delete --username admin
    airflow users create --username admin --password admin --firstname Admin --lastname User --role Admin --email admin@example.com
```








