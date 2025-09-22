#!/bin/bash
set -e  # stop on error

# ===============================
# Config
# ===============================
MODEL="flan-t5-xl"   # choose from llama_8b_it, flan_t5_xl, flan_t5_xxl, gpt
DATASET="nq"         # nq, squad, trivia, 2wikimultihopqa, hotpotqa, musique
LLM_PORT_NUM="8010"  # should match your running server port
conda activate adaptiverag

# Step 1: Run Retrieval Strategies (dev + test)

echo ">>> Running retrieval strategies on dev set..."
for SYSTEM in ircot_qa oner_qa nor_qa; do
    bash run_retrieval_dev.sh $SYSTEM $MODEL $DATASET $LLM_PORT_NUM
done

echo ">>> Running retrieval strategies on test set..."
for SYSTEM in ircot_qa oner_qa nor_qa; do
    bash run_retrieval_test.sh $SYSTEM $MODEL $DATASET $LLM_PORT_NUM
done


# Step 2: Preprocessing

echo ">>> Preprocessing datasets..."
python ./classifier/preprocess/preprocess_predict.py
python ./classifier/preprocess/preprocess_step_efficiency.py

python ./classifier/preprocess/preprocess_silver_train.py $MODEL
python ./classifier/preprocess/preprocess_silver_valid.py $MODEL
python ./classifier/preprocess/preprocess_binary_train.py
python ./classifier/preprocess/concat_binary_silver_train.py

# ===============================
# Step 3: Train Classifiers
# ===============================
echo ">>> Training classifiers..."
cd classifier
bash ./run/run_large_train_xl.sh
bash ./run/run_large_train_xxl.sh
bash ./run/run_large_train_gpt.sh
cd ..

# ===============================
# Step 4: Postprocess + Complexity Prediction
# ===============================
echo ">>> Running postprocess prediction..."
python ./classifier/postprocess/predict_complexity_on_classification_results.py

# ===============================
# Step 5: Final Evaluation
# ===============================
echo ">>> Evaluating final QA performance..."
python ./evaluate_final_acc.py

echo ">>> ✅ Full Adaptive-RAG pipeline complete!"
