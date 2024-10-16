#!/bin/bash

# Function to set up Docker environment for the JMeter controller machine
setup_docker_environment() {
    echo "Setting up Docker environment for machine 'jmeter-controller'..."
    eval "$(docker-machine env jmeter-controller)"
}

# Function to gather available Swarm worker node hostnames
get_swarm_workers() {
    echo "Gathering available Swarm worker nodes..."
    worker_ips=""

    # Get all available Swarm nodes and filter out manager nodes
    swarm_workers=$(docker node ls --filter role=worker --format "{{.Hostname}}")

    # Check if we found any worker nodes
    if [[ -z "$swarm_workers" ]]; then
        echo "[ERROR] No Swarm worker nodes found."
        exit 1
    fi

    # Gather IPs of worker nodes
    for worker in $swarm_workers; do
        ip=$(docker node inspect --format '{{ .Status.Addr }}' "$worker")
        worker_ips+="$ip,"
    done

    # Remove the trailing comma from the list of IPs
    worker_ips="${worker_ips%,}"

    echo "Discovered worker IPs: $worker_ips"
}

# Function to clean up existing JMeter service if it's already running
cleanup_existing_service() {
    existing_service=$(docker service ls --filter name=jmeter-worker --format "{{.ID}}")
    if [ ! -z "$existing_service" ]; then
        echo "Existing JMeter service found. Removing it..."
        docker service rm jmeter-worker
        if [ $? -ne 0 ]; then
            echo "[ERROR] Failed to remove existing JMeter service."
            exit 1
        fi
        echo "Existing JMeter service removed."
    fi
}

# Function to create JMeter service on Swarm workers
create_jmeter_service() {
    echo "Deploying JMeter service on available Swarm workers..."

    # Ensure there is no service running on conflicting ports
    cleanup_existing_service

    # Create the JMeter service, ensuring it runs on all workers
    docker service create \
      --name jmeter-worker \
      --mode global \
      --publish 1099:1099 \
      --publish 4000:4000 \
      --network jmeter-network \
      justb4/jmeter:latest -s \
      -Dserver.rmi.localport=1099 \
      -Dserver.rmi.ssl.disable=true \
      -Jserver.rmi.ssl.disable=true \
      -Jserver_port=4000

    if [ $? -ne 0 ]; then
        echo "[ERROR] Failed to create JMeter service on workers."
        exit 1
    fi

    echo "JMeter service deployed on all Swarm workers."
}

# Function to ensure the JMeter controller container is running
ensure_controller_container_running() {
    local container_name="jmeter-controller"

    # Check if the container is already running
    if ! docker ps --format '{{.Names}}' | grep -Eq "^${container_name}\$"; then
        echo "The container '${container_name}' is not running. Starting the container..."
        docker start "${container_name}"
    else
        echo "The container '${container_name}' is already running."
    fi
}

# Function to run the JMeter test plan in distributed mode
run_jmeter_test_plan() {
    echo "Running JMeter test plan in distributed mode on the controller node with workers: $worker_ips"
    docker exec -it jmeter-controller \
        jmeter -n -t /load_tests/testplan.jmx -l /load_tests/testplan-results.jtl -j /load_tests/testplan-log.log -R $worker_ips
}

# Function to wait for the JMeter test to complete
wait_for_test_completion() {
    local container_name="jmeter-controller"
    echo "Waiting for the JMeter test to complete..."

    # Poll the container's status every 10 seconds until it exits
    while docker ps --format '{{.Names}}' | grep -Eq "^${container_name}\$"; do
        echo "JMeter test is still running... checking again in 10 seconds."
        sleep 10
    done

    echo "JMeter test has completed."
}

# Function to send the StopTestNow signal to all workers
send_shutdown_signal() {
    echo "Sending shutdown signal to all JMeter workers..."

    for ip in $(echo $worker_ips | tr "," "\n"); do
        echo "Sending shutdown signal to worker $ip"
        curl --silent "http://$ip:4445/StopTestNow" || echo "Failed to send shutdown signal to $ip"
    done

    echo "Shutdown signal sent to all workers."
}

# Function to fetch JMeter logs and test results from the controller container
fetch_jmeter_logs_and_results() {
    local container_name="jmeter-controller"
    echo "Fetching JMeter logs and test results from the controller..."

    # Copy the log files from the container to the host machine
    docker cp "${container_name}:/load_tests/testplan-log.log" ./testplan-log.log
    docker cp "${container_name}:/load_tests/testplan-results.jtl" ./testplan-results.jtl

    # Display the logs and results in the terminal
    echo "JMeter Test Log:"
    cat ./testplan-log.log
    echo "JMeter Test Results:"
    cat ./testplan-results.jtl
}

# Function to verify the JMeter service is running
verify_jmeter_service_running() {
    echo "Verifying that JMeter service is running on all workers..."

    # Wait for service replicas to be fully deployed
    while [[ $(docker service ps jmeter-worker --filter "desired-state=Running" --format "{{.CurrentState}}" | grep -v "Running") ]]; do
        echo "Waiting for JMeter service to be fully deployed... checking again in 10 seconds."
        sleep 10
    done

    echo "JMeter service is now running on all workers."
}

# Main execution flow
setup_docker_environment
get_swarm_workers
create_jmeter_service
verify_jmeter_service_running
ensure_controller_container_running
run_jmeter_test_plan
wait_for_test_completion
send_shutdown_signal
fetch_jmeter_logs_and_results

echo "JMeter test plan execution completed in distributed mode. Logs and test results have been retrieved."

