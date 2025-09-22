#!/bin/bash
#SBATCH --job-name=process_datasets
#SBATCH --output=process_datasets_%j.out
#SBATCH --error=process_datasets_%j.err
#SBATCH --account=llmalignment
#SBATCH --time=02:00:00
#SBATCH --partition=a100_normal_q
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1


# Activate conda environment
source activate adaptiverag

# Set CUDA device
export CUDA_VISIBLE_DEVICES=0

# # Change to the correct directory (adjust path as needed)
# cd $SLURM_SUBMIT_DIR

# Process datasets sequentially
echo "Processing Natural Questions..."
python ./processing_scripts/process_nq.py

echo "Processing TriviaQA..."
python ./processing_scripts/process_trivia.py

echo "Processing SQuAD..."
python ./processing_scripts/process_squad.py

echo "All processing completed at: $(date)"
