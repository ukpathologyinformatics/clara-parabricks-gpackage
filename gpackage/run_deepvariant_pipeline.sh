#!/bin/bash

#
#   UKHC Bioinformatics - Nvidia Clara Parabricks DeepVariant Processing Pipeline Wrapper
#   Copyright (C) 2024 Caylin Hickey and Dr. Justin Miller
#
#   This script runs the Nvidia Clara Parabricks DeepVariant pipeline in accordance with
#   the standard genomics processing pipeline used by the University of Kentucky Genomics
#   Core Laboratory and provides standardized output files for further analysis.
#

usage() {
    echo "Usage: $0 -o <output_files_path> -p <panel_folder_name> -f <flowcell_id> -s <sample_id> -r <refseq> [-g <alternate_gpackage_path] [-L <interval_file>] [-l] [-w] fastq1 fastq2 ..." 1>&2;
}

show_help() {
    echo "$0 : Run Nvidia Clara Parabricks DeepVariant Pipeline" 1>&2
    echo "Required Parameters:" 1>&2
    echo "  -o <output_files_path> : The path where the output files should be generated" 1>&2
    echo "  -p <panel_folder_name> : The name of the common folder for panel samples (e.g. PEDSALL-V#)" 1>&2
    echo "  -f <flowcell_id> : The flowcell indentifier" 1>&2
    echo "  -s <sample_id> : The sample accession identifier" 1>&2
    echo "  -r <refseq> : The internal Docker path where the reference sequence .fasta file is mounted (usually in /gpackage)" 1>&2
    echo "Optional Parameters:" 1>&2
    echo "  -g <gpackage_path> : Supply a different gpackage path (defaults to /gpackage)" 1>&2
    echo "  -L <interval_file_path> : Interval file to be supplied to the pipeline" 1>&2
    echo "Optional Flags:" 1>&2
    echo "  -l : Use low-memory mode for GPUs with 16GB of memory" 1>&2
    echo "  -w : Use WES mode" 1>&2
}

check_args() {
    if [ -z "${OUTPUT_FILES}" ]
    then 
        printf "ERROR: you must supply the output files path for processing (-o)\n"
        usage
        exit 1
    fi
    if [ -z "${PANEL_FOLDER}" ]
    then 
        printf "ERROR: you must supply the panel folder name (-p)\n"
        usage
        exit 1
    fi
    if [ -z "${FLOWCELL_ID}" ]
    then
        printf "ERROR: you must supply the flowcell identifier (-f)\n"
        usage
        exit 1
    fi
    if [ -z "${SAMPLE_ID}" ]
    then
        printf "ERROR: you must supply the sample identifier (-s)\n"
        usage
        exit 1
    fi
    if [ -z "${REFERENCE_SEQUENCE}" ]
    then
        printf "ERROR: you must supply the genomic reference sequence .fasta (-r)\n"
        usage
        exit 1
    fi
    if [ -z "${GPACKAGE_PATH}" ]
    then
        printf "ERROR: you must supply a valid gpackage directory path (-g)\n"
        usage
        exit 1
    fi
    if [ ! -z "${INTERVAL_FILE_PATH}" ] && [ ! -f "${INTERVAL_FILE_PATH}" ]
    then
        printf "ERROR: you must supply a valid interval file that exists\n"
        usage
        exit 1
    fi
    # Strip trailing slashes (/) from the supplied gpackage directory path
    GPACKAGE_PATH=$(echo "$GPACKAGE_PATH" | sed 's:/*$::')
}

# Initialize global variables

GPACKAGE_PATH="/gpackage"
USE_LOW_MEMORY=""
USE_WES_MODEL=""


# Pull in command-line arguments

while getopts ":o:p:f:s:r:g:L:lwh" o; do
    case "${o}" in
        o) OUTPUT_FILES="${OPTARG}" ;;
        p) PANEL_FOLDER="${OPTARG}" ;;
        f) FLOWCELL_ID="${OPTARG}" ;;
        s) SAMPLE_ID="${OPTARG}" ;;
        r) REFERENCE_SEQUENCE="${OPTARG}" ;;
        g) GPACKAGE_PATH="${OPTARG}" ;;
        L) INTERVAL_FILE_PATH="${OPTARG}" ;;
        l) USE_LOW_MEMORY="--low-memory " ;;
        w) USE_WES_MODEL="--use-wes-model " ;;
        h)
            show_help
            exit 1
    esac
done
shift $((OPTIND-1))

# Validate the provided arguments

check_args

# Verify pairwise fastq.gz files are provided

if [ $# -eq 0 ]
then
    printf "ERROR: No .fastq files supplied.\n"
    usage
    exit 1
fi
if [ $(($#%2)) != 0 ]
then
    printf "ERROR: FASTQ files must be paired. Odd number of files passed to program\n"
    usage
    exit 1
fi

# Process pairwise .fastq.gz files into --in-fq sets

count=0
infq=""
for arg in "$@"
do
    count=$(($count+1))
    if [ $(($count%2)) != 1 ] 
    then
        infq="$infq ${arg}"
        continue
    fi
    if [ ! -z "${infq}" ]
    then
        infq="${infq} --in-fq ${arg}"
    else
        infq="--in-fq ${arg}"
    fi
done

# Build output directory structure in variables

OUTPUT_SAMPLE_FOLDER="${OUTPUT_FILES}/${FLOWCELL_ID}/${PANEL_FOLDER}/${SAMPLE_ID}"
OUTPUT_BAM_FOLDER="${OUTPUT_SAMPLE_FOLDER}/bam"
OUTPUT_LOGS_FOLDER="${OUTPUT_SAMPLE_FOLDER}/logs"
OUTPUT_QC_FOLDER="${OUTPUT_SAMPLE_FOLDER}/QC_stats"
OUTPUT_VARIANTS_FOLDER="${OUTPUT_SAMPLE_FOLDER}/variants"

# Build supplementary arguments to supply to Parabricks

INTERVAL_ARG=""
if [ ! -z "${INTERVAL_FILE_PATH}" ]
then
    INTERVAL_ARG="--interval ${INTERVAL_FILE_PATH}"
fi

# Generate defined output structure

echo "Creating output directory structure"
echo "Creating bam directory: ${OUTPUT_BAM_FOLDER}"
mkdir -p ${OUTPUT_BAM_FOLDER}
echo "Creating logs directory: ${OUTPUT_LOGS_FOLDER}"
mkdir -p ${OUTPUT_LOGS_FOLDER}
echo "Creating qc directory: ${OUTPUT_QC_FOLDER}"
mkdir -p ${OUTPUT_QC_FOLDER}
echo "Creating variants directory: ${OUTPUT_VARIANTS_FOLDER}"
mkdir -p ${OUTPUT_VARIANTS_FOLDER}
echo "Directories created successfully"

# Run Parabricks pipeline

echo "Running Nvidia Clara Parabricks DeepVariant Pipeline"
/usr/local/parabricks/pbrun deepvariant_germline \
    ${USE_WES_MODEL} \
    ${USE_LOW_MEMORY} \
    --consider-strand-bias \
    --ref ${REFERENCE_SEQUENCE} \
    --out-bam ${OUTPUT_BAM_FOLDER}/${SAMPLE_ID}.bam \
    --out-duplicate-metrics ${OUTPUT_QC_FOLDER}/${SAMPLE_ID}_duplicate_metrics.txt \
    --out-variants ${OUTPUT_VARIANTS_FOLDER}/variants_deepvariant_caller_${SAMPLE_ID}.vcf \
    --logfile ${OUTPUT_LOGS_FOLDER}/parabricks_deepvariant_germline_${SAMPLE_ID}.log \
    ${INTERVAL_ARG} \
    ${infq}