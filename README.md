# bic-pipeline-launch

Repo that should hold scripts to start the steps of the pipeline. This should include getting the pipelines started, and post pipeline actions. Post-pipeline actions should only be actions that don't make sense to have in the pipeline.

## Pipelines

### MusVar
Musvar is the mouse variants pipeline. It utilizes nf-sarek as well as a number of added modules. See [docs/pipelines/musvar.md](docs/pipelines/musvar.md) for more information about running this pipeline.

### RNASeq
RNASeq analysis pipeline consists of nf-rnaseq and nf-diffabundance Nextflow workflows as well as a number of additional modules. It runs on terra, running at iris is still in testing. See [docs/pipelines/rnaseq.md](docs/pipelines/rnaseq.md) for more information about running this pipeline.

### pg2
This contains the command to run 1 run of PG2. Probably some tweaks needs to be made. For example, 

## Automation

There is some automation scripts in `auto_start` which will automatically start the rnaseq pipeline on terra. See [docs/automation/index.md](docs/automation/index.md) for more information about it. 