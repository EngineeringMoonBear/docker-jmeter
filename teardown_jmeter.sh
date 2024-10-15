#!/bin/bash

# Function to check if a Docker machine exists
function check_machine_exists() {
    docker-machine ls | grep -w "$1" > /dev/null 2>&1
}

# Function to remove a Docker machine
function remove_machine() {
    machine_name=$1
    echo "Attempting to remove Docker machine: $machine_name"

    if check_machine_exists "$machine_name"; then
        docker-machine rm -f "$machine_name"
        if [ $? -eq 0 ]; then
            echo "Successfully removed Docker machine: $machine_name"
        else
            echo "[ERROR] Failed to remove Docker machine: $machine_name"
        fi
    else
        echo "Docker machine $machine_name does not exist. Skipping."
    fi
}

# Tear down the JMeter controller
echo "Tearing down JMeter controller node..."
remove_machine "jmeter-controller"

# Tear down JMeter worker nodes (1-20)
echo "Tearing down JMeter worker nodes..."
for i in {1..20}; do
    remove_machine "jmeter-worker-$i"
done

echo "JMeter environment teardown completed."
