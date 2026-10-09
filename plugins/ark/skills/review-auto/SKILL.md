---
name: review-auto
description: Fetch PR review comments, address them, and push the fixes without stopping for approval — applies its own triage of each comment, including structural fixes and declines, then replies to each thread. Use when asked to address review feedback hands-off or automatically. For a run that proposes the fixes and waits for feedback first, use ark:review.
---

Follow the `ark:review` procedure in `../review/SKILL.md` (relative to this skill's directory), in **auto mode**:

- Skip step 4 (propose the plan and wait for feedback). Act on your own step 3 triage — apply straightforward fixes, make structural fixes where the suggested patch is wrong for the PR, and decline comments that conflict with the PR's design, explaining each divergence or decline in the thread reply.
- Do not stop to ask about unclear comments or significant disagreements; leave the code unchanged for those and surface them in the step 9 summary.
- Everything else is unchanged: the holistic pass, the one-time `ark:polish` offer when the fixes reshaped the PR, the single pending review for replies, and the pending-comment sanity check.
