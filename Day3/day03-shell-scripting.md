# Day 3 — Shell Scripting Fundamentals

First-principles learning continued — scripts are just sequences of commands
automated into one repeatable, reliable action.

---

## 1. Why Shell Scripting Exists

**Problem:** typing the same sequence of commands repeatedly is slow and
error-prone, especially during an incident or when a task needs to run
identically across many servers.

**Answer:** a shell script — a text file of commands, executed top to bottom
by the shell, exactly as if typed manually.

```bash
chmod +x script.sh
./script.sh
```

---

## 2. The Shebang Line

```bash
#!/bin/bash
```

Tells the OS "don't execute this file's content directly — hand it to
`/bin/bash` to interpret line by line." Without it, the OS has no way to know
which interpreter should run the file's contents.

---

## 3. Variables & Command Substitution

```bash
NAME="Rupesh"
DATE=$(date +%Y-%m-%d)     # command substitution - captures command output into a variable
echo "Hello, $NAME, today is $DATE"
```

**Rule:** no spaces around `=`. `NAME = "Rupesh"` breaks because bash parses
`NAME` as a command name when a space precedes `=`, not as an assignment.

---

## 4. User Input

```bash
echo "Enter server IP:"
read SERVER_IP
ping -c 2 $SERVER_IP
```

---

## 5. Conditionals

```bash
THRESHOLD=80
USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

if [ $USAGE -gt $THRESHOLD ]; then
    echo "WARNING: disk usage high"
else
    echo "Disk usage normal"
fi
```

**Comparison operators (bash-specific, not `>`/`<`/`==`):**
```
-gt   greater than
-lt   less than
-ge   greater than or equal
-le   less than or equal
-eq   equal to
-ne   not equal to
```

**Why not `>`:** `>` is already reserved for output redirection
(`echo "x" > file.txt`). Using it in a comparison would make bash try to
redirect output into a file literally named after the compared value,
instead of comparing numbers.

**Syntax correction from mock interview:** `[ ]` brackets are required and
`[` is literally an executable command (verify with `which [`), not just
punctuation — it needs a space after `[` and before `]` since they're
argument boundaries for that command. `if $COUNT -gt 10` (no brackets) is
invalid syntax.

---

## 6. Loops

### for loop
```bash
SERVERS="192.168.0.101 192.168.0.102 192.168.0.103"
for server in $SERVERS
do
    ping -c 1 $server > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "$server is UP"
    else
        echo "$server is DOWN"
    fi
done
```

`$?` = exit code of the last command (0 = success, non-zero = failure). This
is the universal convention every Linux command-line tool follows, and it's
how scripts make decisions based on whether a previous step actually worked.

### while loop
```bash
COUNT=1
while [ $COUNT -le 5 ]
do
    echo "Attempt $COUNT"
    COUNT=$((COUNT + 1))    # arithmetic expansion - required for math in bash
    sleep 1
done
```

---

## 7. Functions & Positional Parameters

```bash
check_service() {
    SERVICE_NAME=$1
    sudo systemctl is-active --quiet $SERVICE_NAME
    if [ $? -eq 0 ]; then
        echo "$SERVICE_NAME is running"
    else
        echo "$SERVICE_NAME is NOT running"
    fi
}

check_service nginx
check_service cron
```

`$1` inside a function = first argument passed to that function call.

---

## 8. Script Arguments vs File Descriptors — Two Unrelated Concepts

These look similar (both are small numbers) but mean completely different
things — important to keep clearly separated.

### Positional parameters — input passed INTO a script
```bash
#!/bin/bash
echo "Script name: $0"
echo "First arg: $1"
echo "Second arg: $2"
echo "All args: $@"
echo "Arg count: $#"
```
```bash
./deploy.sh production v2.3.1
```
This is the exact mechanism behind real commands like `./script.sh production`,
`docker run -p 8080:80 myimage`, `kubectl apply -f config.yaml`.

### File descriptors — universal I/O channels every process has
```
0 = stdin   (where a program reads input FROM)
1 = stdout  (where a program sends NORMAL output TO)
2 = stderr  (where a program sends ERROR output TO)
```
```bash
find / -name "nginx.conf" 2>/dev/null      # silence stderr (permission errors)
ping -c 1 $server > /dev/null 2>&1          # silence stdout AND stderr
```
`2>&1` means "send stderr to wherever stdout is currently going" — used
together with `> /dev/null` to fully silence a command while still checking
its exit code via `$?`.

---

## 9. set -e — Halt on Failure

```bash
#!/bin/bash
set -e

echo "Line 1 runs"
false                # always exits 1 (failure)
echo "Line 2 — never runs, script already stopped"
```

**Precise behavior:** the moment ANY command returns a non-zero exit code,
the script terminates immediately — no further lines execute, regardless of
what they are. This is not conditional logic; it's an unconditional halt.

**Why production scripts use this:**
```bash
#!/bin/bash
set -e
cd /important/directory    # if this fails...
rm -rf *                    # ...this NEVER runs, because the script already stopped
```
Without `set -e`, bash prints an error on a failed command and continues to
the next line anyway — meaning a later destructive command can run in an
unintended state (e.g. wrong directory) because an earlier step silently
failed.

---

## 10. Real Automation Scripts

### Cleanup
```bash
#!/bin/bash
set -e
TARGET_DIR="/tmp"
DAYS_OLD=7
DELETED_COUNT=0

while read -r file
do
    rm -f "$file"
    DELETED_COUNT=$((DELETED_COUNT + 1))
done < <(find "$TARGET_DIR" -type f -mtime +$DAYS_OLD)

echo "$DELETED_COUNT files removed"
```

**Subshell bug — important gotcha:** piping into a loop
(`find ... | while read file`) runs the loop in a **subshell** — any
variable changed inside (like `DELETED_COUNT`) resets back to its original
value once the loop ends, because the subshell's memory is separate from the
main script. Process substitution (`< <(...)`) runs the loop in the SAME
shell, so variables persist correctly. Verified this live — a counter
incremented inside a piped loop printed `0` after the loop ended, while the
same counter using process substitution printed the correct count.

### Log Rotation
```bash
#!/bin/bash
set -e
LOG_FILE="app.log"
MAX_SIZE_KB=1
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

CURRENT_SIZE=$(du -k "$LOG_FILE" | cut -f1)

if [ $CURRENT_SIZE -gt $MAX_SIZE_KB ]; then
    mv "$LOG_FILE" "${LOG_FILE}.${TIMESTAMP}"
    gzip "${LOG_FILE}.${TIMESTAMP}"
    touch "$LOG_FILE"
fi
```
Real production systems mostly use the built-in `logrotate` tool
(`/etc/logrotate.d/`) rather than custom scripts for standard services — but
understanding the manual mechanism (rename with timestamp → compress →
recreate empty file) matters for app-specific logs without an existing
logrotate config. Old logs are compressed, not deleted immediately, since
historical logs are often needed for debugging issues reported days later.

### Alerting
```bash
#!/bin/bash
set -e
THRESHOLD=80
USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

send_alert() {
    MESSAGE=$1
    echo "[ALERT] $MESSAGE"
    echo "$(date) - $MESSAGE" >> alerts.log
    # Real version sends to a webhook, e.g.:
    # curl -X POST -H "Content-Type: application/json" \
    #   -d "{\"text\":\"$MESSAGE\"}" https://hooks.slack.com/services/YOUR/WEBHOOK
}

if [ $USAGE -gt $THRESHOLD ]; then
    send_alert "Disk usage at ${USAGE}%, exceeding ${THRESHOLD}% threshold"
fi
```

### Tying it together with cron (from Day 2)
```
0 * * * *  /path/alert.sh        # check + alert hourly
0 0 * * *  /path/log-rotate.sh    # rotate logs at midnight
0 3 * * *  /path/cleanup.sh        # cleanup at 3 AM
```
This is exactly the pattern real production servers use to self-manage:
cron triggers scripts, scripts check conditions, scripts act or alert.

---

## 11. Mock Interview — Self Corrections (Day 3)

1. **Conditional syntax:** `if [ $COUNT -gt 10 ]` requires square brackets —
   `[` is an actual executable command (confirmed via `which [`), and
   needs spaces around it since they're argument boundaries, not just
   punctuation.

2. **Why not `>` for comparison:** precise reason is that `>` is reserved
   for output redirection — `[ $COUNT > 10 ]` would attempt to create/
   overwrite a file named `10`, not compare values.

3. **`set -e` is NOT conditional logic.** It's an unconditional halt the
   instant any command fails — initially described it more like
   exit-code-based decision making (`$?` checks), which is a related but
   separate concept.

4. **Deferred to next session:** explaining the subshell/process
   substitution distinction out loud, precisely, using the word "subshell"
   correctly — concept is understood and documented above, but not yet
   drilled under mock-interview pressure.

**Self-rating: stayed honest about pace today** — prioritized hands-on
automation scripts (cleanup/rotate/alert) over chasing every tangent, per
the pace correction agreed after Day 2. Syntax-level recall under pressure
(brackets, exact behavior of `set -e`) remains the consistent gap across all
3 days so far — same pattern, now being deliberately drilled.

---

## Status: Shell Scripting Fundamentals — Complete
Next: Git & GitHub
