#!/bin/bash

set -e

host=$(hostname)
script_dir=$(dirname "$(realpath "$0")")

if [ $host != "islogin01.mskcc.org" ] ; then
    echo "As of right now, this script must be run on islogin01.mskcc.org."
    exit 1
fi


# constants
bic_adiago="/usersoftware/core001/common/bic/internal/adiago/dev"
profile="singularity"
slurm_partition="cmobic_cpu,cmobic_pipeline"
delivery_dir="kristakaz@terra:/ifs/rtsia01/bic/results"
#delivery_dir="/data1/core002/res/bic/results"
# usage:
if [ $# -lt 3 ]; then
    echo "Usage: run_wes_adiago_iris.sh <request file> <analysis directory> <email> <rsync_dir> [extra args]"
    exit 1
fi

# inputs:
# 1: request file
# 2: analysis directory (whould contain input files)
# 3: email
# 4: rsync directory
## extra args (optional)
req_file=$1
an_dir=$2
email=$3
#rsync_dir=$4
shift 3

# remove tailing / on an_dir
an_dir=$(echo $an_dir | sed 's/\/$//')


extra_args=$@

declare -A target_map
target_map["IDT_Exome_v2_FP_b37"]="idt_v2"

run_number=$(grep ^RunNumber $req_file | cut -f2 -d":" | tr -d " " | xargs printf "%03d" )
target=$(grep ^Assay: $req_file | cut -f2 -d":" | tr -d " " )
project_id=$(grep ^ProjectID $req_file | cut -f2 -d":" | tr -d " " | sed 's/Proj_//')



genome=${genome_map[$build]}

export MODULEPATH=/etc/modulefiles:/usr/share/modulefiles:/admin/software/lmod/modulefiles:/admin/software/spack/spack_modulefiles/Core
export MODULEPATH_ROOT=/usr/share/modulefiles
export MODULESHOME=/usr/share/lmod/lmod
mkdir -p ${an_dir}/work/scratch
export TMPDIR=${an_dir}/work/scratch
export NXF_SINGULARITY_CACHEDIR=/usersoftware/core001/common/bic/internal/.singularity/cache
export PATH=${bic_adiago}/bin:$PATH

. /usr/share/lmod/lmod/init/bash
##module load singularityce/4.1.0
module load nextflow/24.10.0  
module load openjdk/17.0.11_9

dir_name=$(basename $an_dir)

## first turn into input files:
mapping=${an_dir}/inputTempo_mapping.tsv
pairing=${an_dir}/inputTempo_pairing.tsv

# if mapping or pairing is not found, create input files
if [ ! -e $mapping ] || [ -z $pairing ]; then
    echo "Creating input files..."
    r_simg="/data1/core001/rsrc/genomic/bic/singularity/r_xlsx_tidyverse/r_xlsx_tidyverse.simg"
    bic2nf="singularity exec -B /data1 -B /usersoftware $r_simg ${bic_adiago}/scripts/bic2tempo.R ${an_dir}/*sample_mapping.txt_iris.txt ${an_dir}/*sample_pairing.txt ${target_map[$target]}"
    echo "Bic2nf command: $bic2nf"

    eval $bic2nf

    if [ $? -ne 0 ]; then
        echo "Error creating input files: $bic2nf"
        exit 1
    fi
    echo "Input files created: $bic2nf"
fi
echo "Input files not created"


rsync_job_hold=""

job_to_run="sbatch -J \"adiago${dir_name}\" -p ${slurm_partition} -n 4 --mail-user=${email} --mail-type=END,FAIL --time=6-00:00:00 --mem 8G --chdir=${an_dir} -o ${an_dir}/adiago.log -e ${an_dir}/adiago.err \
--wrap=\"${bic_adiago}/bin/runTempoWESCohort.sh $project_id $mapping $pairing\""

echo "$job_to_run \n\n"

jobstring=$(eval $job_to_run)
# if this is unsuccessful, print error and exit
if [ $? -ne 0 ]; then
    echo "Error running job: $job_to_run"
    echo "output: $jobstring"
    exit 1
fi
jobid=${jobstring##* }


rsync_job_hold="--dependency=afterok:$jobid"

# if rsync is filled out, do finalize script
if [ -z $rsync_dir ]; then
    echo "No rsync directory provided, skipping rsync."
    exit 0
fi

sleep 1


