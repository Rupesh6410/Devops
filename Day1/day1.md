# Day 1 — Linux Fundamentals For DevOps

Final-year SE student, transitioning into DevOps. Learning everything hands-on,
first principles — understanding *why* before memorizing *how*.

---

## 1. Why Linux Exists (First Principles)

Raw hardware (CPU, RAM, disk) can't run multiple programs safely on its own —
programs would collide, overwrite each other's memory, and crash constantly.

An **Operating System** sits between programs and hardware, managing resources
fairly. Linux is one (free, open-source) implementation of this idea — and
today it runs **96% of the world's servers**, every Android phone, every
major cloud (AWS/GCP/Azure).

**Layers:**
```
YOU (typing commands)
      |
SHELL (bash) — interprets what you type
      |
KERNEL — manages CPU, memory, disk, network
      |
HARDWARE
```

Verified on my machine:
```bash
echo $SHELL          # /bin/bash
uname -r              # kernel version
cat /etc/os-release    # distro info (Ubuntu)
```

---

## 2. The Linux Filesystem

Everything starts from a single root `/` — no separate drive letters like Windows.

```
/etc   → config files
/var   → logs (/var/log)
/home  → personal folders
/usr   → installed programs
/bin   → core commands
/tmp   → temporary files
/proc  → running processes (virtual)
```

---

## 3. Navigation & File Commands

```bash
pwd                  # where am I
ls -la                # list, including hidden files
cd /etc; cd ~; cd -; cd ..

mkdir -p project/logs/2026     # nested folders in one shot
touch app.log
echo "text" > app.log          # OVERWRITES file
echo "text" >> app.log         # APPENDS to file
cat app.log
cp app.log backup.log
mv backup.log old.log
rm old.log
rm -rf project/                # recursive + force — NO undo, be careful
```

**Key lesson:** `>` vs `>>` — overwrite vs append. Classic real-world mistake:
wiping a production config file by using `>` instead of `>>`.

---

## 4. Processes

A process = one running instance of a program. The kernel rapidly switches
the CPU between processes (time-slicing) so it *feels* simultaneous.

```bash
ps aux                  # list all processes
ps aux | grep nginx      # filter for a specific one
top                      # live view (q to quit, M = sort by memory, P = sort by CPU)
```

Every process has a **PID** (Process ID). PID 1 is always `systemd`.

```bash
ps -p 1                 # confirms systemd is PID 1
```

---

## 5. systemd — Managing Services

systemd is the first process the kernel starts (PID 1) — it starts, stops,
and supervises every other service.

```bash
sudo systemctl status nginx
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl enable nginx     # auto-start ON BOOT
sudo systemctl disable nginx
sudo systemctl is-enabled nginx
```

**Critical distinction:**
- `start` / `stop` → controls state *right now*
- `enable` / `disable` → controls whether it survives a **reboot**

These are two completely independent switches. Stopping a service today does
NOT mean it stays off after a reboot — only `disable` guarantees that.

**Verified hands-on:** stopped nginx → `curl http://localhost` → connection
refused (nothing listening on port 80) → started nginx → `curl` returned the
default HTML page + `200 OK`.

---

## 6. File Permissions

Every file has an owner, a group, and permission bits for **owner / group / others**.

```
-rw-r--r--
↑   ↑    ↑   ↑
type owner group others
```

`r`=4, `w`=2, `x`=1 → add up per group:
```
rwx = 7    rw- = 6    r-x = 5    r-- = 4
```

So `rwxr-xr-x` = `755`, and `rw-r--r--` = `644`.

```bash
chmod 755 script.sh        # numeric mode
chmod u+x script.sh        # symbolic mode (u=owner, g=group, o=others, a=all)
chmod 700 secret.sh         # owner: rwx, group: ---, others: ---  (fully private)
chmod 750 deploy.sh         # owner: rwx, group: r-x, others: ---
```

**Why directories need `x`:** for folders, `x` means "permission to enter/cd
into it," not "execute." Without it you can see a folder exists but can't
access what's inside.

**Ownership:**
```bash
chown root script.sh        # change owner
chown $USER script.sh       # give it back to myself
```

Permissions are evaluated in order: **owner → group → others** — the first
matching category you belong to is the one that applies.

---

## 7. Users & Groups (Least Privilege)

**Why:** if every service ran as one all-powerful user, one compromised
service could destroy everything else on the machine. Separate users with
only the access they need = least privilege.

```bash
whoami
id                              # UID, GID, all groups I belong to
cat /etc/passwd                  # every user on the system

sudo useradd -m testuser          # -m creates a home folder
sudo passwd testuser
sudo groupadd devteam
sudo usermod -aG devteam testuser  # -a = APPEND (don't drop existing groups!)
```

**sudo** lets a trusted user temporarily borrow root's power for a single
command — every use is logged (`/var/log/auth.log`), critical for security
audits and accountability.

---

## 8. Advanced Commands — grep, awk, sed, find, pipes

**Pipes (`|`)** — feed the output of one command as input to the next.
This is the core Unix philosophy: small focused tools, chained together.

```bash
ps aux | grep nginx | grep -v grep   # grep -v grep removes the false self-match
```

**grep** — search text:
```bash
grep -i "error" file.log     # case-insensitive
grep -c "error" file.log     # count matches only
grep -v "error" file.log     # exclude matches
grep -n "error" file.log     # show line numbers
```

**awk** — extract/process columns:
```bash
ps aux | awk '{print $2}'          # just the PID column
ps aux --sort=-%mem | awk '{print $4, $11}' | head -5   # top mem consumers
```

**sed** — find & replace:
```bash
sed 's/old/new/' file.txt          # preview only, doesn't save
sed -i 's/old/new/' file.txt       # -i = in-place, actually saves
```
Always test without `-i` first — a wrong `sed -i` on a production config can
cause a real outage.

**cut** — simpler column extraction:
```bash
cut -d: -f1 /etc/passwd            # extract usernames (':' delimited)
```

**find** — locate files:
```bash
find ~ -name "*.log"
find / -name "nginx.conf" 2>/dev/null   # 2>/dev/null silences permission errors
```

---

## 9. Disk Mounting

**Why mounting exists:** a new disk is just raw storage until it's attached
to a folder in the single unified filesystem tree.

```bash
lsblk                          # see all detected disks (mounted or not)
df -h                          # see currently MOUNTED filesystems + usage
sudo file -s /dev/sdb           # check if it has a filesystem yet
sudo mkfs -t ext4 /dev/sdb       # format it (WIPES existing data — check device name!)
sudo mkdir /mnt/newdisk
sudo mount /dev/sdb /mnt/newdisk
sudo umount /mnt/newdisk
```

**Important:** `mount` is runtime-only — same pattern as `start` vs `enable`.
It does NOT survive a reboot unless added to `/etc/fstab`:

```bash
sudo blkid /dev/sdb              # get the UUID
sudo nano /etc/fstab              # add: UUID=xxx /mnt/newdisk ext4 defaults 0 2
sudo mount -a                     # test the fstab entry BEFORE rebooting
```
A bad fstab entry can prevent a server from booting cleanly — always verify
with `mount -a` first.

---

## 10. Mock Interview — Self Corrections

Ran a mock Linux interview on myself. Key gaps identified and fixed:

1. **Shell ≠ a dumb pass-through to the kernel.** It reads/parses text,
   launches programs as processes, and the *program* makes system calls —
   the shell is an interpreter with its own job, not a wire.

2. **Diagnostic order matters under pressure:** confirm the symptom is real →
   identify the exact process/PID → investigate logs → decide → act (least
   destructive option first). Don't jump to action before gathering evidence.

3. **`kill` vs `kill -9` is about signals, not just "two flavors":**
   - `kill` sends `SIGTERM` — program *can* catch it and clean up gracefully
   - `kill -9` sends `SIGKILL` — cannot be blocked/ignored by any program,
     kernel terminates immediately, no cleanup

4. **Tool-to-resource mapping — my biggest gap:**
   - CPU / Memory → `top`, `htop`, `ps aux`
   - Disk space (filesystem level) → `df -h`
   - Disk space (folder/file level) → `du -sh`
   - Network → `ss`, `ip a`
   Mixed up `top` (CPU/mem) when asked about diagnosing a full disk — wrong
   tool family for the resource category. Corrected.

**Self-rating: 6/10** — solid instinct to gather evidence before acting, but
need more precision separating boot-time vs runtime concepts, and stricter
discipline on which tool measures which resource.

---

## Real-world connection

`502 Bad Gateway` diagnostic flow practiced: check `systemctl status nginx`
first (verify the obvious layer even when confident) → check nginx's own
error log → then check the backend application's process/logs. Verify from
the outside in, with evidence at each step — not straight to a gut theory.

---

## Status: Linux For DevOps — Complete
Next: Networking For DevOps (OSI/TCP-IP, DNS, CIDR, Load Balancers, TLS/SSL)
