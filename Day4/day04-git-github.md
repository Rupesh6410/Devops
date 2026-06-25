# Day 4 — Git & GitHub

First-principles learning continued. This session also explained, in
hindsight, an earlier real bug I'd hit (empty file commits) before I'd
learned the actual mechanics — documented at the end.

---

## 1. Why Git Exists

**Problem:** code changes over time, mistakes happen, and without a way to
track every change you have no way back to a working version — impossible
to manage at scale, and impossible once multiple people touch the same files.

**Answer:** Git — a version control system that tracks every change to every
file over time, lets you revert to any previous state, and lets multiple
people work on the same codebase without overwriting each other.

```bash
git --version
git init
```

---

## 2. The Three States — Core Mental Model

```
Working Directory  →  Staging Area  →  Repository
  (files as you        (git add =          (git commit =
   edit them)            "ready to save")     permanently saved)
```

```bash
git status     # always shows exactly which state your files are in
```

**Why a separate staging area exists:** it allows committing selectively.
If 5 files changed but only 2 belong to one logical change, you can stage
and commit just those 2, keeping commit history meaningful — one commit =
one coherent change, not a random dump of everything touched that day.

---

## 3. Core Workflow

```bash
echo "Hello Git" > file1.txt
git status                              # "Untracked files"

git add file1.txt
git status                              # "Changes to be committed"

git commit -m "Add file1.txt with initial content"
git status                              # "nothing to commit, working tree clean"

git log                                 # full commit history: author, date, message, hash
```

---

## 4. Checking Changes Before Committing — diff

```bash
echo "second line" >> file1.txt
git diff                # shows unstaged changes, line by line (+ added, - removed)

git add file1.txt
git diff                # now shows NOTHING - diff only shows unstaged changes
git diff --staged        # shows what's actually staged and ready to commit
```

Two different commands for two different views — easy to confuse.

---

## 5. Branching

**Problem:** working on something new/risky shouldn't threaten a stable,
working main codebase.

**Answer:** branches — independent, isolated lines of development that can
be merged back later.

```bash
git branch                       # list branches, * marks current one
git branch feature-login          # create a branch (doesn't switch to it)
git checkout feature-login        # switch to it
git checkout -b feature-signup    # create AND switch in one command
```

```bash
echo "signup feature code" > signup.txt
git add signup.txt
git commit -m "Add signup feature"

git checkout main
ls    # signup.txt does NOT exist here - proof branches are isolated
```

---

## 6. Merging

```bash
git checkout main
git merge feature-signup
ls    # signup.txt now appears on main

git log --oneline --graph --all    # visualize branch history
```

**Real workflow this maps to:** `main` = stable/deployed code,
`feature-xyz` = isolated work, developed and tested separately, merged back
once ready.

---

## 7. Merge Conflicts

**Why they happen:** two branches changed the SAME line of the SAME file
differently — Git has no way to know which version is logically correct, so
it forces a human decision rather than silently guessing and potentially
introducing a bug.

```bash
# main has: "main branch line"
# conflict-branch has: "conflict branch line"
# same file, same line, different content

git merge conflict-branch    # → CONFLICT
```

File shows:
```
<<<<<<< HEAD
main branch line
=======
conflict branch line
>>>>>>> conflict-branch
```

- Between `<<<<<<< HEAD` and `=======` → current branch's version
- Between `=======` and `>>>>>>> branch-name` → incoming branch's version

**Resolution:** manually edit the file, delete the conflict markers, keep
whichever content (or combine both) makes sense, then:
```bash
git add conflict-demo.txt
git commit -m "Resolve merge conflict in conflict-demo.txt"
```

---

## 8. Remote Repositories — Connecting to GitHub

Everything above was local-only. GitHub is a remote, hosted copy.

```bash
git remote -v                                              # list connected remotes
git remote add origin https://github.com/user/repo.git     # connect a remote
git push -u origin main                                     # push + set tracking
git push                                                     # works without extra args after -u
git pull origin main                                         # pull down remote changes
```

`origin` is just a conventional name for "the main remote" — not a special
keyword, just the universal default everyone uses.

```bash
git clone https://github.com/user/repo.git
```
Downloads the entire commit history, not just current files.

---

## 9. .gitignore — What NOT to Track

**Problem:** secrets, API keys, system junk files, and huge binaries should
never be committed — especially to a public repo.

```bash
# .gitignore
*.log
.env
node_modules/
__pycache__/
```

Files matching these patterns stop appearing as "untracked" — Git ignores
them for tracking purposes entirely. Critical real-world habit: accidentally
committing API keys/passwords to a public GitHub repo is a common,
career-relevant mistake this directly prevents.

---

## 10. Real Bug This Session Explained Retroactively

Earlier in the journey, several commits showed:
```
1 file changed, 0 insertions(+), 0 deletions(-)
```
and nothing appeared when checking the file. At the time this looked like a
Markdown rendering issue. With the staging/commit mechanics now understood
properly, the actual cause is clear: **the files were genuinely empty when
staged** — `touch`'d but never written to before `git add`. Git's insertion
count was accurate the whole time; the gap was not understanding what that
number meant yet.

**Verified by reproducing intentionally:**
```bash
touch empty-file.txt
git add empty-file.txt
git commit -m "Add empty file"        # → 0 insertions(+), 0 deletions(-) — correct, file IS empty

echo "real content here" > empty-file.txt
git add empty-file.txt
git commit -m "Add real content"       # → 1 insertion(+) — confirms content actually saved
```

**Habit going forward:** check the insertions/deletions count after every
commit. If it shows 0 when real content was expected, that's the exact
signal something didn't save the way intended — catch it immediately rather
than discovering it later on GitHub's website.

---

## Status: Git & GitHub — Complete
Next: Docker (then AWS, Terraform, Kubernetes — tightening pace from here)
