"""
1단계: 원본 CSV를 DuckDB 테이블(events_raw)로 적재합니다.

사용법 (프로젝트 폴더에서 실행)
    python scripts/load_data.py            # data/raw/*.csv 적재
    python scripts/load_data.py --sample   # 연습용 가짜 데이터(data/sample) 적재

컬럼 타입을 직접 지정하는 이유
    read_csv_auto는 일부 행만 보고 타입을 추측합니다. user_id 같은 큰 숫자나
    "2019-10-01 00:00:00 UTC" 형식의 시간이 잘못 추측되는 일을 막기 위해
    타입을 명시하고, 시간은 문자열로 읽은 뒤 정제 단계(02_cleaning.sql)에서 변환합니다.
"""
import argparse
import pathlib
import time

import duckdb

ROOT = pathlib.Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "ecommerce.duckdb"

COLUMNS = {
    "event_time": "VARCHAR",
    "event_type": "VARCHAR",
    "product_id": "BIGINT",
    "category_id": "BIGINT",
    "category_code": "VARCHAR",
    "brand": "VARCHAR",
    "price": "DOUBLE",
    "user_id": "BIGINT",
    "user_session": "VARCHAR",
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sample", action="store_true", help="data/sample의 가짜 데이터 사용")
    args = parser.parse_args()

    data_dir = ROOT / "data" / ("sample" if args.sample else "raw")
    files = sorted(data_dir.glob("*.csv"))
    if not files:
        raise SystemExit(
            f"{data_dir} 에 CSV가 없습니다. data/README.md를 보고 데이터를 먼저 받아 주세요.\n"
            "연습용 데이터로 돌려보려면: python scripts/make_sample_data.py 후 --sample 옵션 사용"
        )

    print(f"적재할 파일 {len(files)}개:")
    for f in files:
        print(f"  - {f.name} ({f.stat().st_size / 1e6:,.0f} MB)")

    columns_sql = "{" + ", ".join(f"'{k}': '{v}'" for k, v in COLUMNS.items()) + "}"
    glob_path = (data_dir / "*.csv").as_posix()

    start = time.time()
    con = duckdb.connect(str(DB_PATH))
    con.execute(f"""
        CREATE OR REPLACE TABLE events_raw AS
        SELECT *, regexp_extract(filename, '[^/\\\\]+$') AS source_file
        FROM read_csv('{glob_path}', header = true, columns = {columns_sql}, filename = true)
    """)
    con.execute("ALTER TABLE events_raw DROP COLUMN filename")

    n = con.execute("SELECT COUNT(*) FROM events_raw").fetchone()[0]
    print(f"\nevents_raw 적재 완료: {n:,}행 ({time.time() - start:.1f}초)")
    print(f"DB 파일: {DB_PATH}")
    print("\n다음 단계: python scripts/run_sql.py sql/01_eda.sql")
    con.close()


if __name__ == "__main__":
    main()
