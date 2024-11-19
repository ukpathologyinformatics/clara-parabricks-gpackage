# UKHC `/gpackage` Resouces for Nvidia Clara Parabricks

---

This repository provides the setup to run the UKHC Parabricks processing pipeline for clinical genomics processing.

### Setup
In addition to the provide script(s), reference files must be provided to Parabricks for successful operation. An example set of reference files can be obtained by following the [Parabricks tutorial setup](https://docs.nvidia.com/clara/parabricks/latest/tutorials/gettingthesampledata.html). Copy those files to the `gpackage/` directory, which is mounted as part of the processing pipeline and supply their location via the `run_deepvariant_pipeline.sh` script.

### `run_deepvariant_pipeline.sh` Usage

```
Run Nvidia Clara Parabricks DeepVariant Pipeline
Required Parameters:
  -o <output_files_path> : The path where the output files should be generated
  -p <panel_folder_name> : The name of the common folder for panel samples (e.g. PEDSALL-V#)
  -f <flowcell_id> : The flowcell indentifier
  -s <sample_id> : The sample accession identifier
  -r <refseq> : The internal Docker path where the reference sequence .fasta file is mounted (usually in /gpackage)
Optional Parameters:
  -g <gpackage_path> : Supply a different gpackage path (defaults to /gpackage)
  -L <interval_file_path> : Interval file to be supplied to the pipeline
Optional Flags:
  -l : Use low-memory mode for GPUs with 16GB of memory
  -w : Use WES mode
