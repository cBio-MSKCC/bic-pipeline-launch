#! /bin/bash
set -e

# This script needs to do some finalization of the pipeline. Things it will do:
# 1. Move project files to the <outdir>/project_files directory.
# 2. Run bicdelivery_summary script.
# 3. Rsync the results to the rsync directory

script_dir=$(dirname "$(realpath "$0")")

# if there is not 6 arguments, print usage and exit
if [ $# -ne 6 ]; then
    echo "Usage: rsync_summary_finalize.sh <rundir> <outdir> <rsync_dir>"
    echo "run_dir: directory where the pipeline was run (should have project files)"
    echo "out_dir: outdir provided to the pipeline"
    echo "rsync_dir: directory to rsync the results to"    
    echo "pfg_simg: path to the pfg singularity image"
    echo "delivery_dir: directory to rsync the results to for delivery"
    echo "cluster: cluster that this script is running on"
    exit 1
fi

# grab rundir output, rsync dirs from command line
run_dir=$1
out_dir=$2
rsync_dir=$3
pfg_simg=$4
delivery_dir=$5
cluster=$6

# if outdir is not a full path, add it to run_dir.
if [[ $out_dir != /* ]]; then
    out_dir=$run_dir/$out_dir
fi

#
# Move project to project_files directory
#
mkdir -p $out_dir/project_files
cp $run_dir/*sample_mapping.txt $run_dir/*request.txt $run_dir/*input.csv $out_dir/project_files/

#
# Rsync the results to the rsync directory
#

echo "rsync -avzP --exclude-from=${script_dir}/rsync_excludes.txt $run_dir $rsync_dir"
rsync -avzP --exclude-from=${script_dir}/rsync_excludes.txt $run_dir $rsync_dir

#
# rsync to delivery directory
#
pi=$(grep ^PI: $out_dir/project_files/*request.txt | cut -f2 -d":" | tr -d " ")
inv=$(grep ^Investigator: $out_dir/project_files/*request.txt | cut -f2 -d":" | tr -d " ")
inv_name=$(grep ^Investigator_Name: $out_dir/project_files/*request.txt | cut -f2 -d":" | tr -d " ")
proj_id=$(grep ^ProjectID: $out_dir/project_files/*request.txt | cut -f2 -d":" | tr -d " ")
run_num="r_$(grep ^RunNumber $out_dir/project_files/*request.txt | cut -f2 -d":" | tr -d " " | xargs printf "%03d" )"
build=$(grep ^Build: $out_dir/project_files/*request.txt | cut -f2 -d":" | tr -d " ")
pipelines=$(grep ^Pipelines: $out_dir/project_files/*request.txt | cut -f2 -d":" | tr -d " ")
if [ -z "$pi" ] || [ -z "$inv" ]; then
    printf "No PI or Investigator found in request file, not delivering project!\n"
    exit 1
fi
del_path=${delivery_dir}/${pi}/${inv}/${proj_id}/

delivery_user="none"
delivery_host="none"
# if delivery_dir contains an @ in it, don't mkdir -p, just rsync
if [[ $delivery_dir == *"@"* ]]; then
    delivery_user=$(echo $delivery_dir | cut -d"@" -f1)
    delivery_host=$(echo $delivery_dir | cut -d"@" -f2 | cut -d":" -f1)
    echo "Delivery directory contains an @, have to create files differently"
    del_path_no_server=${del_path#*:}
    create_dirs="ssh ${delivery_user}@${delivery_host} 'umask 002 && mkdir -m 775 -p ${del_path_no_server}'"
    eval $create_dirs
else
    mkdir -m 775 -p $del_path
fi

echo "rsync -avz --chmod=Du=rwx,Dg=rwx,Do=rx,Fu=rw,Fg=rw,Fo=r --exclude-from=${script_dir}/rsync_excludes.txt $out_dir $del_path"
rsync -avz --chmod=Du=rwx,Dg=rwx,Do=rx,Fu=rw,Fg=rw,Fo=r --exclude-from=${script_dir}/rsync_excludes.txt $out_dir $del_path


#
# ticket_update
#
# if grab lines from stderr that start with ERROR, add to comment in ticket
# grab pipeline version for both rnaseq and diff
# close those tickets.
comments=""
ticket_id=""
diff_ver=""

## PEROFRM DELIVERY
# This is going to be a crazy command because I have to run it in one big line on delivery host.
del_path_no_server="${del_path#*:}"
del_build=$build
if [[ $del_build == "hg38_mm39" ]]; then 
    del_build="hybrid"
fi

if [[ $del_build == "mm38" ]]; then
    del_build="mm10"
fi

cmd_for_delivery="ssh ${delivery_user}@${delivery_host} 'export MODULEPATH=/compute/juno/bic/ROOT/opt/modulefiles:$MODULEPATH \
&& . /usr/share/Modules/init/bash && module load singularity/3.7.1 && cd $del_path_no_server \
&& cp ${del_path_no_server}/${run_num}/project_files/Proj*request.txt . \
&& singularity exec --bind /juno/bic --bind /ifs /juno/opt/common/bic/internal/project_file_generation/pfg.simg python3 /authorization_db/init_project_permissions.py --project_path $del_path_no_server --assembly $del_build \
&& rm Proj*request.txt'"

echo "Running delivery command: $cmd_for_delivery"
eval $cmd_for_delivery

if [ $cluster == "iris" ]; then
    echo "Removing fastq files from CACHE directory"
    rm -r /data1/core001/CACHE/igo/${proj_id}
fi

#
# email delivery
#
eml1=$(grep ^DeliverTo_Email: $out_dir/project_files/*request.txt | cut -f2 -d":" | tr -d " ")
eml2=$(grep ^PI_E-mail: $out_dir/project_files/*request.txt | cut -f2 -d":" | tr -d " ")
eml3=$(grep ^Investigator_E-mail: $out_dir/project_files/*request.txt | cut -f2 -d":" | tr -d " ")

all_emails=$(printf '%s\n%s\n%s\n' "$eml1" "$eml2" "$eml3" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort -u)
unique_emails=$(echo "$all_emails" | tr '\n' ',' | sed 's/,$//')

email_delivery_cmd="bash ${script_dir}/email_delivery_template.sh $proj_id $run_num '$inv_name' $unique_emails"
echo "Running email delivery command: $email_delivery_cmd"
eval $email_delivery_cmd
