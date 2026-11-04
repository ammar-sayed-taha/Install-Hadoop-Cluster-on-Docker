# Line-by-Line Explanation: `airflow-compose.yml`

This file is a Docker Compose definition that runs a single Apache Airflow 2.10.5 instance in standalone mode, connected to an existing external Docker network named `hadoop_cluster_net`.

---

## `services:`

Top-level key that declares the containers Compose should manage. This file defines one service, `airflow`.

---

## `airflow:`

The name of the service. Compose uses it for the internal DNS name and for `docker compose` commands such as `docker compose up airflow`.

---

## `build: .`

Tells Compose to build the image from a Dockerfile in the same directory as this compose file (`.`). The Dockerfile is expected to customize the Airflow base image, for example by installing extra Python packages. Without this line, Compose would only pull a prebuilt image.

---

## `image: airflow-remote:2.10.5`

Names the image produced by the build, using the tag `airflow-remote` with version `2.10.5`. Because `build` is also present, Compose builds the image and labels it with this name. The version tag suggests the image is based on Airflow 2.10.5.

---

## `container_name: airflow`

Gives the running container a fixed name, `airflow`, instead of the auto-generated name Compose would otherwise assign (such as `project-airflow-1`). This makes commands like `docker logs airflow` or `docker exec -it airflow bash` simpler.

---

## `command: standalone`

Overrides the image's default command and passes `standalone` to the container entrypoint. In Airflow 2.x, `airflow standalone` starts the webserver, scheduler, and triggerer together, initializes the metadata database (SQLite by default), and creates an admin user. It is convenient for development but is not designed for production.

---

## `ports:`

Begins the port mapping list.

## `- "8080:8080"`

Maps port 8080 on the host to port 8080 inside the container, in `HOST:CONTAINER` order. You can open the Airflow UI at `http://localhost:8080`. The quotes keep YAML from misreading the value.

---

## `environment:`

Begins the list of environment variables passed into the container.

## `AIRFLOW__CORE__LOAD_EXAMPLES: "false"`

Disables Airflow's bundled example DAGs so the UI shows only your own DAGs. The double underscores follow Airflow's convention: `AIRFLOW__{SECTION}__{KEY}`, which maps to `[core] load_examples` in `airflow.cfg`.

## `AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: "true"`

Makes newly detected DAGs start in the paused state. A new DAG will not run on its schedule until someone unpauses it in the UI. This is a safety measure against unexpected runs.

## `_AIRFLOW_WWW_USER_USERNAME: admin`

Sets the username for the web UI login. This variable is used by the official Airflow Docker image's entrypoint to create the initial user. Behavior can vary depending on the command used, so confirm the login works after startup.

## `_AIRFLOW_WWW_USER_PASSWORD: admin`

Sets the password for that user to `admin`. This is fine for a local test environment, but it is a weak credential and should not be used anywhere the port is reachable by others. Consider moving it into an `.env` file or a Docker secret.

---

## `volumes:`

Begins the list of bind mounts. Each entry has the form `HOST_PATH:CONTAINER_PATH`, so changes on one side appear on the other.

## `- ./airflow-volumes/dags:/opt/airflow/dags`

Maps the local `airflow-volumes/dags` folder to the DAGs folder inside the container. Place DAG `.py` files here on the host, and Airflow picks them up.

## `- ./airflow-volumes/logs:/opt/airflow/logs`

Stores task and scheduler logs on the host so they persist if the container is removed.

## `- ./airflow-volumes/plugins:/opt/airflow/plugins`

Maps custom Airflow plugins (custom operators, hooks, or sensors) into the container.

## `- ./airflow-volumes/config:/opt/airflow/config`

Maps the config folder, which can hold custom logging configuration or similar files.

## `- ./airflow-volumes/airflow-data:/opt/airflow`

Mounts the `airflow-data` folder over the entire `/opt/airflow` directory. This is the most important line to understand, and it has a side effect. Docker applies mounts in order, and this one covers the parent of the three mounts above, so it can hide or conflict with them depending on how the mounts are layered. Also, `airflow.cfg` and the SQLite database usually live under `/opt/airflow`, so this mount is where that state persists. Verify that the subfolders behave as expected. Mounting `airflow-data` onto a narrower path, such as `/opt/airflow/airflow-data`, is often safer.

---

## `networks:`

Lists the networks the service joins.

## `- hadoop_cluster_net`

Attaches the `airflow` container to the network named in the top-level `networks` section, which is the same network the Hadoop cluster uses. This lets Airflow reach Hadoop services by container name.

---

## `restart: unless-stopped`

Restarts the container automatically if it crashes or the Docker daemon restarts. It stays stopped only if you explicitly stop it with `docker stop` or `docker compose stop`.

---

## `networks:` (top-level)

Declares the networks used by the file.

## `hadoop_cluster_net:`

The local alias used inside this compose file. The service refers to it by this name.

## `external: true`

Tells Compose not to create this network. It must already exist, or `docker compose up` will fail. This is what allows the Airflow container to join a network created by another compose project.

## `name: hadoop_cluster_hadoop_network_2`

The actual Docker network name on the host. Compose uses this name when attaching the container, while `hadoop_cluster_net` is only the local alias.

---

## Summary

This file builds a custom Airflow 2.10.5 image, runs it in standalone mode with the UI on port 8080, mounts local folders for DAGs, logs, plugins, and config, and connects the container to an existing Hadoop cluster network. Before running it, confirm that the Dockerfile exists, the external network `hadoop_cluster_hadoop_network_2` has been created, and the `airflow-volumes` folders are present. For anything beyond local development, review the hardcoded `admin/admin` credentials and the overlapping volume mounts.