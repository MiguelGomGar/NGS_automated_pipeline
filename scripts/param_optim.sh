#!/bin/bash

# ==============================================================================
# Cutadapt parameters optimization - Final Coursework
# Author: Miguel Gómez García
# Date: 2026-03-19
# Description: length and quality grid search
# ==============================================================================

# --- 1. USAGE INSTRUCTIONS & INPUT VALIDATION ---
if [ "$#" -ne 1 ]; then
    echo "======================================================================="
    echo " ERROR: the project's root path is missing."
    echo " USE: bash scripts/param_optim.sh <root_project_path>"
    echo "======================================================================="
    exit 1
fi

# --- 2. PARAMETER PARSING ---
ROOT_DIR=$1

# --- 3. HELPER CONFIGS & DIRECTORY SETUP ---
# Dynamically building the paths based on the project root directory ---

# Main files paths
INPUT_FQ="$ROOT_DIR/data/raw/BQ.fq"
REF_INDEX="$ROOT_DIR/data/reference/AFPN02.1/AFPN02.1_merge"
OUTPUT_CSV="$ROOT_DIR/results/optimization_results.csv"

# Temporary files
TEMP_FQ="$ROOT_DIR/results/clean_temp.fq"
TEMP_SAM="$ROOT_DIR/results/temp.sam"
TEMP_STATS="$ROOT_DIR/results/temp_stats.txt"

# Write the CSV file heading
echo "q,m,reads,alignment_rate" > "$OUTPUT_CSV"
echo "The results will be saved at: $OUTPUT_CSV"

# ---4. MAIN LOOP (Grid Search optimization)---
echo "------------------------------------------------------------"
echo "Beginning parameters optimization..."
echo "------------------------------------------------------------"

for q in {10..20}; do
    for m in {20..50..5}; do

        echo "Running q=$q, m=$m..."

        # Trimming
        cutadapt --trim-n -q "$q,$q" -m "$m" -o "$TEMP_FQ" "$INPUT_FQ" --quiet

        # Aligning
        bowtie2 --all --end-to-end -x "$REF_INDEX" -U "$TEMP_FQ" -S "$TEMP_SAM" 2> "$TEMP_STATS"

        # Retrieving statistics
        reads=$(grep "reads; of these:" "$TEMP_STATS" | awk '{print $1}')
        align_rate=$(grep "overall alignment rate" "$TEMP_STATS" | awk '{print $1}' | sed 's/%//')

        # Inserting results into CSV
        echo "$q,$m,$reads,$align_rate" >> "$OUTPUT_CSV"
    done
done

# --- 5. CLEANING TEMPORARY FILES ---
rm -f "$TEMP_FQ" "$TEMP_SAM" "$TEMP_STATS"

echo "======================================================================="
echo "Optimization finished successfully!"
echo "You can find the results at: $OUTPUT_CSV"
echo "======================================================================="