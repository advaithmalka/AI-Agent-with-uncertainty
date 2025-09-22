#!/bin/bash
#SBATCH --job-name=adaptiverag_with_es
#SBATCH --account=llmalignment
#SBATCH --output=logs/adaptiverag_%j.out
#SBATCH --error=logs/adaptiverag_%j.err
#SBATCH --time=00:05:00
#SBATCH --partition=a100_preemptable_q
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
# Function to cleanup on exit

# Change to working directory
cd $SLURM_SUBMIT_DIR

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

# Wait for Elasticsearch to be ready with better error checking
echo "Waiting for Elasticsearch to start..."
MAX_WAIT=300  # 5 minutes timeout
WAIT_TIME=0

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    if curl -s localhost:9200 > /dev/null 2>&1; then
        echo "Elasticsearch is ready!"
        curl -s localhost:9200 | head -10
        break
    fi
    
    # Check if process is still running
    if ! kill -0 $ES_PID 2>/dev/null; then
        echo "ERROR: Elasticsearch process died!"
        echo "Checking logs..."
        if [ -f "${ES_LOGS_DIR}/elasticsearch_startup.log" ]; then
            tail -20 ${ES_LOGS_DIR}/elasticsearch_startup.log
        fi
        echo "Elasticsearch failed to start. Exiting..."
        exit 1
    fi
    
    sleep 5
    WAIT_TIME=$((WAIT_TIME + 5))
    echo "Still waiting for Elasticsearch... (${WAIT_TIME}s/${MAX_WAIT}s)"
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    echo "ERROR: Elasticsearch failed to start within ${MAX_WAIT} seconds"
    echo "Final log output:"
    if [ -f "${ES_LOGS_DIR}/elasticsearch_startup.log" ]; then
        tail -30 ${ES_LOGS_DIR}/elasticsearch_startup.log
    fi
    exit 1
fi

# Start retriever server in background
echo "Starting retriever server..."
uvicorn serve:app --port 8000 --app-dir retriever_server &
RETRIEVER_PID=$!

# Wait for retriever server to be ready
sleep 10

# Run your processing scripts
echo "Building wiki index..."
python retriever_server/build_index.py wiki

echo "Processing datasets..."
python ./processing_scripts/process_nq.py
python ./processing_scripts/process_trivia.py
python ./processing_scripts/process_squad.py

# Build other indices
echo "Building other indices..."
python retriever_server/build_index.py hotpotqa
python retriever_server/build_index.py 2wikimultihopqa
python retriever_server/build_index.py musique

# Run experiments
echo "Running experiments..."
bash run_retrieval_dev.sh ircot_qa llama_8b_it nq 8010

echo "Job completed at: $(date)"