#!/bin/bash

# ==============================================================================
# NGS Automated Pipeline & Optimization - Final Coursework
# Author: Miguel Gómez García (Modified)
# Description: Grid search for QC, Trimming, Alignment and Post-processing.
# Eliminates heavy files on the fly to save space.
# ==============================================================================

# --- 1. USAGE INSTRUCTIONS & INPUT VALIDATION ---
if [ "$#" -ne 1 ]; then
    echo "======================================================================="
    echo " ERROR: Missing or incorrect parameters."
    echo " USAGE: bash merged_pipeline.sh <project_root_dir>"
    echo "======================================================================="
    exit 1
fi

# --- 2. PARAMETER PARSING ---
ROOT_DIR=$1

# --- 3. HELPER CONFIGS & DIRECTORY SETUP ---
RAW_DIR="$ROOT_DIR/data/raw"
TRIM_DIR="$ROOT_DIR/data/trimmed"
REF_PREFIX="$ROOT_DIR/data/reference/AFPN02.1/AFPN02.1_merge"
QC_DIR="$ROOT_DIR/qc"
RES_DIR="$ROOT_DIR/results"

# Create output directories if they do not exist yet
mkdir -p "$TRIM_DIR" "$QC_DIR" "$RES_DIR"

echo "======================================================================="
echo " Initializing NGS Optimization Pipeline..."
echo " Project Root: $ROOT_DIR"
echo "======================================================================="

# Check if the raw data directory exists and has .fq files
if [ ! -d "$RAW_DIR" ] || [ -z "$(ls -A "$RAW_DIR"/*.fq 2>/dev/null)" ]; then
    echo "ERROR: No .fq files found in $RAW_DIR"
    exit 1
fi

# --- 4. MAIN PROCESS ---
for FILE in "$RAW_DIR"/*.fq; do
    
    BASENAME=$(basename "$FILE" .fq)
    
    echo "============================================================"
    echo "Processing raw sample: $BASENAME"
    echo "============================================================"

    # --- Initial FastQC (Only once per sample) ---
    echo "1. Running raw FastQC..."
    fastqc "$FILE" -o "$QC_DIR" -q
    mv "$QC_DIR/${BASENAME}_fastqc.html" "$QC_DIR/${BASENAME}_raw_QC.html" 2>/dev/null
    mv "$QC_DIR/${BASENAME}_fastqc.zip" "$QC_DIR/${BASENAME}_raw_QC.zip" 2>/dev/null

    # --- Grid Search Optimization ---
    for q in {10..20}; do
        for m in {20..50..5}; do
            
            # Identifier based on current parameters
            PARAM_ID="q${q}_m${m}"
            
            echo "------------------------------------------------------------"
            echo "Testing parameters: Quality (q)=$q | Min Length (m)=$m"
            echo "------------------------------------------------------------"

            # --- Trimming with Cutadapt ---
            TRIM_OUT="$TRIM_DIR/${BASENAME}_trimmed_${PARAM_ID}.fq"
            
            # Save the cutadapt log (.txt) so MultiQC can read it
            cutadapt -q "$q" -m "$m" --trim-n -o "$TRIM_OUT" "$FILE" > "$RES_DIR/${BASENAME}_cutadapt_log_${PARAM_ID}.txt"

            # --- Post-trimming FastQC ---
            fastqc "$TRIM_OUT" -o "$QC_DIR" -q
            mv "$QC_DIR/${BASENAME}_trimmed_${PARAM_ID}_fastqc.html" "$QC_DIR/${BASENAME}_trimmed_${PARAM_ID}_QC.html" 2>/dev/null
            mv "$QC_DIR/${BASENAME}_trimmed_${PARAM_ID}_fastqc.zip" "$QC_DIR/${BASENAME}_trimmed_${PARAM_ID}_QC.zip" 2>/dev/null

            # --- Alignment with Bowtie2 ---
            # Save the bowtie2 log (.txt) so MultiQC can read it
            bowtie2 --all --end-to-end -x "$REF_PREFIX" -U "$TRIM_OUT" -S "$RES_DIR/${BASENAME}_${PARAM_ID}.sam" 2> "$RES_DIR/${BASENAME}_bowtie_stats_${PARAM_ID}.txt"

            # --- Samtools post-processing ---
            # Conversion, sorting, and indexing
            samtools view -S -b "$RES_DIR/${BASENAME}_${PARAM_ID}.sam" > "$RES_DIR/${BASENAME}_${PARAM_ID}.bam"
            samtools sort "$RES_DIR/${BASENAME}_${PARAM_ID}.bam" -o "$RES_DIR/${BASENAME}_${PARAM_ID}_sorted.bam"
            samtools index "$RES_DIR/${BASENAME}_${PARAM_ID}_sorted.bam"
            
            FINAL_BAM="$RES_DIR/${BASENAME}_${PARAM_ID}_sorted.bam"

            # Read separation
            samtools view -b -f 4 "$FINAL_BAM" > "$RES_DIR/${BASENAME}_${PARAM_ID}_unmapped.bam"
            samtools view -h "$FINAL_BAM" | grep "XS:i:\|^@" | samtools view -b > "$RES_DIR/${BASENAME}_${PARAM_ID}_multimapped.bam"
            samtools view -h -F 4 "$FINAL_BAM" | grep -v "XS:i:" | samtools view -b > "$RES_DIR/${BASENAME}_${PARAM_ID}_unique.bam"

            # Indexing new BAM files
            samtools index "$RES_DIR/${BASENAME}_${PARAM_ID}_unmapped.bam"
            samtools index "$RES_DIR/${BASENAME}_${PARAM_ID}_multimapped.bam"
            samtools index "$RES_DIR/${BASENAME}_${PARAM_ID}_unique.bam"

            # Fasta extraction
            samtools fasta "$RES_DIR/${BASENAME}_${PARAM_ID}_unmapped.bam" | head -n 6 > "$RES_DIR/${BASENAME}_${PARAM_ID}_blast_queries.fasta"

            # --- CLEANING HEAVY FILES ---
            echo "Cleaning up heavy intermediate files for ${PARAM_ID}..."
            rm -f "$TRIM_OUT"
            rm -f "$RES_DIR/${BASENAME}_${PARAM_ID}.sam"
            rm -f "$RES_DIR/${BASENAME}_${PARAM_ID}.bam"
            rm -f "$FINAL_BAM" "$FINAL_BAM.bai"
            rm -f "$RES_DIR/${BASENAME}_${PARAM_ID}_unmapped.bam" "$RES_DIR/${BASENAME}_${PARAM_ID}_unmapped.bam.bai"
            rm -f "$RES_DIR/${BASENAME}_${PARAM_ID}_multimapped.bam" "$RES_DIR/${BASENAME}_${PARAM_ID}_multimapped.bam.bai"
            rm -f "$RES_DIR/${BASENAME}_${PARAM_ID}_unique.bam" "$RES_DIR/${BASENAME}_${PARAM_ID}_unique.bam.bai"
            rm -f "$RES_DIR/${BASENAME}_${PARAM_ID}_blast_queries.fasta"
            
        done
    done
done

echo "======================================================================="
# --- 5. FINAL REPORT WITH MULTIQC ---
echo "Generating final MultiQC report across all parameter combinations..."
# MultiQC will scan the FastQC HTML/ZIP files and Cutadapt/Bowtie2 TXT logs
multiqc "$QC_DIR" "$RES_DIR" -o "$QC_DIR" -n "MultiQC_Final_Optimization_Report.html"

echo "Pipeline finished!"
echo "======================================================================="