#!/bin/bash

slurm_partition="cmobic_cpu,cmobic_pipeline"
bic_scrnaseq="/data1/core001/work/bic/kazmierk/git/bic-scrnaseq"
an_dir=$(pwd | sed 's/\/$//')


export MODULEPATH=/etc/modulefiles:/usr/share/modulefiles:/admin/software/lmod/modulefiles:/admin/software/spack/spack_modulefiles/Core
export MODULEPATH_ROOT=/usr/share/modulefiles
export MODULESHOME=/usr/share/lmod/lmod
mkdir -p ${an_dir}/work/scratch
export TMPDIR=${an_dir}/work/tmp
export NXF_SINGULARITY_CACHEDIR=/usersoftware/core001/common/bic/internal/.singularity/cache

. /usr/share/lmod/lmod/init/bash
module load nextflow/24.10.0  
module load openjdk/17.0.11_9

dir_name=$(basename $an_dir)



R1="-R1 /data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L001_R1_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L002_R1_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L003_R1_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L004_R1_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L005_R1_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L006_R1_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L007_R1_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L008_R1_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0077_A233GT3LT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S4_L006_R1_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0077_A233GT3LT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S4_L007_R1_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0077_A233GT3LT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S4_L008_R1_001.fastq.gz"
R2="-R2 /data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L001_R2_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L002_R2_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L003_R2_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L004_R2_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L005_R2_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L006_R2_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L007_R2_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L008_R2_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0077_A233GT3LT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S4_L006_R2_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0077_A233GT3LT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S4_L007_R2_001.fastq.gz,/data1/core001/CACHE/igo/Proj_17877/BONO_0077_A233GT3LT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S4_L008_R2_001.fastq.gz"
#R1="-R1 /data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L001_R1_001.fastq.gz"
#R2="-R2 /data1/core001/CACHE/igo/Proj_17877/BONO_0081_A233GNKLT3/Project_17877/Sample_mix1_IGO_17877_1/mix1_IGO_17877_1_S19_L001_R2_001.fastq.gz"
trim="-trim 10"
tags="-t /data1/core001/work/bic/kazmierk/scrnaseq/Proj_17877/tags.csv"
barcodes="-cbf 1 -cbl 16 -umif 17 -umil 28"
expected_cells="--expected_cells 30000"
output="--output ${an_dir}/cite-seq-out-full"
threads="-T 12"

job_to_run="sbatch -J \"scrnaseq_${dir_name}\" -p ${slurm_partition} -n 15 --time=6-00:00:00 --nodes=1 --mem 90G --chdir=${an_dir} -o ${an_dir}/scrna.log -e ${an_dir}/scrna.err \
--wrap=\"singularity exec -B /data1 -B /usersoftware/core001 /data1/core001/rsrc/genomic/bic/singularity/cite-seq-count/sail-mskcc.cite-seq-count-1.4.5.simg \
CITE-seq-Count \
$R1 \
$R2 \
$trim \
$tags \
$barcodes \
$expected_cells \
$output \
$threads --debug \
> ${an_dir}/cite-seq-count_full.log 2>&1\""

echo "$job_to_run \n\n"

jobstring=$(eval $job_to_run)
# if this is unsuccessful, print error and exit
if [ $? -ne 0 ]; then
    echo "Error running job: $job_to_run"
    echo "output: $jobstring"
    exit 1
fi
