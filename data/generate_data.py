"""
Generate a synthetic but realistic dataset for the ABC Corporation database.

Period: 2025-01-01 .. 2026-06-30. Output: CSV files in data/csv/.
The generator models a few real-world behaviours on purpose, so the
analysis has something to find:
  * customer segments with different repeat-purchase habits (and churn);
  * seasonality (holiday peak in Nov–Dec, slow January–February);
  * different price levels and supplier margins by category;
  * different refund rates by category;
  * a few products whose restocking stopped near the end of the period.

Run:  python data/generate_data.py
"""
import csv
import os
from datetime import date, datetime, timedelta

import numpy as np

rng = np.random.default_rng(2025)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "csv")
os.makedirs(OUT, exist_ok=True)

START, END = date(2025, 1, 1), date(2026, 6, 30)
N_DAYS = (END - START).days + 1
SEASON = {1: 0.75, 2: 0.8, 3: 0.95, 4: 1.0, 5: 1.0, 6: 0.95, 7: 0.9,
          8: 0.95, 9: 1.05, 10: 1.1, 11: 1.45, 12: 1.65}


def write(name, header, rows):
    with open(os.path.join(OUT, f"{name}.csv"), "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(header)
        w.writerows(rows)


# ---------------------------------------------------------------- people
FIRST = ["Olena", "Andrii", "Iryna", "Dmytro", "Kateryna", "Oleksandr", "Mariia", "Serhii", "Yuliia",
         "Maksym", "Anna", "Vladyslav", "Sofiia", "Bohdan", "Viktoriia", "Taras", "Daryna", "Artem",
         "Nataliia", "Ihor", "Oksana", "Roman", "Tetiana", "Yevhen", "Alina", "Denys", "Khrystyna",
         "Mykola", "Valeriia", "Pavlo"]
LAST = ["Kovalenko", "Shevchenko", "Bondarenko", "Tkachenko", "Kravchenko", "Melnyk", "Boiko", "Koval",
        "Oliinyk", "Lysenko", "Moroz", "Marchenko", "Savchenko", "Rudenko", "Pavlenko", "Klymenko",
        "Petrenko", "Ponomarenko", "Kuzmenko", "Levchenko", "Hrytsenko", "Sydorenko", "Zinchenko",
        "Fedorenko", "Tkachuk", "Kovalchuk", "Polishchuk", "Lytvynenko", "Romanenko", "Bilyk"]
CITIES = ["Kyiv", "Lviv", "Odesa", "Kharkiv", "Dnipro", "Vinnytsia", "Poltava", "Zhytomyr", "Rivne", "Chernihiv"]
used_phones = set()


def phone():
    while True:
        p = "+380" + str(rng.integers(50, 99)) + str(rng.integers(1_000_000, 9_999_999))
        if p not in used_phones:
            used_phones.add(p)
            return p


def name_email(i, domain):
    f, l = rng.choice(FIRST), rng.choice(LAST)
    return f"{f} {l}", f"{f.lower()}.{l.lower()}{i}@{domain}"


# employees: sales managers in two departments
employees = []
for i in range(1, 13):
    full, email = name_email(i, "abc-corp.com")
    dept = "Online Sales" if i <= 7 else "Retail Sales"
    pos = "Senior Sales Manager" if i in (1, 8) else "Sales Manager"
    employees.append((i, full, pos, email, phone(), dept))
write("employees", ["employee_id", "full_name", "position", "email", "phone", "department"], employees)
emp_weights = rng.dirichlet(np.ones(12) * 3)

# suppliers
SUPPLIERS = ["TechSource Ltd", "HomeLine Distribution", "UrbanWear Supply", "ActiveGear Trading",
             "PageTurner Books", "GlowCare Cosmetics", "Global Goods Import", "EastBridge Logistics"]
suppliers = [(i + 1, n, f"sales@{n.split()[0].lower()}.com", phone(), f"{rng.choice(CITIES)}, Ukraine")
             for i, n in enumerate(SUPPLIERS)]
write("suppliers", ["supplier_id", "name", "email", "phone", "address"], suppliers)

# ---------------------------------------------------------------- products
CATS = {
    #               items, price range, unit-cost share of price, refund rate, main supplier, popularity
    "Electronics":   (["Wireless Earbuds", "Smartwatch", "Bluetooth Speaker", "Power Bank 20000mAh", "Mechanical Keyboard",
                       "Gaming Mouse", "27\" Monitor", "USB-C Hub", "Action Camera", "E-Reader"],
                      (25, 420), 0.80, 0.055, 1, 1.0),
    "Home & Kitchen": (["Coffee Grinder", "Air Fryer", "Knife Set", "Bed Linen Set", "Desk Lamp", "Electric Kettle",
                        "Storage Boxes (3 pcs)", "Cast Iron Pan", "Blender", "Scented Candle Set"],
                       (12, 160), 0.55, 0.03, 2, 1.1),
    "Clothing":      (["Hoodie", "Denim Jacket", "Running T-shirt", "Wool Sweater", "Chino Pants", "Winter Parka",
                       "Sneakers", "Baseball Cap", "Leather Belt", "Rain Jacket"],
                      (12, 140), 0.45, 0.095, 3, 1.2),
    "Sports":        (["Yoga Mat", "Dumbbell Set", "Resistance Bands", "Cycling Gloves", "Water Bottle", "Tennis Racket",
                       "Foam Roller", "Jump Rope", "Hiking Backpack", "Fitness Tracker Strap"],
                      (8, 130), 0.55, 0.035, 4, 0.8),
    "Books":         (["Data Science Handbook", "SQL Pocket Guide", "Mystery Novel", "Cookbook", "History of Kyiv",
                       "Productivity Guide", "Kids Picture Book", "Sci-Fi Trilogy", "Language Course Book", "Art Album"],
                      (8, 45), 0.65, 0.015, 5, 0.9),
    "Beauty":        (["Face Serum", "Hand Cream", "Shampoo & Conditioner", "Perfume 50ml", "Lip Balm Set",
                       "Hair Dryer", "Sunscreen SPF50", "Body Lotion", "Makeup Brush Set", "Beard Care Kit"],
                      (6, 90), 0.40, 0.025, 6, 1.0),
}
products, prod_meta = [], {}
pid = 0
for cat, (items, (lo, hi), cost_share, refund, sup, pop) in CATS.items():
    for item in items:
        pid += 1
        # log-uniform price, rounded to .99
        price = round(float(np.exp(rng.uniform(np.log(lo), np.log(hi)))), 0) - 0.01
        price = max(price, lo - 0.01)
        products.append((pid, item, cat, f"{item} — {cat.lower()} range", f"{price:.2f}"))
        # cheaper items sell more often
        weight = pop * (hi / price) ** 0.45 * rng.uniform(0.6, 1.4)
        prod_meta[pid] = dict(cat=cat, price=price, cost_share=cost_share * rng.uniform(0.93, 1.07),
                              refund=refund, supplier=sup, weight=weight)
write("products", ["product_id", "name", "category", "description", "price"], products)
pids = np.array(list(prod_meta))
pweights = np.array([prod_meta[p]["weight"] for p in pids])
pweights /= pweights.sum()

# ---------------------------------------------------------------- clients & orders
# segment: (share, mean days between orders, probability to churn after each order)
SEGMENTS = {"loyal": (0.15, 28, 0.06), "regular": (0.35, 70, 0.25), "one_off": (0.50, 120, 0.75)}
N_CLIENTS = 2600
day_probs = np.array([SEASON[(START + timedelta(int(d))).month] for d in range(N_DAYS)])
day_probs /= day_probs.sum()

clients, orders, items, transactions = [], [], [], []
order_id = 0
for cid in range(1, N_CLIENTS + 1):
    full, email = name_email(cid, rng.choice(["gmail.com", "ukr.net", "outlook.com", "i.ua"]))
    clients.append((cid, full, email, phone(), f"{rng.choice(CITIES)}, Ukraine"))
    seg = rng.choice(list(SEGMENTS), p=[s[0] for s in SEGMENTS.values()])
    _, gap, churn = SEGMENTS[seg]
    d = START + timedelta(int(rng.choice(N_DAYS, p=day_probs)))
    while d <= END:
        order_id += 1
        ts = datetime(d.year, d.month, d.day, int(rng.integers(8, 23)), int(rng.integers(0, 60)))
        n_lines = int(rng.choice([1, 2, 3, 4], p=[0.55, 0.28, 0.12, 0.05]))
        chosen = rng.choice(pids, size=n_lines, replace=False, p=pweights)
        total = 0.0
        for p in chosen:
            q = int(rng.choice([1, 2, 3], p=[0.78, 0.17, 0.05]))
            items.append((order_id, int(p), q, d))
            total += q * prod_meta[int(p)]["price"]
            if rng.random() < prod_meta[int(p)]["refund"]:
                rd = ts + timedelta(days=int(rng.integers(3, 20)))
                if rd.date() <= END:
                    transactions.append([None, rd.isoformat(), round(q * prod_meta[int(p)]["price"], 2), "refund", order_id])
        emp = int(rng.choice(np.arange(1, 13), p=emp_weights))
        orders.append((order_id, ts.isoformat(), f"{total:.2f}", cid, emp))
        transactions.append([None, (ts + timedelta(minutes=int(rng.integers(1, 30)))).isoformat(),
                             round(total, 2), "payment", order_id])
        if rng.random() < churn:
            break
        # holidays make people buy again sooner
        g = rng.exponential(gap) / SEASON[d.month]
        d = d + timedelta(days=max(3, int(g)))

transactions.sort(key=lambda t: t[1])
for i, t in enumerate(transactions, 1):
    t[0] = i
write("clients", ["client_id", "full_name", "email", "phone", "address"], clients)
write("orders", ["order_id", "order_date", "total_amount", "client_id", "employee_id"], orders)
write("order_items", ["order_id", "product_id", "quantity"], [(o, p, q) for o, p, q, _ in items])
write("transactions", ["transaction_id", "transaction_date", "amount", "type", "order_id"], transactions)

# ---------------------------------------------------------------- deliveries
# restock every ~6 weeks with ~1.05x the demand of the next period;
# 4 products get their last delivery more than two months before the end (stock-out risk)
demand = {p: np.zeros(N_DAYS + 60) for p in prod_meta}
for _, p, q, d in items:
    demand[p][(d - START).days] += q
stopped = set(rng.choice(pids, size=4, replace=False).tolist())
deliveries = []
for p, meta in prod_meta.items():
    d = START - timedelta(days=14)
    stock = 0  # units left over from previous deliveries
    while d <= END:
        nxt = d + timedelta(days=int(rng.integers(35, 50)))
        last = p in stopped and nxt >= END - timedelta(days=60)
        if last:
            # final delivery covers demand to the end of the period almost exactly -> near-zero stock
            nxt = END + timedelta(days=1)
        a, b = max(0, (d - START).days), max(0, (nxt - START).days)
        need = demand[p][a:b].sum()
        if last:
            qty = int(need - stock) + int(rng.integers(0, 3))
        else:
            qty = int(np.ceil(need * rng.uniform(1.0, 1.15))) + int(rng.integers(0, 3))
        stock += qty - need
        if qty <= 0:
            d = nxt
            continue
        sup = meta["supplier"] if rng.random() < 0.8 else int(rng.choice([7, 8]))
        unit_cost = meta["price"] * meta["cost_share"]
        deliveries.append((sup, p, d.isoformat(), qty, f"{qty * unit_cost:.2f}"))
        d = nxt
write("deliveries", ["supplier_id", "product_id", "delivery_date", "quantity", "cost"], deliveries)

print(f"clients={len(clients)} orders={len(orders)} order_items={len(items)} "
      f"transactions={len(transactions)} deliveries={len(deliveries)} products={len(products)}")
print("products without restocking in the last 60 days:", sorted(stopped))
