# 03. Put it on a real server

**Goal**: rent a computer that is on the internet 24 hours a day, give it a domain and HTTPS, and do the first deploy by hand.

> This doc is something the teacher sets up once. In class, it's enough to SSH into the finished server and look around.

## What we're building

```
Teacher's Mac ──ssh──▶  GCP server (e2-micro, Oregon USA, free)
                         ├─ Docker
                         ├─ /opt/wejump        (this repo)
                         └─ deploy user        (the account GitHub Actions logs in as)

DuckDNS:  wejump.duckdns.org  ──▶  server IP
```

**Cost**: the GCP free tier (one e2-micro, 30GB disk, external IP included) and DuckDNS are both $0. You do need to register a card when signing up for GCP.

## 0. First: the image has to be on GitHub

The server doesn't build the app itself. It downloads a finished image from GitHub's warehouse (ghcr.io).

1. When you push the repo to GitHub, Actions builds the image automatically. In the Actions tab, check that `test` and `build` are green. (`deploy` is skipped because nothing is configured yet. That's normal.)
2. Go to your GitHub profile → **Packages** → `wejump` and check that the image is **Public**.
   The server can only download the image without logging in if it's public. Images pushed by Actions from a public repo usually become public automatically. If it says Private, go to **Package settings** → **Change visibility** at the bottom → **Public**.
   There are no secrets in the image, so making it public is safe (see `.dockerignore` in [02-docker](02-docker.md)).

## 1. Create the GCP server (on your Mac)

1. Sign up at <https://console.cloud.google.com> → link a billing account → create a new project. Write down the project ID.
2. Install gcloud and log in:
   ```bash
   brew install --cask google-cloud-sdk
   gcloud auth login
   ```
3. Create the server:
   ```bash
   PROJECT=<project-id> ./deploy/vps/create-vm.sh
   ```
   It prints the public IP at the end. Open [`create-vm.sh`](../deploy/vps/create-vm.sh) and you'll see everything written down: the machine type (e2-micro), the operating system (Ubuntu 24.04), and the firewall (only 80 and 443 open).

## 2. Create a domain (DuckDNS)

1. Log in to <https://www.duckdns.org> with your GitHub account.
2. Create a subdomain with the name you want (e.g. `wejump`), put the server IP in the **current ip** field, and click **update ip**.
3. Write down the **token** at the top of the page (used for automatic IP updates, keep it secret).

Check:
```bash
dig +short wejump.duckdns.org     # success if it prints the server IP
```

## 3. Make a deploy key (on your Mac)

Create an SSH key pair that GitHub Actions will use to get into the server.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/wejump_deploy -N "" -C "github-actions-wejump"
cat ~/.ssh/wejump_deploy.pub      # public key (the lock). Registered on the server. Safe to show
# ~/.ssh/wejump_deploy            # private key (the key). Goes only into a GitHub Secret in 04. Never share it
```

## 4. Prepare the server (inside the server)

```bash
gcloud compute ssh wejump --project <project-id> --zone us-west1-b
```

Your prompt is now on the server. Look around.

```bash
uname -a          # Linux kernel
free -h           # 1GB of RAM
df -h /           # 30GB of disk
curl ifconfig.me  # this server's public IP
```

Then run the setup script once.

```bash
git clone https://github.com/<github-id>/wejump.git /tmp/wejump
sudo DOMAIN=wejump.duckdns.org \
     DEPLOY_PUBKEY="<the one-line public key you copied in step 3>" \
     DUCKDNS_TOKEN=<DuckDNS token> \
     bash /tmp/wejump/deploy/vps/setup.sh
```

What [`setup.sh`](../deploy/vps/setup.sh) does: installs Docker, adds 1GB of swap memory, creates the `deploy` user and registers the public key, downloads the code to `/opt/wejump`, and creates `.env` (the database password is generated randomly, so no person ever needs to see it).

## 5. First deploy by hand

```bash
sudo -iu deploy                      # switch to the deploy user
cd /opt/wejump/deploy/vps
./deploy.sh latest
```

Open `https://wejump.duckdns.org`. Click the lock in the address bar and you'll see the certificate was issued by **Let's Encrypt**. Caddy got it on its own, just from seeing the domain name.

## 6. Look around the server

```bash
alias dc='docker compose -f docker-compose.prod.yml'   # the command is long, so give it a nickname

dc ps                    # running containers: db, caddy, app-blue
cat Caddyfile            # where visitors are being sent right now
cat .active              # blue
dc logs caddy | grep -i certificate   # the certificate issuing log
dc logs -f app-blue      # live access log. Open the site on your phone and it shows up here (Ctrl+C to stop)
dc exec db psql -U wejump -c "SELECT count(*) FROM messages;"
```

## 7. Security check

On your Mac:
```bash
nc -vz -G 3 <server-ip> 443     # open (succeeded)
nc -vz -G 3 <server-ip> 5432    # closed (timeout). The database can't be reached from the internet
```

The database is protected twice. The compose file gives the database no `ports`, and the GCP firewall only opens 80 and 443.

## Think about it

- Building an image and logging into the server to type `deploy.sh` every time you change the code is tedious → [04-automation](04-automation.md)
- What does `deploy.sh` actually do so the site never goes down even once? → [05-blue-green](05-blue-green.md)
