#/usr/bin/env python3

import logging
from utils.ticket_utils import get_igo_ids
from utils.project_utils import project_files_exist
from auto_config import REQUEST_PIPELINE_DATA, PROJECT_FILE_GENERATION_SCRIPT

# This sciprt will be used to generate the project files for a project
# I will need a good project id from the description of the task
# if there is more than one project ID, I have to ask the user to do this manually

def generate_project_files(ticket, pipeline):
    igo_ids = get_igo_id(ticket)
    if len(igo_ids) > 1:
        logging.error(f"There is more than one IGO id in the description of the task {ticket['id']}")
        return False
    if not igo_ids:
        logging.error(f"No IGO id found in the description of the task {ticket['id']}")
        return False
    
    igo_id = igo_ids[0]

    if project_files_exist(igo_id, REQUEST_PIPELINE_DATA[pipeline]['project_files_dir']):
        logging.info(f"Project files already exist for the IGO id {igo_id} - this must be done manually")
        return False
    
    # create project folder
    proj_dir = create_project_folder(igo_id, REQUEST_PIPELINE_DATA[pipeline]['project_files_dir'])

    # create readme file
    create_readme_file(igo_id, proj_dir, ticket['description'])

    # run project file generation script
    pfg_cmd = f"cd {proj_dir} && python {PROJECT_FILE_GENERATION_SCRIPT} {igo_id}"
    pfg_output = subprocess.run(pfg_cmd, shell=True, check=True, capture_output=True)
    logging.info(f"Project files generated for the IGO id {igo_id}")

    #check output of project file generation script
    if pfg_output.returncode != 0:
        logging.error(f"Project file generation script failed for the IGO id {igo_id}")
        logging.error(f"Output: {pfg_output.stdout.decode('utf-8')}")
        logging.error(f"Error: {pfg_output.stderr.decode('utf-8')}")
        raise Exception(f"Project file generation script failed for the IGO id {igo_id}")

    return True

