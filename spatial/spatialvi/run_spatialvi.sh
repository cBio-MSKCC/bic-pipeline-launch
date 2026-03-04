#!/bin/bash

slurm_partition="cmobic_cpu,cmobic_pipeline"
bic_spatialvi="/data1/core001/work/bic/kazmierk/git/bic-spatialvi"
profile="singularity"
email="kazmierk@mskcc.org"
an_dir=$(pwd | sed 's/\/$//')


export MODULEPATH=/etc/modulefiles:/usr/share/modulefiles:/admin/software/lmod/modulefiles:/admin/software/spack/spack_modulefiles/Core
export MODULEPATH_ROOT=/usr/share/modulefiles
export MODULESHOME=/usr/share/lmod/lmod
mkdir -p ${an_dir}/work/scratch
export TMPDIR=${an_dir}/work/scratch
export NXF_SINGULARITY_CACHEDIR=/usersoftware/core001/common/bic/internal/.singularity/cache

. /usr/share/lmod/lmod/init/bash
module load openjdk/17.0.11_9

nextflow=/data1/core001/work/bic/kazmierk/nextflow/25.10.0/nextflow


dir_name=$(basename $an_dir)

job_to_run="sbatch -J \"spatialvi_${dir_name}\" -p ${slurm_partition} -n 4 --time=6-00:00:00 --nodes=1 --mem 8G --chdir=${an_dir} -o ${an_dir}/spatialvi.log -e ${an_dir}/spatialvi.err \
--wrap=\"$nextflow run $bic_spatialvi \
    -profile $profile \
    -resume \
    -ansi-log false \
    -c $bic_spatialvi/conf/bic/iris.config \
    -w ${an_dir}/work \
    --email $email \
    --input ${an_dir}/sample_sheet.csv \
    --merge_sdata true \
    --outdir ${an_dir}/out\""

echo "$job_to_run \n\n"

jobstring=$(eval $job_to_run)
# if this is unsuccessful, print error and exit
if [ $? -ne 0 ]; then
    echo "Error running job: $job_to_run"
    echo "output: $jobstring"
    exit 1
fi

