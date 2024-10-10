#!/bin/bash

# Function to set up Docker environment for a specific Docker machine
setup_docker_environment() {
    echo "Setting up Docker environment for machine 'jmeter-controller'..."
    eval "$(docker-machine env jmeter-controller)"
}

# Function to ensure the JMeter container is running
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

# Function to run the JMeter test plan in the existing container
run_jmeter_test_plan() {
    echo "Running JMeter test plan in the existing container..."
    docker exec -it jmeter-controller \
        jmeter -n -t /load_tests/testplan.jmx -l /load_tests/testplan-results.jtl -j /load_tests/testplan-log.log
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

# Function to fetch JMeter logs and test results from the container
fetch_jmeter_logs_and_results() {
    local container_name="jmeter-controller"
    echo "Fetching JMeter logs and test results..."

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
ensure_container_running
run_jmeter_test_plan
wait_for_test_completion
fetch_jmeter_logs_and_results

echo "JMeter test plan execution completed. Logs and test results have been retrieved."

