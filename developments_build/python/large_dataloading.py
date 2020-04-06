from sqlalchemy import create_engine
from cook import Importer
import os
import pandas as pd
from multiprocessing import Pool, cpu_count

RECIPE_ENGINE = os.environ.get('RECIPE_ENGINE', '')
BUILD_ENGINE=os.environ.get('BUILD_ENGINE', '')
EDM_DATA = os.environ.get('EDM_DATA', '')

def ETL(table):
    importer = Importer(RECIPE_ENGINE, BUILD_ENGINE)
    importer.import_table(schema_name=table)

large_tables = ['dob_permitissuance',
                'dob_jobapplications',
                'dob_cofos',
                'dof_dtm',
                'dcp_mappluto',
                'doitt_buildingfootprints',
                'doitt_zipcodeboundaries']

small_tables = ['housing_input_lookup_occupancy',
                'housing_input_lookup_status',
                'housing_input_research',
                'dcp_ntaboundaries',
                'dcp_cdboundaries',
                'dcp_censusblocks',
                'dcp_censustracts',
                'dcp_school_districts',
                'dcp_boroboundaries_wi',
                'dcp_councildistricts',
                'housing_input_hny_job_manual',
                'hpd_hny_units_by_building',
                'hpd_hny_units_by_project',
                'housing_input_hny']
                
def dob_cofos_append():
    df = pd.read_sql("SELECT * FROM dob_cofos.append", RECIPE_ENGINE)
    df.to_sql('dob_cofos_append', BUILD_ENGINE, if_exists='replace', chunksize=2000, index=False)

def old_developments():
    importer = Importer(EDM_DATA, BUILD_ENGINE)
    importer.import_table(schema_name='developments', version="2019/09/10")

if __name__ == "__main__":
    with Pool(processes=cpu_count()) as pool:
            pool.map(ETL, large_tables)
    
    dob_cofos_append()
    old_developments()