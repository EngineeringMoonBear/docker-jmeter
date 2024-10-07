# Dockerized JMeter - A Distributed Load Testing Workflow

### Supported Cloud Providers:
- [DigitalOcean](https://www.digitalocean.com/join/)

### Images Used:
- **JMeter Worker** ([Docker Image](https://hub.docker.com/r/hhcordero/docker-jmeter-server)) (formerly "Slave")
- **JMeter Controller Non-GUI** ([Docker Image](https://hub.docker.com/r/hhcordero/docker-jmeter-client)) (formerly "Master")

### Prerequisites:
1. Docker and Docker Machine CLI installed on your host. Follow the instructions at [Docker Installation](https://docs.docker.com/installation/).
2. DigitalOcean account with the following:
   - Access Token

3. JMeter test plan created on your host. See the [JMeter Test Plan](http://jmeter.apache.org/usermanual/build-web-test-plan.html) documentation.

### Steps

#### 1. Provision the JMeter Controller Node (Non-GUI Mode)

To create a JMeter Controller node on DigitalOcean, use the following command:
```bash
./launch_jmeter_controller_do
```

To create a JMeter Controller node on your local machine, use:
```bash
./launch_jmeter_controller_local
```

#### 2. Provision JMeter Worker Nodes (Server Mode)

You can specify the number of worker nodes to provision, with a default value of 1 if no parameter is given. The maximum number of nodes supported is 20.

For DigitalOcean:
```bash
./launch_jmeter_worker_do 2
```

#### 3. Copy the JMeter Test Plan to the JMeter Controller Node

After provisioning the JMeter Controller, you need to copy your test plan to the `/load_tests` directory on the controller node.

**Connect to the JMeter Controller Node:**
```bash
eval "$(docker-machine env jmeter-controller)"
docker-machine ssh jmeter-controller
```

**Create the `/load_tests` directory on DigitalOcean:**
```bash
mkdir /load_tests
```

**Create the `/load_tests` directory on your local machine:**
```bash
sudo mkdir /load_tests && sudo chown docker:docker /load_tests
```

**Exit back to your host machine:**
```bash
exit
```

**Copy the test plan from your host to the JMeter Controller Node:**

Use the following syntax to copy the test plan:
```bash
docker-machine scp [path to test directory] [controller machine name]:/load_tests
```

**Example:**
```bash
docker-machine scp -r /home/user/docker-jmeter-controller/load_tests/my_test jmeter-controller:/load_tests
```

#### 4. Run the JMeter Load Test

Execute the following commands to run the load test on the JMeter Controller node. Replace values as necessary before executing.

**Get the JMeter Controller Node IP Address:**
```bash
IP=$(docker-machine ip jmeter-controller)
```

**Set the Remote Hosts for the Worker Nodes:**

Replace the value with the comma-separated IP addresses of the worker nodes:
```bash
REMOTE_HOSTS=""
```

**Specify the Test Plan Details:**

Set the parent directory and test plan name:
```bash
TEST_DIR="my_test"
TEST_PLAN="test-plan"
```

**Run the JMeter Controller in Non-GUI Mode to Perform the Load Test:**
```bash
docker run \
    --detach \
    --publish 1099:1099 \
    --volume /load_tests/$TEST_DIR:/load_tests/$TEST_DIR \
    --env TEST_DIR=$TEST_DIR \
    --env TEST_PLAN=$TEST_PLAN \
    --env IP=$IP \
    --env REMOTE_HOSTS=$REMOTE_HOSTS \
    --env constraint:type==controller \
    hhcordero/docker-jmeter-client
```

#### 5. Monitor Test Output

You can monitor the test output by following the logs from the JMeter Controller node.

**Log Command Syntax:**
```bash
docker logs -f [container name]
```

**Example:**
```bash
docker logs -f jmeter-controller/tender_feynman
```

#### 6. Save the Test Results

After the test completes, save the result file (.jtl) from the JMeter Controller node.

**Copy the result file to your host machine:**
```bash
docker-machine scp [controller machine name]:/load_tests/[test dir]/[test plan result] [path to test directory]
```

**Example:**
```bash
docker-machine scp jmeter-controller:/load_tests/${TEST_DIR}/${TEST_PLAN}.jtl /home/user/docker-jmeter-controller/load_tests/my_test/.
```

### Summary

This workflow outlines how to set up a distributed JMeter testing environment using Docker Swarm with the updated terminology of "Controller" and "Worker" nodes. By utilizing modern Docker Swarm commands and focusing on DigitalOcean provisioning, we create a more streamlined and inclusive testing setup.
