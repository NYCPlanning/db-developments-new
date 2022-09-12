import pandas as pd
import sys
from sqlalchemy import create_engine

template_lookup = {
    "aggregate_cdta_2020": "CDTA",
    "aggregate_block_2020": "CensusBlocks",
    "aggregate_tract_2020": "CensusTracts",
    "aggregate_councildst_2010": "CityCouncil",
    "aggregate_commntydst_2010": "CommunityDistricts",
    "aggregate_nta_2020": "NTA",
}

BUILD_ENGINE = sys.argv[1]


def read_aggregate_template(name: str):
    base = pd.read_csv(
        f"data/agg_template/{template_lookup[name]}.csv", dtype=str)
    base.set_index(get_index_columns(name),
                   inplace=True, verify_integrity=True)
    base.drop(columns=base.columns, axis=1, inplace=True)
    return base


def get_index_columns(name: str):
    index_name = {
        "aggregate_cdta_2020": "cdta2020",
        "aggregate_block_2020": "bctcb2020",
        "aggregate_tract_2020": "bct2020",
        "aggregate_councildst_2010": "councildst",
        "aggregate_commntydst_2010": "commntydst",
        "aggregate_nta_2020": "nta2020",
    }
    return index_name[name]


if __name__ == "__main__":

    table = sys.argv[2]

    engine = create_engine(BUILD_ENGINE)
    base = read_aggregate_template(table)
    df = pd.read_sql(f"""SELECT * FROM {table}""", con=engine)

    df.dropna(axis=0, subset=[get_index_columns(table)], inplace=True)
    df.set_index(get_index_columns(table), inplace=True, verify_integrity=True)

    final = pd.concat([base, df], axis=1)

    final.to_csv(f"output/{table}.csv", index=True)
