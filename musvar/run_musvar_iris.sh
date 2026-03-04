#!/bin/bash

set -e


host=$(hostname)
script_dir=$(dirname "$(realpath "$0")")

if [ $host != "islogin01.mskcc.org" ] ; then
    echo "As of right now, this script must be run on islogin01.mskcc.org."
    exit 1
fi

sarek_dir="/usersoftware/core001/common/bic/internal/bic-sarek/dev"
profile="singularity"
rsync_only=false
slurm_partition="cmobic_cpu,cmobic_pipeline"

# usage:
# run_musvar_terra.sh <request file> <analysis directory> <email> <rsync_dir> [extra args]
if [ $# -lt 3 ]; then
    echo "Usage: run_musvar_iris.sh <request file> <analysis directory> <email> <rsync_dir> [extra args]"
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
rsync_dir=$4
shift 4

if [ "$1" == "rsync_only" ]; then
    rsync_only=true
    shift 1
fi

# remove tailing / on an_dir
an_dir=$(echo $an_dir | sed 's/\/$//')

extra_args=$@

# map between request target and config filename
declare -A targets_map
targets_map["M-IMPACT"]="impact"
targets_map["TWIST"]="twist"

declare -A genome_map
genome_map["mm38"]="GRCm38_local"
genome_map["mm39"]="GRCm39_local"

if [ ! -f $an_dir/input.csv ]; then
    echo
    echo "Error: $an_dir/input.csv not found. This is required for the sarek pipeline"
    echo
    exit
fi


build=$(grep ^Build $req_file | cut -f2 -d":" | tr -d " ")
run_number=$(grep ^RunNumber $req_file | cut -f2 -d":" | tr -d " " | xargs printf "%03d" )

### targets pulled from request file
###
targets=$(grep ^Targets: $req_file | cut -f2 -d":" | tr -d " " | xargs printf "%s" )
if [ -z "$targets" ]; then
    echo
    echo "Error: No taregets found in request file. This is required for the sarek pipeline"
    echo
    exit
fi
if [ -z "${targets_map[$targets]}" ]; then
    echo
    echo "Error: Invalid targets '$targets' in request file. Valid targets are: ${!targets_map[@]}"
    echo
    exit
fi

targets_config=$sarek_dir/conf/bic/targets/${targets_map[$targets]}.config
# check targets conf dir to see if a target config exists
if [ ! -f $targets_config ]; then
    echo
    echo "Error: $targets_config not found. This is required for the sarek pipeline"
    echo
    exit
fi
setup_env="
export MODULEPATH=/etc/modulefiles:/usr/share/modulefiles:/admin/software/lmod/modulefiles:/admin/software/spack/spack_modulefiles/Core;
export MODULEPATH_ROOT=/usr/share/modulefiles;
export MODULESHOME=/usr/share/lmod/lmod;
export NXF_SINGULARITY_CACHEDIR=/usersoftware/core001/common/bic/internal/.singularity/cache;
mkdir -p ${an_dir}/work/scratch;
export TMPDIR=${an_dir}/work/scratch;

. /usr/share/lmod/lmod/init/bash;
##module load singularityce/4.1.0;
module load nextflow/24.10.0;
module load openjdk/17.0.11_9;
"
eval $setup_env

dir_name=$(basename $an_dir)

if [ $rsync_only == false ]; then 
    rsync_job_hold="-w post_done(MusVar_${dir_name})"

    nf_cmd="sbatch -J \"MusVar_${dir_name}\" -p ${slurm_partition} -n 4 --time=6-00:00:00 -cwd ${an_dir} --mem 8G -o ${an_dir}/musvar.log -e ${an_dir}/musvar.err \
    --wrap=\"nextflow run $sarek_dir/main.nf \
        -profile $profile \
        -resume \
        -ansi-log false \
        -c $sarek_dir/conf/bic/bic_musvar.config \
        -c $sarek_dir/conf/bic/iris.config \
        -c $targets_config \
        -work-dir ${an_dir}/work \
        --genome ${genome_map[$build]} \
        --igenomes_ignore true \
        --email_on_fail $email \
        --tools freebayes,mutect2,strelka,manta \
        --input ${an_dir}/input.csv \
        --outdir ${an_dir}/r_${run_number}\""
    
    # so we can rerun by hand if needed
    {
    echo "$setup_env"
    echo
    echo
    echo "$nf_cmd"
    } > "${an_dir}/musvar_cmd.txt"
    
    jobstring=$(eval $nf_cmd)
    
    if [ $? -ne 0 ]; then
        echo "Error running job: $job_to_run"
        echo "output: $jobstring"
        exit 1
    fi

    echo "MusVar pipeline submitted for analysis directory: $an_dir"
fi
jobid=${jobstring##* }

# if rsync is filled out, do finalize script
if [ -z $rsync_dir ]; then
    echo "No rsync directory provided, skipping rsync."
    exit 0
fi

rsync_job_hold="--dependency=afterok:$jobid"

job_to_run="sbatch -J \"finalize_${dir_name}\" $rsync_job_hold --mail-user=${email} --mail-type=END,FAIL \
-n 1 --time=6-00:00:00 -p ${slurm_partition} --mem 2G --chdir=${an_dir} -o ${an_dir}/rsync.log -e ${an_dir}/rsync.err \
--wrap=\"/bin/bash ${script_dir}/rsync_summary_finalize.sh $an_dir ${an_dir}/r_${run_number} $rsync_dir\""
echo "$job_to_run \n\n"
jobstring=$(eval $job_to_run) 
if [ $? -ne 0 ]; then
    echo "Error running job: $job_to_run"
    echo "output: $jobstring"
    exit 1
fi
jobid=${jobstring##* }