#/usr/bin/env python3

import logging
import re
import glob

# Helper scripts for working with project files

def project_files_exist(igo_id, project_files_dir):
    # This function will check if the project files exist
    project_files_dir = os.path.join(project_files_dir, "Proj_" + igo_id)
    if os.path.exists(project_files_dir):
        if glob.glob(os.path.join(project_files_dir, "README.txt")):
            return True
    return False

def create_project_folder(igo_id, project_files_dir):
    # This function will create the project folder
    project_files_dir = os.path.join(project_files_dir, "Proj_" + igo_id)
    if not os.path.exists(project_files_dir):
        os.makedirs(project_files_dir)
    return project_files_dir

def create_readme_file(igo_id, project_files_dir, ticket_description):
    # This function will create the readme file
    readme_file = os.path.join(project_files_dir, "README.txt")
    with open(readme_file, "w") as f:
        f.write(ticket_description)


