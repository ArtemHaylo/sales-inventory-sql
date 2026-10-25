"""Build README charts from the CSV query results in results/."""
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

ROOT = os.path.dirname(os.path.abspath(__file__))
R = lambda n: pd.read_csv(os.path.join(ROOT, "results", f"q{n:02d}.csv"))
IMG = os.path.join(ROOT, "images")
os.makedirs(IMG, exist_ok=True)
BLUE, ORANGE, GREY = "#2F6DB5", "#E08A2E", "#9AA5B1"
plt.rcParams.update({"axes.spines.top": False, "axes.spines.right": False, "font.size": 10})

# 1. monthly revenue
m = R(2)
m["month"] = pd.to_datetime(m["month"])
fig, ax = plt.subplots(figsize=(10, 4.5))
ax.bar(m["month"], m["revenue"], width=20, color=BLUE, alpha=0.85, label="Monthly revenue")
ax.plot(m["month"], m["moving_avg_3m"], color=ORANGE, lw=2.5, label="3-month moving average")
peak = m.loc[m["revenue"].idxmax()]
ax.annotate(f"Holiday peak\n{peak['revenue']/1000:.0f}k", (peak["month"], peak["revenue"]),
            xytext=(-150, -25), textcoords="offset points", arrowprops=dict(arrowstyle="->", color="black"))
ax.set_title("Monthly revenue, Jan 2025 – Jun 2026", loc="left", fontweight="bold")
ax.set_ylabel("Revenue")
ax.yaxis.set_major_formatter(lambda v, _: f"{v/1000:.0f}k")
ax.legend(frameon=False)
fig.tight_layout()
fig.savefig(os.path.join(IMG, "monthly_revenue.png"), dpi=130)

# 2. revenue share vs profit share by category
c = R(3)[["category", "revenue_share_pct"]].merge(R(4)[["category", "profit_share_pct", "gross_margin_pct"]])
c = c.sort_values("revenue_share_pct")
fig, ax = plt.subplots(figsize=(9, 4.5))
y = range(len(c))
ax.barh([i + 0.2 for i in y], c["revenue_share_pct"], height=0.4, color=GREY, label="Share of revenue, %")
ax.barh([i - 0.2 for i in y], c["profit_share_pct"], height=0.4, color=BLUE, label="Share of gross profit, %")
for i, (_, r) in enumerate(c.iterrows()):
    ax.text(max(r["revenue_share_pct"], r["profit_share_pct"]) + 0.6, i, f"margin {r['gross_margin_pct']:.0f}%",
            va="center", fontsize=9, color="#333")
ax.set_yticks(list(y))
ax.set_yticklabels(c["category"])
ax.set_xlim(0, 42)
ax.set_title("Electronics brings the most revenue, but Clothing brings the most profit", loc="left", fontweight="bold")
ax.legend(frameon=False, loc="lower right")
fig.tight_layout()
fig.savefig(os.path.join(IMG, "category_revenue_vs_profit.png"), dpi=130)

# 3. RFM segments
s = R(9)
s["segment"] = s["segment"].str.replace(r"^\d\. ", "", regex=True)
s = s.iloc[::-1]
fig, ax = plt.subplots(figsize=(9, 4.5))
y = range(len(s))
ax.barh([i + 0.2 for i in y], s["customers_pct"], height=0.4, color=GREY, label="Share of customers, %")
ax.barh([i - 0.2 for i in y], s["revenue_pct"], height=0.4, color=BLUE, label="Share of revenue, %")
ax.set_yticks(list(y))
ax.set_yticklabels(s["segment"])
ax.set_title("RFM: 13% of customers (Champions) bring 42% of revenue", loc="left", fontweight="bold")
ax.legend(frameon=False, loc="lower right")
fig.tight_layout()
fig.savefig(os.path.join(IMG, "rfm_segments.png"), dpi=130)

# 4. cohort retention heatmap
h = R(8)
h["cohort"] = pd.to_datetime(h["cohort"]).dt.strftime("%b %Y")
vals = h[["m1_pct", "m2_pct", "m3_pct", "m6_pct"]].values
fig, ax = plt.subplots(figsize=(6.5, 6))
im = ax.imshow(vals, cmap="Blues", aspect="auto", vmin=0, vmax=30)
ax.set_xticks(range(4))
ax.set_xticklabels(["Month 1", "Month 2", "Month 3", "Month 6"])
ax.set_yticks(range(len(h)))
ax.set_yticklabels([f"{c} (n={n})" for c, n in zip(h["cohort"], h["cohort_size"])])
for i in range(vals.shape[0]):
    for j in range(vals.shape[1]):
        ax.text(j, i, f"{vals[i, j]:.0f}%", ha="center", va="center", fontsize=8,
                color="white" if vals[i, j] > 20 else "black")
ax.set_title("Share of each cohort that ordered again", loc="left", fontweight="bold")
fig.tight_layout()
fig.savefig(os.path.join(IMG, "cohort_retention.png"), dpi=130)
print("charts saved")
