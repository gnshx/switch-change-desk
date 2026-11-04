# Change Desk — Submission

**Hackathon:** Switch Hackathon  
**Track:** Main + Wispr Flow side track + #HowISwitch blog  
**Submitted by:** [your name]  
**Date:** 2026-11-07

---

## Project Summary

**Name:** Change Desk  
**Tagline:** Every AI-assisted change, with a full paper trail. Plan → Review → Approve → Execute → Evidence.  
**Repo:** [https://github.com/YOUR_USERNAME/switch-change-desk](#) ← update  
**Video:** [YouTube / Loom link](#) ← update after recording  
**Blog:** [link to #HowISwitch post](#) ← update  
**Wispr Flow screenshot:** `demo/wispr-flow-screenshot.png` ← add before submitting

---

## Switch Features Used

| Feature | How Used |
|---------|---------|
| **Agent access setting: Owner only** | Executor agent is locked to room owner. Non-owner messages are refused by Switch before delivery. |
| **Room knowledge** | `policy/change-policy.md` is attached to the room. All agents see the rules without being re-prompted. |
| **Agent system instructions** | Each agent (`planner.md`, `reviewer.md`, `executor.md`) has a dedicated instruction file loaded as its system prompt. |
| **Room history** | Auditor can read the room to reconstruct the full story. |

---

## Judging Criteria — Self Assessment

| Criterion | Score (self) | Evidence |
|-----------|-------------|---------|
| **Use of Switch** | ★★★★★ | Owner-only executor is the core feature; exact setting documented in README |
| **Technical execution** | ★★★★★ | Judge can reproduce in ≤ 10 min from README; gate tested with 5 cases |
| **Creativity and impact** | ★★★★☆ | Opens with real cost of unreviewed changes; shows "no" paths prominently |
| **Presentation** | ★★★★☆ | Architecture diagram, tight README, 2.5-min video |
| **Wispr Flow side track** | ★★★★☆ | Used for dictating prompts, instructions, and README (screenshot saved) |

---

## Submission Checklist

### Code
- [ ] All scripts executable (`chmod +x`)
- [ ] `demo/reset.sh` runs clean
- [ ] `tools/test_gate.sh` — all 5 tests PASS
- [ ] `demo/run_happy_path.sh` — exits 0
- [ ] `demo/run_tamper_beat.sh` — exits 0 (gate refused as expected)
- [ ] Evidence folder empty (no test artifacts)
- [ ] `.gitignore` excludes CHG-* evidence dirs

### Documentation
- [ ] `README.md` is self-contained (no broken links, no placeholder text)
- [ ] Video link added to README
- [ ] Switch settings section accurate
- [ ] Architecture diagram renders correctly
- [ ] Exact `sha256sum` command shown for hash computation

### Demo
- [ ] Two clean runs recorded
- [ ] Tamper beat: HASH MISMATCH shown clearly on screen
- [ ] Outsider beat: shown or explicitly skipped with honest note
- [ ] Auditor beat: `ls evidence/` and `cat approval.txt` on screen
- [ ] Video ≤ 2:30

### Side tracks
- [ ] Wispr Flow screenshot saved as `demo/wispr-flow-screenshot.png`
- [ ] Blog post published
- [ ] #HowISwitch post published

### Final git
- [ ] All files committed
- [ ] `git log --oneline` shows clean phase commits
- [ ] Pushed to public GitHub repo
- [ ] Repo URL added to submission form
