#/usr/bin/env python3

import logging
import re
from auto_config import CHECK_FASTQ_IGO

# Helper scripts for working with ticket objects

def get_igo_ids(ticket: dict) -> list[str]:
    # This function will get the IGO id from the description of the task
    igo_id_set = set()
    for line in ticket['description'].splitlines():
        if any(line.startswith(keyword) for keyword in CHECK_FASTQ_IGO):
            logging.debug(f"Found IGO ID line in ticket {ticket['id']}: {line}")
            igo_id_value = line.split(":", maxsplit=1)[-1].strip()
            # regex to find igo ids in the line
            igo_ids = re.findall(r'(\d{5}(?:_[a-zA-Z]+)?)', igo_id_value)
            if igo_ids:
                igo_id_set.update(igo_ids)
                logging.debug(f"IGO IDs found: {igo_ids}")
    return list(igo_id_set)


