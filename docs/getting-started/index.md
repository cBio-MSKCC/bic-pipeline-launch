# Getting Started

## Prerequisites

- Access to required execution environment(s), such as IRIS
- Appropriate credentials/secrets for workflow launch
- Familiarity with pipeline-specific docs files in this repository

## Repository layout

- `rnaseq/` - RNA-seq launch scripts
- `musvar/` - mouse variant workflow launch scripts
- `scRNA/` - single-cell workflow launch scripts
- `variants/` - additional variant flow support
- `auto_start/` - automation helpers for startup pipelines

## Suggested documentation workflow

When adding or updating launch scripts:

1. Add or update the module's page in `docs/`
2. Include a runnable example command
3. Capture known failure modes in troubleshooting notes
