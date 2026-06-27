# Day 6 (continued) — Docker: Building Images, Volumes, Networking, Best Practices

Continuing from Docker fundamentals (image vs container, core commands,
run lookup sequence) covered earlier today. This session: building custom
images, volumes, networking, and production best practices.

---

## 1. Dockerfile — Building Your Own Image

**Problem:** so far only used pre-built images (`nginx`, `hello-world`).
Real work means packaging your own application.

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

EXPOSE 5000

CMD ["python", "app.py"]
```

**Why `FROM` an existing base instead of starting blank:** every container
needs an OS + runtime layer underneath it. Building Python's entire
interpreter from scratch for every image would be wasteful — `FROM` builds
on top of an already-prepared, tested base, same "don't reinvent the wheel"
principle as Linux distros being built on top of one shared kernel.

**Critical ordering lesson — copy dependencies BEFORE application code:**
Docker builds images in layers and caches each one. If `requirements.txt`
hasn't changed, Docker reuses the cached "install dependencies" layer
instead of re-running `pip install` on every rebuild. If everything was
copied at once, any code change would invalidate the cache and force a full
dependency reinstall even when dependencies didn't change.

**`EXPOSE` is documentation, not the actual publishing mechanism** — the
real port mapping to the host still happens via `-p` at `docker run` time.

```bash
docker build -t my-flask-app .
docker run -d -p 5000:5000 my-flask-app
curl http://localhost:5000
```

**Verified the caching lesson hands-on:** changed `app.py`, rebuilt, and
saw build output explicitly mark `WORKDIR`, `COPY requirements.txt`, and
`RUN pip install` as `CACHED` — only the final `COPY app.py .` layer
actually re-ran, since that was the only thing that changed.

---

## 2. Multistage Builds

**Problem:** build tools (compilers, dev dependencies) are needed to CREATE
the final artifact but are pure bloat once the app is actually built.

```dockerfile
# Stage 1: Build
FROM python:3.11 AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt
COPY app.py .

# Stage 2: Final, minimal
FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY --from=builder /app/app.py .
ENV PATH=/root/.local/bin:$PATH
EXPOSE 5000
CMD ["python", "app.py"]
```

`COPY --from=builder` reaches into the first (otherwise discarded) stage's
filesystem and pulls out only the specific files actually needed. Everything
else from the build stage — compilers, intermediate files — never makes it
into the final image. Result: a noticeably smaller final image, confirmed by
comparing sizes with `docker images`.

**Distroless images** (noted, not hands-on today): base images with no
shell, no package manager — only the app and its exact runtime deps. Reduces
attack surface further than even a "slim" image. Flagged as interview-aware
knowledge, parked for now given pace priorities.

---

## 3. Docker Compose

**Problem:** real apps need multiple containers (app + database, etc.)
running together and networked — manually running multiple `docker run`
commands with the right flags every time is tedious and error-prone.

```yaml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "5000:5000"
    depends_on:
      - db

  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: mysecretpassword
    volumes:
      - pg-data:/var/lib/postgresql/data

volumes:
  pg-data:
```

```bash
docker compose up -d
docker compose ps
docker compose logs web
docker compose down
```

`depends_on` only controls start ORDER, not "wait until the dependency is
actually ready to accept connections" — a real gotcha requiring additional
health-check logic in production.

---

## 4. Registries

```bash
docker login
docker tag my-flask-app yourusername/my-flask-app:v1
docker push yourusername/my-flask-app:v1
```

Tagging with a username namespaces the image on Docker Hub. This is how a
teammate, CI/CD pipeline, or production server pulls a specific built image
without redoing the build — push once, pull anywhere.

---

## 5. Volumes — Why They Exist

**Problem:** containers are designed to be ephemeral/disposable — this is a
feature (clean scaling, updates, rollbacks), but it means anything written
inside a container disappears the moment that container is removed.

**Verified by breaking it on purpose:** wrote a file inside a running
container, removed the container, ran a fresh one from the same image —
the file was gone. The new container is a clean instance from the image,
with none of the previous container's runtime changes.

**Named volumes** (Docker-managed, most common):
```bash
docker volume create my-data
docker run -d --name test-db -v my-data:/var/lib/postgresql/data postgres:15
```
Docker manages the actual physical storage location — data survives even
after `docker rm -f` + recreating the container, since the volume, not the
container, holds the data.

**Bind mounts** (map a specific host folder):
```bash
docker run -d -p 8080:80 -v ~/docker-practice/html:/usr/share/nginx/html nginx
```
Edits to the host file appear instantly inside the running container, no
rebuild or restart needed — useful for active development. Named volumes
don't require knowing/controlling the exact host path (good for databases);
bind mounts require exactly that (good for editing files directly).

**tmpfs mounts** (noted, not hands-on): memory-only storage, never written
to disk — used for temporary sensitive data like secrets.

**Important default:** `docker rm` does NOT delete associated named volumes
unless `docker rm -v` or `docker volume prune` is run explicitly — Docker
defaults toward not destroying data accidentally.

---

## 6. Docker Networking

**Problem:** how does one container actually find and reach another
container, without hardcoding IPs that can change?

```bash
docker network ls
```
Default networks: `bridge` (default), `host`, `none`.

**Default bridge network — the gotcha:**
```bash
docker run -d --name container-a nginx
docker run -d --name container-b nginx
docker exec -it container-a ping container-b   # FAILS - no name-based DNS on default bridge
```
Containers on the default bridge can only reach each other by IP, not name.

**Custom (user-defined) bridge network — the fix:**
```bash
docker network create my-app-network
docker run -d --name container-c --network my-app-network nginx
docker run -d --name container-d --network my-app-network nginx
docker exec -it container-c ping container-d    # WORKS - name-based DNS provided automatically
```

**Why the difference exists:** largely historical — the default bridge
predates Docker's embedded DNS feature; user-defined networks were
introduced later with this improvement built in, and the old default was
kept for backward compatibility. Practical takeaway: always create a custom
network for real projects.

**Connects directly to Compose:** this is exactly why a Compose `web`
service can reach `db` just by hostname — Compose automatically creates its
own custom network for all services defined in one file, giving free
name-based DNS resolution without ever running `docker network create`
manually.

**Port mapping vs networking — distinct concerns:** `-p 8080:80` exposes a
container to the OUTSIDE world (host/internet). Custom networks/DNS are
about containers reaching EACH OTHER internally. A `db` service typically
has no `-p` mapping at all — only `web` needs outside reachability.

---

## 7. Best Practices — Production Checklist

**Image size / build:**
- Use slim/alpine/distroless base images
- Order Dockerfile instructions least-to-most frequently changing
- Multistage builds for compiled apps
- `.dockerignore` (same concept as `.gitignore` — keeps junk/secrets out of
  the build context entirely)

**Security:**
- Never run as root — create and `USER` a non-root user
- Never hardcode secrets into a Dockerfile (can be extracted from image
  layers even if "removed" in a later step) — pass secrets at runtime
  (`docker run -e`) or use a proper secrets manager
- Scan images for CVEs: `docker scout cves my-flask-app`
- Use specific version tags, never `latest` in production — `latest` is a
  moving target and breaks reproducibility

**Runtime / resources:**
- Set resource limits: `--memory`, `--cpus` — prevents one container from
  starving others on the host (same finite-CPU problem as Day 1 processes,
  now at the container level)
- Use `HEALTHCHECK` — same L7 health check concept as Load Balancers
  (Day 2): catches a frozen-but-running process, not just a crashed one

**Volumes / data:**
- Named volumes for anything that must persist
- Don't rely on bind-mounted code in production — bake code into the image
  at build time for immutable, versioned deployments

**Networking:**
- Always use custom networks, never the default bridge
- Expose only the ports that genuinely need external access

**Logging:**
- Write logs to stdout/stderr, not files inside the container — logs
  written inside the container vanish when it's destroyed, same as any
  other ephemeral container storage

**CI/CD tagging:**
- Tag images with the Git commit hash (`docker build -t myapp:$(git rev-parse --short HEAD) .`)
  so it's always traceable which exact code version produced a given image

---

## Status: Docker — Complete (image building, volumes, networking, best practices)
Next: Azure
