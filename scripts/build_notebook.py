"""notebooks/analysis.ipynb 를 생성하는 스크립트 (노트북 셀을 고치고 싶다면 노트북을 직접 수정해도 됩니다)."""
import pathlib

import nbformat as nbf

ROOT = pathlib.Path(__file__).resolve().parents[1]
nb = nbf.v4.new_notebook()
md, code = nbf.v4.new_markdown_cell, nbf.v4.new_code_cell

nb.cells = [
md("""# 화장품 쇼핑몰 행동 로그 분석 — 5단계: 시각화와 통계 검정

**큰 질문:** 조회는 많은데 구매로 이어지지 않는 원인은 무엇이고, 어떻게 전환율을 높일 수 있는가?

실행 전 준비
1. `python scripts/load_data.py` (원본 적재)
2. `python scripts/run_sql.py all` (SQL 분석 → `outputs/*.csv`)

이 노트북은 `outputs/` 폴더의 CSV를 읽어 차트를 그리고, 차트 이미지를 `images/`에 저장합니다.
README에는 `images/`의 이미지를 넣으세요."""),

code("""import pathlib
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
import numpy as np
import pandas as pd
import seaborn as sns
from scipy.stats import chi2_contingency

ROOT = pathlib.Path.cwd().parent if pathlib.Path.cwd().name == "notebooks" else pathlib.Path.cwd()
OUT, IMG = ROOT / "outputs", ROOT / "images"
IMG.mkdir(exist_ok=True)

# 한글 폰트: 윈도우(맑은 고딕) / 맥(애플고딕) / 리눅스·코랩(나눔고딕) 중 있는 것 사용
installed = {f.name for f in fm.fontManager.ttflist}
for font in ["Malgun Gothic", "AppleGothic", "NanumGothic", "Noto Sans CJK KR"]:
    if font in installed:
        plt.rcParams["font.family"] = font
        break
else:
    print("한글 폰트를 찾지 못했습니다. 차트의 한글이 네모로 보이면 나눔고딕을 설치하세요.")
plt.rcParams["axes.unicode_minus"] = False
sns.set_theme(style="whitegrid", font=plt.rcParams["font.family"])

def load(name, **kw):
    return pd.read_csv(OUT / f"{name}.csv", **kw)

def save(fig, name):
    fig.savefig(IMG / f"{name}.png", dpi=150, bbox_inches="tight")"""),

md("## 1. 핵심 KPI"),
code("""kpi = load("kpi_overall").iloc[0]
print(f"총 매출        : {kpi.revenue:,.0f}")
print(f"전체 사용자    : {kpi.users:,.0f}  /  구매 고객: {kpi.buyers:,.0f}")
print(f"주문 수(근사)  : {kpi.orders:,.0f}  /  객단가(AOV): {kpi.aov:,.2f}")
print(f"세션 구매전환율: {kpi.session_cvr_pct:.2f}%")
print(f"재구매율       : {kpi.repurchase_rate_pct:.2f}%")
load("kpi_monthly")"""),

md("## 2. 일별 매출 추이\n데이터가 빠진 날·급증한 날이 있는지, 블랙프라이데이(2019-11-29) 효과가 보이는지 확인합니다."),
code("""daily = load("kpi_daily", parse_dates=["event_date"])
fig, ax = plt.subplots(figsize=(12, 4))
ax.plot(daily.event_date, daily.revenue, lw=1.5)
ax.axvline(pd.Timestamp("2019-11-29"), color="tab:red", ls="--", lw=1)
ax.text(pd.Timestamp("2019-11-29"), ax.get_ylim()[1] * 0.95, " 블랙프라이데이", color="tab:red", va="top")
ax.set(title="일별 매출", xlabel="", ylabel="매출")
save(fig, "01_daily_revenue")"""),

md("## 3. 퍼널: 어디서 가장 많이 이탈하는가?"),
code("""f = load("funnel_session").query("funnel_type == 'loose'").iloc[0]
stages = ["조회", "장바구니", "구매"]
values = [f.view_sessions, f.cart_sessions, f.purchase_sessions]

fig, ax = plt.subplots(figsize=(8, 4))
bars = ax.barh(stages[::-1], values[::-1], color=["#2a9d8f", "#e9c46a", "#264653"][::-1])
for bar, v in zip(bars, values[::-1]):
    ax.text(bar.get_width(), bar.get_y() + bar.get_height() / 2, f" {v:,.0f} ({v / values[0] * 100:.1f}%)", va="center")
ax.set(title="세션 기준 퍼널", xlabel="세션 수")
ax.set_xlim(0, values[0] * 1.25)
save(fig, "02_funnel")

print(f"조회→장바구니: {f.view_to_cart_pct}%   장바구니→구매: {f.cart_to_purchase_pct}%")
load("funnel_product_level")"""),

md("## 4. 가격대·브랜드별 장바구니 → 구매 전환율"),
code("""pb = load("conv_by_price_band")
fig, ax = plt.subplots(figsize=(8, 4))
sns.barplot(data=pb, x="price_band", y="cart_to_purchase_pct", color="#2a9d8f", ax=ax)
ax.axhline(np.average(pb.cart_to_purchase_pct, weights=pb.carted_items), color="gray", ls="--", label="전체 평균")
ax.set(title="가격대별 장바구니→구매 전환율", xlabel="가격대", ylabel="전환율(%)")
ax.legend()
save(fig, "03_conv_by_price_band")
pb"""),
code("""br = load("conv_by_brand").sort_values("cart_to_purchase_pct")
fig, ax = plt.subplots(figsize=(8, max(4, len(br) * 0.3)))
sns.barplot(data=br, y="brand", x="cart_to_purchase_pct", color="#e76f51", ax=ax)
ax.set(title="브랜드별 장바구니→구매 전환율 (장바구니 표본이 충분한 브랜드)", xlabel="전환율(%)", ylabel="")
save(fig, "04_conv_by_brand")"""),

md("### 가설 2 보강: 장바구니 총액이 작을수록 구매 전환율이 낮은가?"),
code("""bv = load("h2_basket_value_conversion")
fig, ax = plt.subplots(figsize=(8, 4))
sns.barplot(data=bv, x="basket_band", y="cvr_pct", color="#264653", ax=ax)
for i, v in enumerate(bv.cvr_pct):
    ax.text(i, v, f"{v:.1f}%", ha="center", va="bottom")
ax.set(title="장바구니 총액 구간별 세션 구매 전환율", xlabel="장바구니 총액", ylabel="구매 전환율(%)")
save(fig, "08_conv_by_basket_value")
bv"""),

md("## 가설 3: 장바구니 이탈 고객은 며칠 안에 돌아오는가?"),
code("""rr = load("h3_return_rate")
fig, ax = plt.subplots(figsize=(8, 4))
ax.plot(rr.n_days, rr.return_pct, marker="o", label="복귀율 (다시 방문)")
ax.plot(rr.n_days, rr.recovered_purchase_pct, marker="o", label="회수 구매율 (다시 구매)")
for x, y in zip(rr.n_days, rr.return_pct):
    ax.text(x, y + 1.5, f"{y:.1f}%", ha="center")
ax.axhline(30, color="gray", ls="--", lw=1, label="채택 기준 (7일 내 복귀율 30%)")
ax.set_xticks(rr.n_days)
ax.set(title="장바구니 이탈 후 N일 안에 돌아온 고객 비율", xlabel="이탈 후 경과 일수", ylabel="%")
ax.legend()
save(fig, "09_cart_return_rate")
display(load("h3_days_to_return"))
load("h3_return_by_basket")"""),

md("## 5. (보조) 코호트 리텐션: 첫 구매 고객이 다시 사는가?"),
code("""ch = load("cohort_retention")
ch["cohort"] = pd.to_datetime(ch.cohort).dt.strftime("%Y-%m")
pivot = ch.pivot(index="cohort", columns="month_n", values="retention_pct")
fig, ax = plt.subplots(figsize=(8, 4))
sns.heatmap(pivot, annot=True, fmt=".1f", cmap="Blues", cbar_kws={"label": "재구매 고객 비율(%)"}, ax=ax)
ax.set(title="첫 구매월 코호트별 재구매율", xlabel="첫 구매 후 경과 개월", ylabel="첫 구매월")
save(fig, "05_cohort_heatmap")
load("repurchase_gap")"""),

md("## 6. 요일 × 시간대별 구매 전환율 (UTC 기준)"),
code("""hd = load("sessions_by_hour_dow")
dow_names = {1: "월", 2: "화", 3: "수", 4: "목", 5: "금", 6: "토", 7: "일"}
hd["요일"] = hd.dow.map(dow_names)
fig, axes = plt.subplots(2, 1, figsize=(14, 7))
for ax, col, title, cmap in [(axes[0], "sessions", "세션 수", "Greens"), (axes[1], "cvr_pct", "구매 전환율(%)", "Oranges")]:
    p = hd.pivot(index="요일", columns="hour_utc", values=col).reindex(list(dow_names.values()))
    sns.heatmap(p, cmap=cmap, ax=ax, cbar_kws={"label": title})
    ax.set(title=f"요일 × 시간대 {title} (UTC)", xlabel="시간(UTC)", ylabel="")
fig.tight_layout()
save(fig, "06_hour_dow_heatmap")"""),

md("""## 7. 통계 검정: 차이가 우연이 아닌가?

**가설 1.** 주말과 평일의 세션 구매 전환율은 다르다.
- 귀무가설(H0): 요일 유형과 구매 여부는 독립이다 (전환율 차이 없음)
- 유의수준 0.05

데이터가 수백만 세션이라 아주 작은 차이도 p < 0.05가 나옵니다. 그래서 **p-value와 함께 차이의 크기(%p)와 효과 크기(Cramér's V)도 함께** 보고하세요."""),
code("""def chi2_report(table, labels, title):
    chi2, p, dof, _ = chi2_contingency(table)
    n = table.sum()
    cramers_v = np.sqrt(chi2 / (n * (min(table.shape) - 1)))
    rates = table[:, 0] / table.sum(axis=1) * 100
    print(f"[{title}]")
    for l, r in zip(labels, rates):
        print(f"  {l}: 전환율 {r:.2f}%")
    print(f"  차이 {rates.max() - rates.min():.2f}%p | chi2={chi2:,.1f}, p-value={p:.4g}, Cramér's V={cramers_v:.3f}")
    print("  → 통계적으로 유의한 차이" if p < 0.05 else "  → 유의한 차이 없음")

ww = load("weekend_vs_weekday")
chi2_report(ww[["purchase_sessions", "no_purchase_sessions"]].to_numpy(), ww.day_type.tolist(), "주말 vs 평일 세션 전환율")"""),
md("**가설 2.** 저가 상품(5 미만)은 그 이상 가격대보다 장바구니→구매 전환율이 낮다."),
code("""pb["group"] = np.where(pb.price_band.isin(["1) ~2", "2) 2~5"]), "저가(<5)", "중고가(5+)")
g = pb.groupby("group")[["purchased_items", "carted_items"]].sum()
g["not_purchased"] = g.carted_items - g.purchased_items
chi2_report(g[["purchased_items", "not_purchased"]].to_numpy(), g.index.tolist(), "가격대별 장바구니→구매 전환율")"""),

md("## 8. RFM 세그먼트: 누가 매출을 만드는가?"),
code("""rfm = load("rfm_segment_summary")
fig, ax = plt.subplots(figsize=(9, 4))
x = np.arange(len(rfm))
ax.bar(x - 0.2, rfm.customer_pct, 0.4, label="고객 비중(%)", color="#8ecae6")
ax.bar(x + 0.2, rfm.revenue_pct, 0.4, label="매출 비중(%)", color="#023047")
ax.set_xticks(x, rfm.segment, rotation=20)
ax.set(title="RFM 세그먼트별 고객 비중 vs 매출 비중", ylabel="%")
ax.legend()
save(fig, "07_rfm_segments")
rfm"""),

md("""## 9. 기대효과 추정 (7단계 인사이트용)

예시: "저가 상품의 장바구니→구매 전환율을 중고가 수준의 절반만큼 끌어올리면 매출이 얼마나 늘까?"
가정은 바꿔 가며 보수적으로 잡고, README에 **가정을 그대로 적으세요.**"""),
code("""low = pb[pb.group == "저가(<5)"]
low_rate = low.purchased_items.sum() / low.carted_items.sum()
high_rate = g.loc["중고가(5+)", "purchased_items"] / g.loc["중고가(5+)", "carted_items"]
target_rate = low_rate + (high_rate - low_rate) * 0.5          # 가정: 격차의 50%를 줄인다

avg_low_price = 3.0      # 가정: 저가 상품 평균 가격. events 테이블에서 실제 값을 구해 바꾸세요
extra_items = low.carted_items.sum() * (target_rate - low_rate)
extra_revenue = extra_items * avg_low_price
print(f"저가 전환율 {low_rate:.1%} → 목표 {target_rate:.1%}")
print(f"추가 구매 상품 약 {extra_items:,.0f}개, 추가 매출 약 {extra_revenue:,.0f} "
      f"(전체 매출의 {extra_revenue / kpi.revenue:.1%}, 5개월 기준)")"""),

md("""## 10. 인사이트 정리 메모

분석 결과마다 아래 형식으로 적어 두었다가 README의 "핵심 인사이트와 제안"에 옮기세요.

| 발견 | 해석 | 제안 | 기대효과 |
|---|---|---|---|
| (예) 저가 상품 장바구니→구매 전환율이 중고가보다 ○%p 낮음 (p<0.05) | 소액 상품은 배송비 부담으로 구매를 미루는 것으로 추정 | 무료배송 기준 근처에서 "○원 더 담으면 무료배송" 추천 | 격차 50% 해소 시 매출 약 ○% 증가 |
|  |  |  |  |
|  |  |  |  |"""),
]

nb.metadata["kernelspec"] = {"name": "python3", "display_name": "Python 3", "language": "python"}
(ROOT / "notebooks").mkdir(exist_ok=True)
nbf.write(nb, ROOT / "notebooks" / "analysis.ipynb")
print("notebooks/analysis.ipynb 생성 완료")
