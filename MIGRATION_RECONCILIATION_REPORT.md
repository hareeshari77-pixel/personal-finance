# Excel migration and reconciliation report

- Source: `Income ^L0 Expense Tracker - 2026.xlsx` (credentials sheet intentionally excluded)
- Historical ledger: **2,678 rows**, 2025-01-01 opening snapshot through **2026-08-15**.
- Transfer links: **89 deterministic two-sided pairs**; **2** ambiguous candidates left unlinked rather than guessed.
- Reconciliation status: **MATCHED**.

## Reconciliation checks

| Group | Account / position | Excel | App model | Difference | Status |
|---|---|---:|---:|---:|---|
| Account | AXIS | 335,067.54 | 335,067.54 | 0.00 | MATCH |
| Account | HDFC | 5,852.44 | 5,852.44 | 0.00 | MATCH |
| Account | SBI | 6,429.19 | 6,429.19 | 0.00 | MATCH |
| Account | CASH | 1,965.00 | 1,965.00 | 0.00 | MATCH |
| Account | AXIS CC | -250,026.72 | -250,026.72 | 0.00 | MATCH |
| Account | SBI CC | -1,076.09 | -1,076.09 | 0.00 | MATCH |
| Account | HDFC CC | -4.25 | -4.25 | 0.00 | MATCH |
| Account | RBICC | -18,328.54 | -18,328.54 | 0.00 | MATCH |
| Investment | Chit Fund (RRP-1st) | -5,500.00 | -5,500.00 | 0.00 | MATCH |
| Investment | Chit Fund (RRP-10th) | -9,450.00 | -9,450.00 | 0.00 | MATCH |
| Investment | Chit Fund (PPL) | -12,000.00 | -12,000.00 | 0.00 | MATCH |
| Investment | Chit Fund (Ongole) | 315,000.00 | 315,000.00 | 0.00 | MATCH |
| Investment | Chit Fund (Prasanna) | -17,000.00 | -17,000.00 | 0.00 | MATCH |
| Investment | Chit Fund (Jyoshna) | 9,000.00 | 9,000.00 | 0.00 | MATCH |
| Investment | Chit Fund (Jyoshna1) | 9,000.00 | 9,000.00 | 0.00 | MATCH |
| Investment | Chit Fund (Gowthami) | 88,000.00 | 88,000.00 | 0.00 | MATCH |
| Investment | Chit Fund (Ndg) | 25,000.00 | 25,000.00 | 0.00 | MATCH |
| Investment | RD | 140,000.00 | 140,000.00 | 0.00 | MATCH |
| Investment | FD | 314,887.00 | 314,887.00 | 0.00 | MATCH |
| Investment | SIP-Dhan | 357,000.00 | 357,000.00 | 0.00 | MATCH |
| Investment | SIP-Kite | 202,766.00 | 202,766.00 | 0.00 | MATCH |
| Investment | Stocks | 770,079.71 | 770,079.71 | 0.00 | MATCH |
| Investment | MutualFund | 125,000.00 | 125,000.00 | 0.00 | MATCH |
| Investment | ETFs | 176,514.28 | 176,514.28 | 0.00 | MATCH |
| Receivable | Sai Kiran | 20,000.00 | 20,000.00 | 0.00 | MATCH |
| Receivable | Jagadeesh | -11.87 | -11.87 | 0.00 | MATCH |
| Receivable | Sathish Nelakurthi | 49,998.00 | 49,998.00 | 0.00 | MATCH |
| Receivable | Sailaja | 8,538.00 | 8,538.00 | 0.00 | MATCH |
| Receivable | Jyoshna | 13,999.00 | 13,999.00 | 0.00 | MATCH |
| Receivable | Nanna | 0.00 | 0.00 | 0.00 | MATCH |
| Receivable | Annayya | 349,973.82 | 349,973.82 | 0.00 | MATCH |
| Receivable | Nani | 14,586.08 | 14,586.08 | 0.00 | MATCH |
| Receivable | Ashok Y | 10,000.00 | 10,000.00 | 0.00 | MATCH |
| Receivable | Anusha Y | 49,427.33 | 49,427.33 | 0.00 | MATCH |
| Receivable | Lakshman | 0.00 | 0.00 | 0.00 | MATCH |
| Receivable | Sai Jagadeesh | 81,350.94 | 81,350.94 | 0.00 | MATCH |
| Receivable | Manoj | 3,122.00 | 3,122.00 | 0.00 | MATCH |
| Receivable | Munna | 2,000.00 | 2,000.00 | 0.00 | MATCH |
| Receivable | Raghu | -1.00 | -1.00 | 0.00 | MATCH |
| Receivable | Sai Krishna | 0.00 | 0.00 | 0.00 | MATCH |
| Receivable | Alekhya | 0.00 | 0.00 | 0.00 | MATCH |
| Receivable | Venkaiah Mamayya | 837,141.00 | 837,141.00 | 0.00 | MATCH |
| Receivable | Dhanalakshmi | 100,000.00 | 100,000.00 | 0.00 | MATCH |
| Receivable | Mamayya Frnd | 100,000.00 | 100,000.00 | 0.00 | MATCH |
| Receivable | Mamayya Frnd | 100,000.00 | 100,000.00 | 0.00 | MATCH |
| Receivable | Satyavati amma | 0.00 | 0.00 | 0.00 | MATCH |
| Receivable | Alekhya | 63,000.00 | 63,000.00 | 0.00 | MATCH |
| Receivable | Nani | 20,000.00 | 20,000.00 | 0.00 | MATCH |

## Unlinked transfer candidates

These entries remain preserved as separate source rows. They need user confirmation before the app treats them as a single linked transfer.

- 2026-06-05 — ₹5,763.00: excel-2336, excel-2338, excel-2343
- 2026-06-05 — ₹5,763.00: excel-2342, excel-2338, excel-2343
