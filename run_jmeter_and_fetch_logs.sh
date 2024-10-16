#!/bin/bash

# Function to set up Docker environment for the JMeter controller machine
setup_docker_environment() {
    echo "Setting up Docker environment for machine 'jmeter-controller'..."
    eval "$(docker-machine env jmeter-controller)"
}

# Function to gather worker node IPs (1 through 20)
get_worker_ips() {
    echo "Gathering IP addresses of JMeter worker nodes..."
    worker_ips=""
    
    # Loop through worker IDs 1 to 20 and gather IP addresses
    for i in $(seq 1 20); do
        worker_name="jmeter-worker-$i"
        
        # Check if the worker machine exists
        if docker-machine ls --filter "name=$worker_name" --format "{{.Name}}" | grep -q "$worker_name"; then
            ip=$(docker-machine ip "$worker_name")
            worker_ips+="$ip,"
        fi
    done

    # Remove the trailing comma from the list of IPs
    worker_ips="${worker_ips%,}"

    # Check if we found any worker IPs
    if [[ -z "$worker_ips" ]]; then
        echo "[ERROR] No JMeter worker nodes found."
        exit 1
    fi

    echo "Discovered worker IPs: $worker_ips"
}

# Function to ensure the JMeter controller container is running
ensure_container_running() {
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

# Main execution flow
setup_docker_environment
get_worker_ips
ensure_container_running
run_jmeter_test_plan
wait_for_test_completion
fetch_jmeter_logs_and_results

echo "JMeter test plan execution completed in distributed mode. Logs and test results have been retrieved."
