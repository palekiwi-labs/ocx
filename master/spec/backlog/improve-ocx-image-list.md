Improve the output of `ocx image list` and support `--json`

- Images appear twice (latest + version)
- images are not grouped logically (base with final)
- hard to gauge how many images there are and if need pruning or manual deletion
```
ocx image list
╭────┬──────────────────────────────────────┬────────┬──────────────┬───────────────────────────────┬───────╮
│  # │              repository              │  tag   │     hash     │            created            │ size  │
├────┼──────────────────────────────────────┼────────┼──────────────┼───────────────────────────────┼───────┤
│  0 │ localhost/ocx-terraform              │ 1.1.50 │ 92133799408d │ 2026-02-04 11:24:11 +0800 CST │ 446MB │
│  1 │ localhost/ocx-terraform              │ latest │ 92133799408d │ 2026-02-04 11:24:11 +0800 CST │ 446MB │
│  2 │ localhost/ocx                        │ latest │ de19e5a876ee │ 2026-02-03 18:27:07 +0800 CST │ 337MB │
│  3 │ localhost/ocx-nushell                │ latest │ 5e02aa6e655b │ 2026-02-03 12:14:12 +0800 CST │ 548MB │
│  4 │ localhost/ocx-base-terraform         │ latest │ e5cb38d2633e │ 2026-02-02 20:29:12 +0800 CST │ 297MB │
│  5 │ localhost/ocx-base-nushell           │ latest │ bccc6d8f8a21 │ 2026-01-21 12:27:06 +0800 CST │ 400MB │
│  6 │ localhost/ocx-base-spabreaks         │ latest │ a23b4e7bfb19 │ 1980-01-01 08:00:00 +0800 CST │ 717MB │
│  7 │ localhost/ocx-base-voucher-portal    │ latest │ 7fa59c84b185 │ 1980-01-01 08:00:00 +0800 CST │ 650MB │
│  8 │ localhost/ocx-my-account             │ 1.1.50 │ 98a6fb07fc18 │ 1980-01-01 08:00:00 +0800 CST │ 847MB │
│  9 │ localhost/ocx-my-account             │ latest │ 98a6fb07fc18 │ 1980-01-01 08:00:00 +0800 CST │ 847MB │
│ 10 │ localhost/ocx-base-ocx               │ latest │ 00daf6b4f2ce │ 1980-01-01 08:00:00 +0800 CST │ 420MB │
│ 11 │ localhost/ocx-ocx                    │ 1.1.50 │ 3939e9930c58 │ 1980-01-01 08:00:00 +0800 CST │ 569MB │
│ 12 │ localhost/ocx-ocx                    │ latest │ 3939e9930c58 │ 1980-01-01 08:00:00 +0800 CST │ 569MB │
│ 13 │ localhost/ocx-ruby                   │ latest │ 13239b860b1b │ 1980-01-01 08:00:00 +0800 CST │ 776MB │
│ 14 │ localhost/ocx-booking-transform      │ latest │ 99cafef3fe4e │ 1980-01-01 08:00:00 +0800 CST │ 760MB │
│ 15 │ localhost/ocx-spabreaks              │ 1.1.50 │ 599ac01dda4b │ 1980-01-01 08:00:00 +0800 CST │ 866MB │
│ 16 │ localhost/ocx-spabreaks              │ latest │ 599ac01dda4b │ 1980-01-01 08:00:00 +0800 CST │ 866MB │
│ 17 │ localhost/ocx-base                   │ latest │ 0c28a9f5e32e │ 1980-01-01 08:00:00 +0800 CST │ 188MB │
│ 18 │ localhost/ocx-base-my-account        │ latest │ c5cd5582c1af │ 1980-01-01 08:00:00 +0800 CST │ 698MB │
│ 19 │ localhost/ocx-base-ruby              │ latest │ 742e711665e2 │ 1980-01-01 08:00:00 +0800 CST │ 605MB │
│ 20 │ localhost/ocx-voucher-portal         │ latest │ 8db513cd0549 │ 1980-01-01 08:00:00 +0800 CST │ 799MB │
│ 21 │ localhost/ocx-base-booking-transform │ latest │ 8263f2b428b2 │ 1980-01-01 08:00:00 +0800 CST │ 612MB │
╰────┴──────────────────────────────────────┴────────┴──────────────┴───────────────────────────────┴───────╯
```
