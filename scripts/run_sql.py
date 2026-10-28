"""
SQL 파일을 실행하고, 결과를 화면에 출력하면서 outputs/ 폴더에 CSV로 저장합니다.
저장된 CSV는 노트북 시각화와 Tableau/Looker Studio 대시보드에 그대로 씁니다.

SQL 파일 작성 규칙
    각 쿼리 위에 `-- name: 결과이름` 을 적으면, 그 쿼리 결과가 outputs/결과이름.csv 로 저장됩니다.
    CREATE TABLE 같은 쿼리는 결과가 없으므로 실행만 합니다.

사용법
    python scripts/run_sql.py sql/01_eda.sql
    python scripts/run_sql.py all          # sql/ 폴더의 모든 파일을 번호 순서대로 실행
"""
import pathlib
import re
import sys
import time

import duckdb

ROOT = pathlib.Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "ecommerce.duckdb"
OUT_DIR = ROOT / "outputs"
PREVIEW_ROWS = 15


def split_blocks(sql_text):
    """'-- name: xxx' 표시를 기준으로 쿼리 블록을 나눕니다."""
    parts = re.split(r"^--\s*name:\s*(\S+)\s*$", sql_text, flags=re.MULTILINE)
    blocks = []
    if parts[0].strip():
        blocks.append((None, parts[0]))
    for i in range(1, len(parts), 2):
        blocks.append((parts[i], parts[i + 1]))
    return blocks


def run_file(con, path):
    print(f"\n{'=' * 70}\n▶ {path.relative_to(ROOT)}\n{'=' * 70}")
    for name, sql in split_blocks(path.read_text(encoding="utf-8")):
        sql = sql.strip()
        if not re.search(r"\b(SELECT|CREATE|WITH|INSERT|DROP)\b", sql, re.IGNORECASE):
            continue
        start = time.time()
        result = con.execute(sql)
        is_ddl = re.match(r"(CREATE|DROP|INSERT|ALTER)\b", re.sub(r"^\s*--.*$", "", sql, flags=re.MULTILINE).strip(), re.IGNORECASE)
        if result.description is None or name is None or is_ddl:
            print(f"\n[{name or '실행'}] 완료 ({time.time() - start:.1f}초)")
            continue
        df = result.df()
        for col in df.select_dtypes("float").columns:          # SUM 결과(정수)가 52.0처럼 보이지 않게
            if df[col].dropna().apply(float.is_integer).all():
                df[col] = df[col].astype("Int64")
        OUT_DIR.mkdir(exist_ok=True)
        df.to_csv(OUT_DIR / f"{name}.csv", index=False, encoding="utf-8-sig")
        print(f"\n[{name}] {len(df):,}행 → outputs/{name}.csv ({time.time() - start:.1f}초)")
        print(df.head(PREVIEW_ROWS).to_string(index=False))


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    if not DB_PATH.exists():
        raise SystemExit("DB가 없습니다. 먼저 python scripts/load_data.py 를 실행해 주세요.")

    con = duckdb.connect(str(DB_PATH))
    if sys.argv[1] == "all":
        targets = sorted((ROOT / "sql").glob("*.sql"))
    else:
        targets = [pathlib.Path(p).resolve() for p in sys.argv[1:]]
    for path in targets:
        run_file(con, path)
    con.close()


if __name__ == "__main__":
    main()
