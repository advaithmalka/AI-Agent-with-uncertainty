#!/bin/bash
#SBATCH --job-name=adaptiverag_with_es
#SBATCH --account=llmalignment
#SBATCH --output=logs/adaptiverag_%j.out
#SBATCH --error=logs/adaptiverag_%j.err
#SBATCH --time=0:10:00
#SBATCH --partition=a100_preemptible_q
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up..."
    # Kill Elasticsearch process
    if [ ! -z "$ES_PID" ]; then
        kill $ES_PID 2>/dev/null || true
    fi
    # Kill retriever server
    if [ ! -z "$RETRIEVER_PID" ]; then
        kill $RETRIEVER_PID 2>/dev/null || true
    fi
    # Kill any remaining elasticsearch processes
    pkill -f "elasticsearch.*${SLURM_JOB_ID}" 2>/dev/null || true
    # Clean up job-specific data directory
    rm -rf elasticsearch-7.10.2/data_${SLURM_JOB_ID} 2>/dev/null || true
    exit
}
trap cleanup EXIT INT TERM

# Start Elasticsearch in background
echo "Starting Elasticsearch..."
cd elasticsearch-7.10.2/
./bin/elasticsearch &
ES_PID=$!
cd ..

# Wait for Elasticsearch to be ready
echo "Waiting for Elasticsearch to start..."
while ! curl -s localhost:9200 > /dev/null; do
    sleep 5
    echo "Still waiting for Elasticsearch..."
done
echo "Elasticsearch is ready!"