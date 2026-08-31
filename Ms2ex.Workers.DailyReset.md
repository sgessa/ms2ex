# `Ms2ex.Workers.DailyReset`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/workers/daily_reset.ex#L1)

Runs at midnight (Oban crontab) to reset each character's daily meso
instant-revive allowance. The counter is stored on the character row so it
survives restarts; only the day roll-over (this job) clears it. Connected
players are told immediately so their in-memory counter and the client's
"uses left" gauge reset too.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
