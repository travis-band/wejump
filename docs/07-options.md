# 07. Comparing deployment options, and why we chose this setup

> Prices were checked in September 2026. Cloud prices and free-tier policies change often, so check again before class. See the source links below.

## The abstraction ladder

The further down you go, the less you do yourself, and the less you can see inside.

| Level | Examples | What you manage | What the platform manages |
|---|---|---|---|
| Your own computer | localhost, ngrok | Everything (the computer has to stay on) | Nothing |
| VPS (virtual server) | GCP Compute Engine, AWS Lightsail, DigitalOcean | OS, Docker, proxy, deploy scripts, database | Hardware, network |
| Serverless containers | GCP Cloud Run | Image, traffic split, permissions (IAM) | Servers, scaling, HTTPS |
| PaaS | Render, Railway, Koyeb | Code and one config file | Build, servers, HTTPS, zero-downtime deploys |
| Frontend-focused | Vercel, Firebase Hosting | Code | Almost everything, but only for apps of a set shape |

## Server (app) costs

| Option | Monthly cost | Specs / conditions | Notes |
|---|---|---|---|
| **GCP e2-micro** ✅ Track 1 | **$0** | 2 vCPU (shared), 1GB, 30GB disk, one of 3 US regions | External IP included in the free tier. Card required |
| AWS Lightsail | $5 (0.5GB) / $7 (1GB) | Plans that include IPv4 | Some plans free for the first 3 months. Has a Seoul region |
| DigitalOcean | $4 (0.5GB) / $6 (1GB) | | Simplest UI |
| Hetzner | €5.99 and up | Prices rose in June 2026, low-cost plans temporarily sold out | Mostly Europe |
| Oracle Always Free | $0 | ARM, 2 cores, 12GB (halved in June 2026) | Signups are often rejected and regions often run out of capacity. Needs ARM images |
| GCP Cloud Run | $0 (within the free tier) | 2 million requests, 180,000 vCPU-seconds, 360,000 GiB-seconds per month | Scales to zero with no requests, 1 to 3 seconds to wake up |
| **Render free** ✅ Track 2 | **$0** | 750 hours/month | Sleeps after 15 minutes of no activity, about a minute to wake up. No card needed |
| Railway | $5 | Usage-based, $5 credit for the first 30 days | Doesn't sleep. Hard to keep using for free |
| Koyeb free | $0 | 1 web service, 512MB | The free database gets 5 hours a month, so it isn't practical |

## Database costs

| Option | Monthly cost | Conditions |
|---|---|---|
| **Postgres container on the server** ✅ Track 1 | $0 | Uses the server's disk. You do your own backups |
| **Neon free** ✅ Track 2 | $0 | 1 GB, 100 CU-hours of compute a month, sleeps when unused. See [the free-tier limits appendix](appendix-free-tier-limits.md) |
| Supabase free | $0 | 0.5GB, the project pauses after 7 days with no database activity |
| Render Postgres free | $0 | 1GB, **deleted after 30 days** |
| GCP Cloud SQL | About $8 to $10 | Smallest shared-core instance. Never turns off |

## Domain

| Option | Cost | Notes |
|---|---|---|
| **DuckDNS** ✅ | $0 | `name.duckdns.org`. Can get Let's Encrypt certificates |
| The platform's default address | $0 | `*.onrender.com`, `*.run.app`, and so on |
| Buy a domain | About $10 a year | Cloudflare, Porkbun, and others. For Track 1, just change the domain line in the Caddyfile |

## Why we chose this setup

**The goal is "teaching how deployment works", not "the easiest deploy", so we split it into two tracks.**

- **Track 1 = GCP e2-micro VPS.** The server, processes, ports, proxy, certificate, volumes, and blue/green switch are all visible as files in the repo and commands on the server. It costs $0, and the same files run unchanged on any Linux server.
- **Track 2 = Render + Neon.** The experience of a platform doing what you did yourself in Track 1. $0 with no card, in 15 minutes. It uses the same `Dockerfile` as Track 1, so the comparison "same code, different owner of the infrastructure" holds.

## Options we left out, and why

| Option | Why it was left out | When it's a good choice |
|---|---|---|
| **Vercel** | It runs Python only as serverless functions that run briefly per request, not as a container. It doesn't support a `Dockerfile`, which breaks the rule that both tracks use the same image. It has no database of its own, so you'd end up connecting Neon anyway. | The app is Next.js, or static HTML/JS with a few APIs. Putting a vibe-coded frontend online in 5 minutes |
| **Firebase** | Firebase Hosting serves only static files. The Python API would still have to go on Cloud Run separately, and the database would be Firestore (NoSQL), which doesn't fit a Postgres lesson. Firebase App Hosting focuses on Next.js and Angular, and Python needs your own container plus Terraform. | Static sites, or apps using Firestore and Firebase login |
| **GCP Cloud Run + Cloud SQL** | Each part shows up as a product in the GCP console, which is nice, but the machine, processes, and ports are hidden. Cloud SQL is a fixed $8 to $10 a month. Authenticating from GitHub to GCP (service accounts, Workload Identity) is hard for middle and high school students. | An advanced lesson after Track 1. The per-revision traffic slider (10% → 50% → 100%) is excellent for showing canary deploys |
| **GCP Cloud Run + Neon** | Same as above, but $0 | Could be added as a third track that puts the same image on Cloud Run |
| **AWS Lightsail** | The 1GB plan is $7. Similar specs to GCP e2-micro, but paid | When you need the Seoul region (response speed) |
| **Oracle Always Free** | Signup rejections and regional capacity shortages are common, which makes class prep unreliable. It's ARM, so images must be built for ARM | When you really need a large free server |
| **Railway** | Can't keep using it for free ($5/month) | When you need a PaaS that doesn't sleep and $5 a month is fine |
| **GCP managed load balancer** | About $18 a month. Too much for one server. Caddy does the same jobs (HTTPS, switching, distributing) inside the server | When you have several servers |

## Sources

- [Cloud Run pricing](https://cloud.google.com/run/pricing)
- [Cloud SQL pricing](https://cloud.google.com/sql/pricing)
- [Google Cloud Free Program](https://cloud.google.com/free), [Getting started with the Compute Engine free tier](https://cloud.google.com/free/docs/compute-getting-started)
- [Firebase App Hosting frameworks](https://firebase.google.com/docs/app-hosting/frameworks-tooling)
- [Render: Deploy for Free](https://render.com/docs/free), [Render Blueprint YAML Reference](https://render.com/docs/blueprint-spec), [Render Deploys (checksPass)](https://render.com/docs/deploys)
- [Neon Pricing](https://neon.com/pricing), [Neon Free plan limits](https://neon.com/faqs/free-plan-limits-and-quotas)
- [Supabase Project Pausing](https://supabase.com/docs/guides/platform/free-project-pausing)
- [Railway Pricing Plans](https://docs.railway.com/pricing/plans)
- [Koyeb Pricing FAQ](https://www.koyeb.com/docs/faqs/pricing)
- [Amazon Lightsail Pricing](https://aws.amazon.com/lightsail/pricing)
- [DigitalOcean Droplet Pricing](https://www.digitalocean.com/pricing/droplets)
- [Hetzner Price Adjustment 2026](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/)
- [Oracle Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm), [InfoQ: Oracle halves free tier A1 limits](https://www.infoq.com/news/2026/07/oracle-cloud-free-tier-limits/)
