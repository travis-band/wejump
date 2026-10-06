# Appendix: Free-tier usage limits (Render + Neon)

> Checked in October 2026. Free plans change often, so check the source links at the bottom before relying on these numbers.

Both free plans give you a **monthly allowance of "time switched on"**. It goes down only while a server is awake. Sleeping doesn't use it. The allowance refills every month.

## Render (the app server)

| Item | Free plan |
|---|---|
| Monthly allowance | 750 instance hours per workspace |
| Used when | Only while the app is awake |
| Goes to sleep | After 15 minutes with no visitors. Waking up takes about a minute |
| If it runs out | All free web services stop until the start of next month |

A month has 720 to 744 hours, so **one service can stay awake 24 hours a day and still fit in 750 hours**. With a single free service, as in this repo, you don't need to worry about Render's limit. If you create a second free service in the same workspace, the two share the 750 hours.

## Neon (the database)

| Item | Free plan |
|---|---|
| Monthly allowance | 100 CU-hours of compute per project |
| Used when | While the database is awake: hours awake × database size |
| Goes to sleep | After 5 minutes with no activity. Can't be changed on the free plan |
| Waking up | A few hundred milliseconds |
| Storage | 1 GB per project |
| If compute runs out | The database stops until the next month (or until you upgrade) |
| If storage fills up | Writes that add data fail until you free space |

**What is a CU-hour?** CU (compute unit) is the size of the database server. Under light load like this app, Neon runs at its smallest size, 0.25 CU. So one hour awake uses 0.25 CU-hours, and **100 CU-hours last 400 hours awake per month**. A whole month is about 730 hours, so keeping Neon awake 24/7 doesn't fit.

When Neon sleeps, only the compute stops. Your data is stored separately and stays safe.

## How the two are linked

While the Render app is awake, Render checks its health every few seconds by calling `/healthz`. Our `/healthz` sends `SELECT 1` to the database, so **while Render is awake, Neon can't fall asleep.**

1. The last visitor leaves.
2. For 15 minutes Render stays awake, and its health checks keep Neon awake.
3. Render goes to sleep, and the health checks stop.
4. 5 minutes later, Neon goes to sleep too.

So Neon's awake time is roughly Render's awake time plus 5 minutes.

Requests from an open browser tab keep both awake too. That's why the page's **Auto-refresh** toggle (top right) is off by default:

- **Off (the default)**: the page loads messages once when it opens, and again after you post. After that, an open tab sends nothing.
- **On**: it refreshes every 10 seconds and shows "Last updated" in your browser's local time. It pauses while the tab is hidden, and after 10 minutes with no clicks, taps, typing, scrolling, or mouse movement. Coming back to the tab, or tapping, resumes it.

## How much will we use?

| Usage | Render (of 750) | Neon (of 100) |
|---|---|---|
| Class 3 times a week, 1 hour each | About 16 hours | About 4 CU-hours |
| A tab left open, with Auto-refresh off, or on but untouched | Nothing extra: the tab stops sending requests | Nothing extra |
| Something outside the page requests the site all day, every day (an uptime monitor, for example) | About 744 hours, fits | Runs out around day 17 |

The class numbers: each session keeps Render awake about 1 hour 15 minutes and Neon about 1 hour 20 minutes, about 13 sessions a month.

**Used only during class, both are very generous.** A forgotten open tab no longer uses anything, thanks to Auto-refresh being off by default and pausing on its own. The remaining risk is something outside the page requesting the site around the clock. Neon would run out first.

## What happens if Neon runs out

- The app can't read or write messages.
- `/healthz` starts returning 503. When health checks keep failing, Render stops sending traffic to the app, so **the whole site stops working**, not just the messages.
- It comes back when Neon's allowance refills next month, or when you upgrade the Neon plan.

## How to avoid it

- Leave Auto-refresh off unless you need it, for example for the blue/green demo.
- Don't point an uptime monitor or "keep-alive" pinger at the site. It stops both services from ever sleeping.
- Check usage now and then: the usage page in the Neon console shows compute hours used this month, and Render's billing page shows free instance hours.

## Sources

- [Render: Deploy for Free](https://render.com/docs/free)
- [Render: Health Checks](https://render.com/docs/health-checks)
- [Neon: Scale to Zero](https://neon.com/docs/introduction/scale-to-zero)
- [Neon: Free plan limits and quotas](https://neon.com/faqs/free-plan-limits-and-quotas)
