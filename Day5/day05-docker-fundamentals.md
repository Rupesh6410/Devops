# Day 5 — Docker Fundamentals

Following Abhishek Veeramalla's Docker playlist (videos 1-3 of 7 covered
today), first-principles + hands-on as usual, plus a mock interview pass at
the end.

---

## 1. Why Docker Exists

**Problem:** "it works on my machine" — an app that runs fine on a
developer's laptop fails on the server because of different OS versions,
missing dependencies, different library versions, etc.

**Answer:** Docker packages an application together with everything it
needs to run (dependencies, libraries, runtime, config) into one portable
unit that behaves identically anywhere Docker is installed — laptop, server,
cloud, doesn't matter.

```bash
docker --version
```

---

## 2. Image vs Container — The Core Mental Model

**Precise relationship:**
> An image is a read-only template/blueprint. A container is a running (or
> stopped) instance created FROM that image.

```
Image     = a class / a recipe
Container = an object instantiated from that class / the actual dish cooked
```

**Key precision point:** multiple independent containers can be created from
the exact same single image — each runs isolated from the others, with its
own filesystem changes, without affecting the original image or each other.

```bash
docker pull nginx
docker images                    # list images stored locally

docker run -d --name web1 nginx
docker run -d --name web2 nginx
docker ps                         # two separate containers, same one image
```

---

## 3. Core Commands

```bash
docker images                     # list local images
docker ps                          # list RUNNING containers
docker ps -a                       # list ALL containers (including stopped)

docker run hello-world              # create + start a container from an image
docker run -d -p 8080:80 nginx       # detached mode + port mapping

docker stop <container_id>           # gracefully stop a running container
docker start <container_id>          # start a stopped container again
docker rm <container_id>             # remove a (stopped) container
docker rmi <image_id>                 # remove an image
```

---

## 4. docker run — The Exact Lookup Sequence

`docker run` is not just "fetch and run" as one vague action — it follows a
precise sequence:

```
1. Check LOCAL machine first - does this image already exist? (docker images)
2. If found locally -> skip straight to creating/starting the container, no network needed
3. If NOT found locally -> implicit "docker pull" from the default registry
   (Docker Hub) -> download the image -> THEN create/start the container
```

**Verified hands-on:**
```bash
docker rmi hello-world
docker run hello-world
# Output shows: "Unable to find image 'hello-world:latest' locally"
# then "Pulling from library/hello-world" - the implicit pull, visible

docker run hello-world
# Run again immediately - NO pulling message this time, image is now cached locally
```

---

## 5. The `-d` (Detached) Flag — Precise Mechanism

**Without `-d`:**
```bash
docker run -p 8080:80 nginx
```
Terminal is now ATTACHED to the container's output — live logs print
directly to the terminal, and the terminal is blocked/stuck until `Ctrl+C`
(which also stops the container).

**With `-d`:**
```bash
docker run -d -p 8080:80 nginx
```
Container starts in the background, control returns to the terminal
immediately (just prints the container ID). The container keeps running
independently of the terminal session.

**Verified hands-on (two-terminal proof):** ran nginx without `-d` in
Terminal 1 (terminal appeared "stuck" showing logs) — then from Terminal 2,
`docker ps` showed it WAS running, and `curl localhost:8081` got a real
response. This proves the container's execution is independent of the
terminal; `-d` only changes whether the terminal waits and watches or walks
away immediately.

---

## 6. Port Mapping

```bash
docker run -d -p 8080:80 nginx
```
```
-p HOST_PORT:CONTAINER_PORT
```
`8080` (host/your machine) maps to `80` (inside the container, where nginx
actually listens). Visiting `localhost:8080` on the host routes through to
port `80` inside the isolated container — this is how an app inside an
isolated container becomes reachable from outside it.

```bash
curl http://localhost:8080
```

---

## 7. Mock Interview — Self Corrections (Day 5)

1. **Image vs container relationship** — correctly identified images create
   containers, but initially missed stating precisely that ONE image can
   produce MANY independent containers simultaneously. Verified by running
   two separately-named containers from the same single `nginx` image.

2. **Why `hello-world` ran without an explicit `docker pull` first** —
   correct general instinct ("it fetches and runs it"), but the precise
   mechanism is a specific lookup sequence: check local cache first, only
   pull from the registry if missing. Verified by removing the image and
   watching the explicit "Unable to find image locally... Pulling from..."
   message appear, then disappear on the second run.

3. **`-d` flag** — correct on "detached so terminal doesn't freeze," refined
   to the precise mechanism: the container's actual process runs independent
   of any terminal regardless of `-d`; the flag only controls whether the
   terminal stays attached and blocks, or returns control immediately while
   the container keeps running in the background under the Docker daemon.

**Recurring pattern, now clearly established across 5 days:** general
behavior/intuition is consistently correct on the first attempt across
Linux, Networking, Shell Scripting, and now Docker. The specific, deliberate
skill to keep practicing is stating the EXACT underlying mechanism unprompted
the first time, rather than needing a follow-up question to get there.

---

## Status: Docker — In Progress (Videos 1-3 of 7 complete)
Next: Videos 4-7 — Docker Compose, registries, advanced concepts,
multistage builds, distroless images
