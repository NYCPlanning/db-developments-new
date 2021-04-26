from sqlalchemy import create_engine
from cook import Importer
import os
import pandas as pd
from multiprocessing import Pool, cpu_count
from utils.exporter import exporter
import sys

RECIPE_ENGINE = os.environ.get("RECIPE_ENGINE", "")
BUILD_ENGINE = os.environ.get("BUILD_ENGINE", "")

def ETL(table):
    importer = Importer(RECIPE_ENGINE, BUILD_ENGINE)
    importer.import_table(schema_name=table)


tables = [
    "council_members",
    "doe_school_subdistricts",
    "doe_eszones",
    "doe_mszones",
    "hpd_hny_units_by_building",
]

def dob_cofos():
    recipe_engine = create_engine(RECIPE_ENGINE)
    build_engine = create_engine(BUILD_ENGINE)
    table_names = [record[0] for record in recipe_engine.execute(
        '''
        SELECT table_name FROM information_schema.tables 
        WHERE table_schema = 'dob_cofos' and table_type = 'BASE TABLE'
        '''
    )]
    template = '''
        SELECT 
            '{0}' as v,
            jobnum,
            effectivedate,
            bin,
            boroname,
            housenumber,
            streetname,
            block,
            lot,
            numofdwellingunits,
            occupancyclass,
            certificatetype,
            buildingtypedesc,
            docstatus
        FROM dob_cofos."{0}"
    '''
    query = ' UNION '.join([template.format(tb_name) for tb_name in table_names])
    df=pd.read_sql(query, recipe_engine)
    exporter(df=df, table_name="dob_cofos", con=build_engine)
    del df


if __name__ == "__main__":
    with Pool(processes=cpu_count()) as pool:
        pool.map(ETL, tables)

    dob_cofos()
