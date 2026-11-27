# BIC Pipeline Launch

This repository contains launch scripts and operational glue for running and coordinating BIC analysis workflows.

## What this repo is for

- Starting pipeline runs (especially Nextflow-based pipelines)
- Wrapping post-pipeline actions that do not belong inside core pipeline code
- Housing lightweight automation for routine launch tasks

## Pipelines currently represented

- `MusVar`: mouse variant calling workflow support
- `RNASeq`: RNA-seq launch flow (including diff abundance components)
- `scRNA`: single-cell related launch/config support
- `Variants`: variant-oriented helpers

## Next steps

Use this docs site as the single place for runbooks:

1. Add run commands and required inputs per pipeline
2. Document environment assumptions (Terra, local testing, credentials)
3. Add troubleshooting and ownership notes
