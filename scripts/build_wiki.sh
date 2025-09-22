#!/bin/bash
#SBATCH --job-name=build_wiki
#SBATCH --output=logs/build_wiki%j.out
#SBATCH --error=logs/build_wiki%j.err
#SBATCH --account=llmalignment
#SBATCH --time=06:00:00
#SBATCH --partition=a100_normal_q
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1

echo "building wiki index..."
python retriever_server/build_index.py wiki