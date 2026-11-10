"""Run a .sql file made of '-- name: xxx' blocks; print + export each result to /home/claude/olist_project/data/out/xxx.csv"""
import sqlite3, sys, os, re, pandas as pd
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
con = sqlite3.connect(os.path.join(ROOT, "olist.db"))
os.makedirs(os.path.join(ROOT, "data", "out"), exist_ok=True)
path = sys.argv[1]; show = "--quiet" not in sys.argv
txt = open(path).read()
if "-- name:" not in txt:
    con.executescript(txt); print("executed", path); sys.exit()
for blk in re.split(r"(?m)^-- name:\s*", txt)[1:]:
    name, _, sql = blk.partition("\n")
    df = pd.read_sql(sql, con)
    df.to_csv(os.path.join(ROOT, "data", "out", name.strip() + ".csv"), index=False)
    if show:
        print(f"\n### {name.strip()}  ({len(df)} rows)"); print(df.head(12).to_string(index=False))
