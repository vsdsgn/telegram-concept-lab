"""Offline integration checks: no LLM calls, public pushes, or external network."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import collab

def git(cwd, *args):
    p = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if p.returncode: raise AssertionError(p.stderr)
    return p.stdout.strip()

class CollaborativeTest(unittest.TestCase):
    def test_sandboxed_invocations(self):
        with tempfile.TemporaryDirectory() as tmp:
            for agent, readonly in (("codex", False), ("claude", True)):
                with mock.patch.object(collab.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as call:
                    collab.tool(agent, Path(tmp), "Review only", Path(tmp) / f"{agent}.log", readonly=readonly)
                    argv = call.call_args.args[0]
                    self.assertNotIn("--dangerously-bypass-approvals-and-sandbox", argv)
                    if agent == "codex": self.assertIn("--approve-for-me", argv)
                    else: self.assertIn("plan", argv)

    def test_both_platforms_have_cross_review(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            git(root, "init", "-b", "main")
            git(root, "config", "user.name", "Test")
            git(root, "config", "user.email", "test@invalid.local")
            spec = root/"concepts/sample/SPEC.md"
            spec.parent.mkdir(parents=True)
            spec.write_text("Public fixture")
            git(root, "add", ".")
            git(root, "commit", "-m", "base")
            trees = root/".lab/worktrees/sample"
            for plat in ("design", "ios", "android"):
                dest = trees/plat
                dest.parent.mkdir(parents=True, exist_ok=True)
                git(root, "worktree", "add", "-b", f"concept/sample/{plat}", str(dest), "main")
            previous = collab.ROOT, collab.STATE, collab.TASKS
            try:
                collab.ROOT = root
                collab.STATE = root/".lab"
                collab.TASKS = root/".lab/jobs.json"
                collab.save({"sample":{"mode":"collaborative","phase":"queued","platforms":{p:{"agent":"codex","branch":f"concept/sample/{p}","worktree":str(trees/p)} for p in ("ios","android")}}})
                seen=[]
                def fake_stage(slug, name, agent, cwd, prompt, readonly=False, report=None):
                    seen.append((name, agent, readonly))
                    collab.update(slug, phase=name)
                    shared = cwd/"concepts/sample"
                    if name=="design":
                        (shared/"UX_DESIGN.md").write_text("Claude draft")
                    elif name=="design-review":
                        self.assertTrue((shared/"UX_DESIGN.md").exists())
                        (shared/"DESIGN_REVIEW.md").write_text("Codex critique")
                    elif name=="design-revise":
                        (shared/"UX_DESIGN.md").write_text("Claude refined")
                    elif name.startswith("build-"):
                        self.assertEqual((shared/"UX_DESIGN.md").read_text(), "Claude refined")
                        self.assertTrue((shared/"DESIGN_REVIEW.md").exists())
                        p = shared/name.replace("build-","")
                        p.mkdir(parents=True, exist_ok=True)
                        (p/"app.txt").write_text("Codex code")
                    elif name.startswith("review-"):
                        self.assertEqual(agent, "claude")
                        self.assertTrue(readonly)
                        report.parent.mkdir(parents=True, exist_ok=True)
                        report.write_text("Claude QA")
                    elif name.startswith("fix-"):
                        p=shared/name.replace("fix-","")
                        self.assertEqual((p/"CLAUDE_REVIEW.md").read_text(), "Claude QA")
                        (p/"app.txt").write_text("Codex fixed")
                    git(cwd,"add",".")
                    if git(cwd,"status","--porcelain"):
                        git(cwd,"commit","-m",name)
                with mock.patch.object(collab, "stage", side_effect=fake_stage):
                    self.assertEqual(collab.run_pipeline("sample"),0)
                self.assertEqual(len(seen),9)
                self.assertEqual(sum(agent=="claude" for _,agent,_ in seen),4)
                self.assertEqual(sum(agent=="codex" for _,agent,_ in seen),5)
                self.assertEqual(collab.get_jobs()["sample"]["phase"],"complete")
                for platform in ("ios","android"):
                    self.assertEqual((trees/platform/"concepts/sample"/platform/"app.txt").read_text(),"Codex fixed")
                self.assertEqual((root/".lab/logs/sample/pipeline.exit").read_text(),"0")
            finally:
                collab.ROOT, collab.STATE, collab.TASKS = previous
if __name__=="__main__": unittest.main()
