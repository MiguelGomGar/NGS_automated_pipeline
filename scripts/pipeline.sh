#!/bin/bash

# ==============================================================================
# NGS automation pipeline - Final Coursework
# Author: Miguel Gómez García
# Date: 2026-03-20
# Description: Automated QC, Trimming, Alignment and Post-processing
# ==============================================================================

# --- 1. USAGE INSTRUCTIONS & INPUT VALIDATION ---
# The script expects exactly 3 parameters: quality threshold, length threshold and the project root path
if [ "$#" -ne 3 ]; then
    echo "======================================================================="
    echo " ERROR: Missing or incorrect parameters."
    echo " USAGE: ./pipeline.sh <quality_threshold> <min_length> <project_root_dir>"
    echo " EXAMPLE: ./pipeline.sh 15 50 /workspaces/codespaces_NGS/assessments/final_coursework"
    echo "======================================================================="
    exit 1
fi

# --- 2. PARAMETER PARSING ---
QUALITY_Q=$1
MIN_LEN_M=$2
ROOT_DIR=$3

# --- 3. HELPER CONFIGS & DIRECTORY SETUP ---
# Dynamically building the paths based on the project root directory
RAW_DIR="$ROOT_DIR/data/raw"
TRIM_DIR="$ROOT_DIR/data/trimmed"
REF_PREFIX="$ROOT_DIR/data/reference/AFPN02.1/AFPN02.1_merge"
QC_DIR="$ROOT_DIR/qc"
RES_DIR="$ROOT_DIR/results"

# Timestamp for log files
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create output directories if they don't exist yet
mkdir -p "$TRIM_DIR" "$QC_DIR" "$RES_DIR"

echo "======================================================================="
echo " Initializing NGS pipeline at $TIMESTAMP..."
echo " Project Root: $ROOT_DIR"
echo " Quality Threshold (-q): $QUALITY_Q"
echo " Minimum Length (-m): $MIN_LEN_M"
echo "======================================================================="

# Check if the raw data directory exists and has .fq files
if [ ! -d "$RAW_DIR" ] || [ -z "$(ls -A "$RAW_DIR"/*.fq 2>/dev/null)" ]; then
    echo "ERROR: No .fq files found in $RAW_DIR"
    exit 1
fi

# --- 4. MAIN PIPELINE LOOP ---
# Processes each .fq file in the raw directory
for FILE in "$RAW_DIR"/*.fq; do
    
    # File's basename (i.e.:saves "BQ" for the "BQ.fq" file)
    BASENAME=$(basename "$FILE" .fq)
    
    echo "------------------------------------------------------------"
    echo "Processing sample: $BASENAME"
    echo "------------------------------------------------------------"

    # --- First step: Initial FastQC ---
    echo "1. Running raw FastQC..."
    fastqc "$FILE" -o "$QC_DIR" -q
    # Rename the output files
    mv "$QC_DIR/${BASENAME}_fastqc.html" "$QC_DIR/${BASENAME}_raw_QC.html"
    mv "$QC_DIR/${BASENAME}_fastqc.zip" "$QC_DIR/${BASENAME}_raw_QC.zip"

    # --- Second step: trimming with Cutadapt ---
    echo "2. Trimming reads with Cutadapt..."
    TRIM_OUT="$TRIM_DIR/${BASENAME}_trimmed.fq"
    # Using parsed parameters and logging to timestamped file.
    cutadapt -q "$QUALITY_Q" -m "$MIN_LEN_M" --trim-n -o "$TRIM_OUT" "$FILE" > "$QC_DIR/${BASENAME}_cutadapt_log_${TIMESTAMP}.txt"

    # --- Third step: post-trimming FastQC ---
    echo "3. Running FastQC on clean reads..."
    fastqc "$TRIM_OUT" -o "$QC_DIR" -q
    # Rename the output files
    mv "$QC_DIR/${BASENAME}_trimmed_fastqc.html" "$QC_DIR/${BASENAME}_trimmed_QC.html"
    mv "$QC_DIR/${BASENAME}_trimmed_fastqc.zip" "$QC_DIR/${BASENAME}_trimmed_QC.zip"

    # --- Fourth step: Sequences alignment with Bowtie2 ---
    echo "4. Aligning with the reference genome..."
    # Logging Bowtie2 stats to a timestamped file[cite: 22].
    bowtie2 --all --end-to-end -x "$REF_PREFIX" -U "$TRIM_OUT" -S "$RES_DIR/${BASENAME}.sam" 2> "$RES_DIR/${BASENAME}_bowtie_stats_${TIMESTAMP}.txt"

    # --- Fifth step: Samtools post-processing ---
    echo "5. Post-processing with Samtools (SAM to sorted BAM)..."
    
    # Compress the SAM file to .BAM format
    samtools view -S -b "$RES_DIR/${BASENAME}.sam" > "$RES_DIR/${BASENAME}.bam"
    
    # Sort the BAM file by coordinates
    samtools sort "$RES_DIR/${BASENAME}.bam" -o "$RES_DIR/${BASENAME}_sorted.bam"
    
    # Create the index for the already sorted BAM file
    samtools index "$RES_DIR/${BASENAME}_sorted.bam"
    
    # Cleaning: Delete heavy intermediate files[cite: 22].
    rm "$RES_DIR/${BASENAME}.sam" "$RES_DIR/${BASENAME}.bam"

    echo "Sample $BASENAME processed successfully."

done

echo "------------------------------------------------------------"
# --- Final step: Global report with MultiQC ---
echo "Generating MultiQC report..."
multiqc "$QC_DIR" "$RES_DIR" -o "$QC_DIR" -n "MultiQC_Final_Report_${TIMESTAMP}.html"

echo "¡Pipeline finished at $(date +"%H:%M:%S")!"