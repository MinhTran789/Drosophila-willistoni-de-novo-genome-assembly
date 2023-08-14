# Drosophila-willistoni de novo genome assembly
This repository contains the code to implement the de novo assembly step provided by https://doi.org/10.1111/mec.16941 on the DNAnexus platform

The author's source code is available at https://github.com/pgonzale60/Nonmodel-Species/blob/main/genome_assembly.sh

The `src/` folder contains the WDL tasks and workflows that need to be compiled to DNAnexus native apps and workflow, using the dxCompiler file. The latest version of dxCompiler cna be downloaded from https://github.com/dnanexus/dxCompiler/releases

# Input files
Input files were provided by the author and can be downloaded from:
- D. willistoni standard genomic HiSeq (SRR13703952): https://trace.ncbi.nlm.nih.gov/Traces/?view=run_browser&acc=SRR13703952&display=metadata
- D. willistoni standard genomic PacBio (SRR13703953): https://trace.ncbi.nlm.nih.gov/Traces/?view=run_browser&acc=SRR13703953&display=metadata
- ENA Project PRJNA670571: https://www.ebi.ac.uk/ena/browser/view/PRJNA670571

# Docker images
The following docker images were pulled/built and used within the WDL tasks:
- Trimmomatic: https://hub.docker.com/r/staphb/trimmomatic
- Platanus: Built from https://github.com/cmonjeau/docker-platanus
- Canu: https://hub.docker.com/r/biocontainers/canu/tags
- MUMmer 4: https://registry.hub.docker.com/r/staphb/mummer/tags
- Quickmerge: https://quay.io/repository/biocontainers/quickmerge?tab=tags&tag=latest
- Interleave fastq: https://hub.docker.com/r/erictdawson/interleave-fastq
- BWA/Samtools: https://hub.docker.com/r/dukegcb/bwa-samtools
