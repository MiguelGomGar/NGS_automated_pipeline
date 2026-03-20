# Automated NGS pipeline

Production-ready Bash workflow for the automated processing of Next Generation Sequencing data. This pipeline handles quality control, quality trimming, genome alignment and SAM/bam post-processing in a single execution loop.

## Prerequisites

Ensure the following tools are installed and available in your system's `$PATH`:

* `fastqc`
* `cutadapt`
* `bowtie2`
* `samtools`
* `multiqc`

## Project structure requirements

Before running the script, your project root directory must contain the raw `.fq` files and the Bowtie2 reference genome index following this exact structure:

```text
project_root/
├── data/
│   ├── raw/                  <-- raw .fq files
│   └── reference/
│       └── AFPN02.1/         <-- bowtie2 genome index files
└── scripts/
    └── pipeline.sh           <-- main executable script
```

*Note: The script will automatically create the output directories during execution.*

## Usage instructions

The script requires exactly three positional parameters to run successfully:

1. **Quality Threshold (`-q`)**: Minimum Phred quality score for Cutadapt trimming.
2. **Minimum Length (`-m`)**: Minimum read length required to keep a sequence after trimming.
3. **Project Root Directory**: Absolute path to your main project folder.

**Syntax:**

```bash
bash scripts/pipeline.sh <quality_threshold> <min_length> <project_root_dir>
```

**Example:**
```bash
bash scripts/pipeline.sh 15 50 /workspaces/codespaces_NGS/assessments/final_coursework
```

## Outputs

Once the pipeline finishes, you will find:

* **`qc/`**: Individual FastQC HTML reports (raw and trimmed), Cutadapt timestamped logs, and a unified MultiQC summary report.
* **`data/trimmed/`**: Cleaned `.fq` files ready for downstream applications.
* **`results/`**: Sorted and indexed `.bam` files (along with their `.bai` indices) and timestamped Bowtie2 alignment logs. Intermediate heavy `.sam` files are automatically purged to save disk space.
