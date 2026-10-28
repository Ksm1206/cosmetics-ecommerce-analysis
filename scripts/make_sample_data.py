"""
연습용 가짜 데이터를 만듭니다. (실제 Kaggle 데이터가 아닙니다!)

실제 데이터(2GB)를 받기 전에 코드가 잘 돌아가는지 확인하거나,
쿼리를 빠르게 실험할 때 씁니다. 실제와 같은 컬럼·형식에 결측·중복·음수 가격도 흉내 냅니다.
이 데이터로 나온 숫자는 의미가 없으니 README나 인사이트에 쓰지 마세요.

사용법
    python scripts/make_sample_data.py
    python scripts/load_data.py --sample
"""
import pathlib

import numpy as np
import pandas as pd

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "sample"
rng = np.random.default_rng(42)

N_USERS, N_PRODUCTS = 8_000, 1_500
BRANDS = ["runail", "irisk", "masura", "grattol", "estel", "ingarden", "uno", "kapous",
          "jessnail", "bpw.style", "freedecor", "concept", "lianail", "smart", "yoko"]
MONTHS = [("2019-Oct", "2019-10-01", 31), ("2019-Nov", "2019-11-01", 30),
          ("2019-Dec", "2019-12-01", 31), ("2020-Jan", "2020-01-01", 31),
          ("2020-Feb", "2020-02-01", 29)]
HEX = list("0123456789abcdef")

products = pd.DataFrame({
    "product_id": rng.integers(5_000_000, 5_900_000, N_PRODUCTS),
    "category_id": rng.choice(rng.integers(1_480_000_000_000_000_000, 2_200_000_000_000_000_000, 60), N_PRODUCTS),
    "brand": np.where(rng.random(N_PRODUCTS) < 0.4, None, rng.choice(BRANDS, N_PRODUCTS)),
    "price": np.round(rng.lognormal(1.6, 0.9, N_PRODUCTS), 2),
})
products["category_code"] = np.where(rng.random(N_PRODUCTS) < 0.98, None, "apparel.glove")
products = products.to_dict("records")
user_ids = rng.integers(400_000_000, 622_000_000, N_USERS)
weights = rng.pareto(1.5, N_USERS) + 0.3          # 소수 사용자가 활동 대부분을 차지
weights /= weights.sum()

OUT.mkdir(parents=True, exist_ok=True)
for fname, start, days in MONTHS:
    n_sessions = int(9_000 * (1.4 if fname == "2019-Nov" else 1.0))   # 11월 블랙프라이데이 효과
    s_users = rng.choice(user_ids, n_sessions, p=weights)
    s_start = pd.Timestamp(start) + pd.to_timedelta(rng.random(n_sessions) * days * 86400, unit="s")
    rows = []
    for uid, t in zip(s_users, s_start):
        sess = "".join(rng.choice(HEX, 8)) + "-" + "".join(rng.choice(HEX, 4))
        boost = 1.3 if t.dayofweek >= 5 else 1.0                     # 주말에 전환이 조금 높게
        for idx in rng.choice(len(products), rng.integers(1, 8), replace=False):
            p = products[idx]
            t += pd.Timedelta(seconds=int(rng.integers(5, 300)))
            rows.append((t, "view", p, uid, sess))
            if rng.random() < 0.08 * boost:
                t += pd.Timedelta(seconds=int(rng.integers(5, 120)))
                rows.append((t, "cart", p, uid, sess))
                r = rng.random()
                if r < 0.30:
                    rows.append((t + pd.Timedelta(seconds=30), "remove_from_cart", p, uid, sess))
                elif r < 0.30 + (0.45 if p["price"] > 5 else 0.25) * boost:   # 저가 상품은 구매 전환 낮게
                    rows.append((t + pd.Timedelta(seconds=600), "purchase", p, uid, sess))

    month_end = pd.Timestamp(start) + pd.DateOffset(months=1)
    rows = [r for r in rows if r[0] < month_end]                      # 다음 달로 넘어간 이벤트 제거
    df = pd.DataFrame([{
        "event_time": tt.strftime("%Y-%m-%d %H:%M:%S") + " UTC", "event_type": et,
        "product_id": p["product_id"], "category_id": p["category_id"],
        "category_code": p["category_code"], "brand": p["brand"], "price": p["price"],
        "user_id": uid, "user_session": sess,
    } for tt, et, p, uid, sess in rows])

    # 실제 데이터의 지저분함 흉내: 중복 행, 음수 가격, 세션 결측
    df = pd.concat([df, df.sample(frac=0.01, random_state=1)])
    df.loc[df.sample(frac=0.001, random_state=2).index, "price"] = -1.0
    df.loc[df.sample(frac=0.0005, random_state=3).index, "user_session"] = None
    df = df.sort_values("event_time")
    df.to_csv(OUT / f"{fname}.csv", index=False)
    print(f"{fname}.csv: {len(df):,}행")

print(f"\n완료 → {OUT}\n다음 단계: python scripts/load_data.py --sample")
