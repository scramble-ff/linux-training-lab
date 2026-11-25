"""Integration tests for the generated runner. Each test owns a temporary HOME."""
import os
from pathlib import Path
import select
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "lab.sh"


class LabTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="beginnix test ")
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)
        self.root = self.home / ".linux-training-lab"
        self.env = dict(os.environ, HOME=str(self.home), LAB_SHELL="bash",
                        TERM="dumb", NO_COLOR="1")
        for name in ("LINUX_LAB_PRACTICE_ID", "BEGINNIX_TERMINAL_DIR", "BASH_ENV", "ENV"):
            self.env.pop(name, None)

    def runner(self, *args, stdin="", success=True):
        result = subprocess.run(["bash", SCRIPT, *args], input=stdin, text=True,
                                cwd=self.home, env=self.env, capture_output=True, timeout=15)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def lesson(self, number):
        return self.root / "lessons" / f"{number:02}"

    def test_retry_after_partial_preparation(self):
        self.runner("setup", "--jump", "13")
        logfile = self.lesson(13) / "records/archive/dispatch.log"
        flag = next(row.split()[-1] for row in logfile.read_text().splitlines()
                    if "TICKET-1042" in row)
        commands = self.home / "commands"
        commands.mkdir()
        broken_zip = commands / "zip"
        broken_zip.write_text("#!/bin/sh\nexit 23\n")
        broken_zip.chmod(0o755)
        self.env["PATH"] = f"{commands}:{self.env['PATH']}"
        failure = self.runner("submit", flag, success=False)
        self.assertIn("Progress saved", failure)
        self.assertFalse(self.lesson(14).exists())
        self.assertIn("1 independent", self.runner("stats"))
        self.runner("save")
        broken_zip.unlink()
        self.assertIn("Open the shipment", self.runner("current"))
        self.assertTrue((self.lesson(14) / "sealed.zip").is_file())
        self.assertIn("already accepted", self.runner("submit", flag, success=False))

    def test_script_feedback(self):
        for number, name, body, expected in (
            (28, "label.sh", 'printf "%s: %s\\n" "${1%% *}" "$2"', "West Gate: BOX-003"),
            (29, "decision.sh", "echo wrong; exit 5", "Command exit status: 5"),
            (30, "queue.sh", "echo wrong", "Queued: west gate"),
            (31, "ready.sh", "echo wrong > ready-ids.txt", "Actual ready-ids.txt:\nwrong"),
            (32, "states.awk", 'END {print "wrong"}', "Actual sorted output:\nwrong"),
        ):
            with self.subTest(number=number):
                self.runner("setup", "--jump", str(number))
                folder = self.lesson(number)
                script = folder / name
                script.write_text("#!/bin/bash\n" + body + "\n")
                script.chmod(0o700)
                result = self.runner("submit", (folder / "dispatch.txt").read_text().strip(),
                                     success=False)
                for text in (name, expected, "Expected ", "Actual "):
                    self.assertIn(text, result)
                self.assertIn("Incorrect submissions: 0", self.runner("stats"))
                self.runner("teardown")

    def test_final_lesson(self):
        self.runner("setup", "--jump", "38")
        folder = self.lesson(38)
        for row in (folder / "access.log").read_text().splitlines()[1:]:
            shift, decision, path, role = row.split("|")
            if shift == "NIGHT" and decision == "APPROVED":
                (folder / path).chmod({"REVIEW": 0o400, "TEAM_READ": 0o640, "TEAM_EDIT": 0o660}[role])
        result = self.runner("submit", (folder / "dispatch.txt").read_text().strip())
        self.assertIn("complete", result)
        self.assertNotIn("Choice [1]", result)
        self.assertIn("Solved: 1 / 1", self.runner("stats"))

    def test_practice_and_teardown(self):
        self.runner("setup")
        self.runner("setup", "--jump", "4")
        practice = self.root / (".practice." + (self.root / ".last-practice").read_text().strip())
        (practice / "lessons/04/unfinished.txt").touch()
        menu = self.runner("setup")
        self.assertIn("Resume last practice", menu)
        resumed = self.runner("setup", stdin="4\npwd\nexit\n")
        self.assertIn(str(practice / "lessons/04"), resumed)
        self.assertTrue((practice / "lessons/04/unfinished.txt").is_file())
        self.runner("save")
        self.runner("--import-launch-save")
        self.assertTrue(list(self.root.glob(".previous.*/lab/.last-practice")))

        # Simulate a backup from version 29 and a similarly named user directory.
        legacy = self.home / ".beginnix-previous.abcdef"
        shutil.copytree(self.root, legacy / "lab")
        unrelated = self.home / ".beginnix-previous.123456"
        unrelated.mkdir()
        self.runner("teardown")
        self.assertEqual(set(self.home.iterdir()), {unrelated, self.home / "beginnix-progress.txt"})
        self.runner("setup", "--resume", str(self.home / "beginnix-progress.txt"))
        self.assertIn("Solved: 0 / 38", self.runner("stats"))

    def test_puzzle_objectives_and_walkthroughs(self):
        self.runner("setup", "--puzzles")
        self.assertIn("0/6 puzzles completed", self.runner("setup"))
        for number in range(33, 39):
            with self.subTest(number=number):
                folder = self.lesson(number)
                before = self.runner("check", success=False)
                self.assertIn("[ ]", before)
                if number == 33:
                    self.assertIn("[x] Preserve both warehouse originals", before)
                    self.runner("check", success=False)
                    self.assertIn("demonstrated: 1 / 14", self.runner("stats"))
                walkthrough = self.runner("answer")
                example = walkthrough.split("\n\n", 2)[2].split("\n\n", 1)[0]
                subprocess.run(["bash", "-ec", example], cwd=folder, env=self.env,
                               capture_output=True, check=True)
                self.assertIn("Ready.", self.runner("check"))
                if number == 35:
                    archive = folder / "recovery.tar.gz"
                    original = archive.read_bytes()
                    archive.write_bytes(b"damaged")
                    feedback = self.runner("submit", success=False)
                    self.assertIn("[ ] Preserve archive integrity", feedback)
                    self.assertIn("[x] Recover the verified note", feedback)
                    archive.write_bytes(original)
                self.assertIn("Completed with walkthrough", self.runner("submit"))
        self.assertIn("6/6 puzzles completed", self.runner("setup"))
        self.assertIn("demonstrated: 14 / 14", self.runner("stats"))
        self.runner("save")
        self.runner("teardown")
        self.runner("setup", "--resume", str(self.home / "beginnix-progress.txt"))
        self.assertIn("demonstrated: 14 / 14", self.runner("stats"))

    def test_restart_preview_and_restore_partial_credit(self):
        self.runner("setup", "--jump", "35")
        folder = self.lesson(35)
        (folder / "my-notes").write_text("keep this")
        preview = self.runner("restart")
        self.assertIn("restart --confirm", preview)
        self.assertFalse((self.root / "previous-attempts").exists())
        self.runner("answer")
        self.runner("check", success=False)
        self.runner("restart", "--confirm")
        backup, = (self.root / "previous-attempts").glob("*/attempt/my-notes")
        self.assertEqual(backup.read_text(), "keep this")
        self.assertFalse((folder / "my-notes").exists())
        before = self.runner("stats")
        self.assertIn("Walkthrough opened", before)
        self.assertIn("demonstrated: 1 /", before)
        self.runner("save")
        self.runner("teardown")
        self.runner("setup", "--resume", str(self.home / "beginnix-progress.txt"))
        self.assertIn("demonstrated: 1 /", self.runner("stats"))

    def test_legacy_checkpoint_and_independent_replay(self):
        legacy = self.home / "beginnix-progress.txt"
        legacy.write_text("BEGINNIX-CHECKPOINT-1\n" + "a" * 32
                          + " 5 2 0 2 0 1 ,1,\n,1,\n")
        self.runner("setup", "--resume", str(legacy))
        self.assertIn("0 independent, 1 with walkthrough", self.runner("stats"))
        self.runner("setup", "--jump", "1")
        practice_id = (self.root / ".last-practice").read_text().strip()
        self.env["LINUX_LAB_PRACTICE_ID"] = practice_id
        first = self.root / (".practice." + practice_id) / "lessons/01/supplies/note.txt"
        self.runner("submit", "typo", success=False)
        self.runner("submit", first.read_text().strip())
        del self.env["LINUX_LAB_PRACTICE_ID"]
        self.assertIn("1 independent, 0 with walkthrough", self.runner("stats"))
        self.assertIn("Challenge 02", self.runner("current"))
        self.runner("save")
        self.assertTrue(legacy.read_text().startswith("BEGINNIX-CHECKPOINT-2\n"))
        self.runner("teardown")
        self.runner("setup", "--resume", str(legacy))
        self.assertIn("1 independent", self.runner("stats"))

    def test_upgrading_an_unfinished_archive_lesson(self):
        self.runner("setup", "--jump", "35")
        folder = self.lesson(35)
        # Version 30 kept neither a checksum nor per-objective state.
        (folder / ".original.sha256").unlink()
        (folder / ".seeded-puzzle").unlink()
        (folder / "my-note").write_text("unfinished")
        (self.root / ".lesson-prompts-v31").unlink()
        state = self.root / "state"
        state.write_text(" ".join(state.read_text().split()[:9]) + "\n")
        (self.root / ".linux-lab-install").write_text("30\n")
        self.runner("setup")
        self.assertEqual((folder / "my-note").read_text(), "unfinished")
        self.assertIn("older lesson has no original checksum", self.runner("check", success=False))
        self.runner("restart", "--confirm", "35")
        self.assertIn("[x] Preserve archive integrity", self.runner("check", success=False))
        kept, = (self.root / "previous-attempts").glob("*/attempt/my-note")
        self.assertEqual(kept.read_text(), "unfinished")

    def test_guided_revisions(self):
        self.runner("setup", "--jump", "3")
        self.assertIn("dispatch.log", self.runner("current"))
        self.assertIn("Discovery", self.runner("check"))
        count = sum(line.startswith("WARN") for line in (self.lesson(3) / "dispatch.log").read_text().splitlines())
        self.runner("submit", f"FLAG{{r-c-{count}}}")
        self.runner("teardown")
        self.runner("setup", "--jump", "25")
        folder = self.lesson(25)
        port = next(row.split()[3].split(":")[1] for row in (folder / "sockets.txt").read_text().splitlines()
                    if row.startswith("LISTEN") and row.split()[3].startswith("127.0.0.1"))
        (folder / "listener.txt").write_text(port)
        self.assertIn("checks passed", self.runner("check"))
        self.runner("submit", (folder / "dispatch.txt").read_text().strip())

    def test_neon_arcade_stats(self):
        self.runner("setup")
        order = (self.root / ".course-layout").read_text().split()
        self.runner("teardown")
        checkpoint = self.home / "arcade.txt"
        def checkpoint_for(solved, current, objectives):
            completed = "," + "".join(lesson + "," for lesson in order[:solved])
            checkpoint.write_text(
                "BEGINNIX-CHECKPOINT-2\n" + "a" * 32
                + f" 11520 {current} 0 5 0 1 {completed}\n,1,2,\n{objectives}\n,\n")
            self.runner("setup", "--resume", str(checkpoint))

        first_seven = ",27.1,27.2,27.3,29.1,29.2,30.1,30.2,"
        checkpoint_for(34, order[34], first_seven)
        self.env.update(TERM="xterm-256color", LC_ALL="C.UTF-8")
        self.env.pop("NO_COLOR", None)
        def terminal_stats(columns=80, option=""):
            result = subprocess.run(
                ["script", "-qec", f"stty cols {columns}; bn stats {option}", "/dev/null"],
                cwd=self.home, env=dict(self.env, PATH=f"{self.root}/bin:{self.env['PATH']}"),
                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=5, check=True)
            return result.stdout

        arcade = terminal_stats()
        for item in ("✦ BEGINNIX ARCADE ✦", "89%", "34 / 38", "Report dock and pallet count",
                     "7 / 14", "NEXT OBJECTIVE", "bn stats --details", "┏━┓", "Independent guided clears"):
            self.assertIn(item, arcade)
        for color in (81, 213, 221):
            self.assertIn(f"\x1b[1;38;5;{color}m", arcade)
        self.assertIn("Puzzle checklist\n", terminal_stats(option="--details"))
        self.env["NO_COLOR"] = "1"
        compact = terminal_stats(columns=32)
        self.assertNotIn("\x1b[", compact)
        self.assertNotIn("┏━┓", compact)
        self.assertIn("89%", compact)
        self.assertNotIn("\x1b[", self.runner("stats"))
        self.runner("teardown")

        all_objectives = first_seven + "30.3,28.1,28.2,37.1,37.2,38.1,38.2,"
        checkpoint_for(38, "0", all_objectives)
        finished = self.runner("stats")
        for item in ("Course cleared!", "100%", "ALL 6 PUZZLES CLEARED", "Every objective demonstrated!"):
            self.assertIn(item, finished)
        self.assertNotIn("NEXT OBJECTIVE", finished)

    def test_course_options_and_plain_menu(self):
        self.runner("setup", "--puzzles")
        menu = self.runner("setup", stdin="5\n1\n\n8\n")
        self.assertIn("  5  Course options", menu)
        self.assertIn("Puzzle objectives demonstrated:", menu)
        self.assertNotIn("\x1b[", menu)
        self.runner("setup", stdin="5\n3\n2\n8\n")
        self.assertTrue((self.root / ".auto-move").exists())
        self.runner("setup", stdin="5\n3\n1\n8\n")
        self.assertFalse((self.root / ".auto-move").exists())
        self.runner("setup", stdin="5\n2\n1\n8\n")
        self.assertFalse((self.root / "previous-attempts").exists())
        self.runner("restart", "--confirm", "34", success=False)
        self.assertFalse((self.root / "previous-attempts").exists())

    def exercise_navigation(self, shell):
        self.env["LAB_SHELL"] = shell
        self.env["TERM"] = "xterm-256color"
        self.env.pop("NO_COLOR", None)
        # util-linux script supplies the same controlling TTY as a real launch.
        with subprocess.Popen(["script", "-qec", f"bash {shlex.quote(str(SCRIPT))} setup --training",
                               "/dev/null"], cwd=self.home, env=self.env,
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT) as proc:
            pending = b""

            def expect(text):
                nonlocal pending
                marker = text.encode()
                deadline = time.monotonic() + 8
                while marker not in pending:
                    left = deadline - time.monotonic()
                    self.assertTrue(left > 0 and select.select([proc.stdout], [], [], left)[0],
                                    (text, pending))
                    chunk = os.read(proc.stdout.fileno(), 8192)
                    self.assertTrue(chunk, (text, pending))
                    pending += chunk
                pending = pending.split(marker, 1)[1]

            def send(line):
                proc.stdin.write((line + "\n").encode())
                proc.stdin.flush()

            try:
                expect("exit for the menu.")
                send("touch scratch-note && bn restart --confirm")
                expect("Previous attempt:")
                expect("Challenge 01")
                send('test ! -e scratch-note && submit "$(cat supplies/note.txt)"')
                expect("Choice [1]")
                send("1")
                expect("Challenge 02")
                send('bn -s "$(cat .dispatch/morning-dispatch-for-the-training-crew.txt)"')
                expect("Choice [1]")
                send("2")
                expect("Staying here")
                send('printf "still-in-%s\\n" "${PWD##*/}"')
                expect("still-in-02")
                send("lab --submit 'FLAG{r-c-3}'")
                expect("Choice [1]")
                send("3")
                expect("Challenge 04")
                send('mkdir staging && touch staging/arrival.txt && beginnix submit "$(cat dispatch.txt)"')
                expect("Challenge 05")
                send('printf "arrived-in-%s\\n" "${PWD##*/}"')
                expect("arrived-in-05")
                send("exit")
                expect("\x1b[7;1m > Continue course")
                send("")  # Reopen the course in a fresh shell.
                expect("exit for the menu.")
                send("cp manifest.txt backup.txt && mv draft.txt ready.txt")
                send("sh")
                send('bn submit "$(cat dispatch.txt)"')
                expect("Progress saved.")
                send("exit")  # The parent lesson shell picks up the child submission.
                expect("Challenge 06")
                send('printf "reopened-in-%s\\n" "${PWD##*/}"')
                expect("reopened-in-06")
                send("exit")
                expect("Continue course")
            finally:
                proc.terminate()
                proc.wait(timeout=10)
        self.assertTrue((self.root / ".auto-move").exists())
        self.runner("move", "ask")
        self.assertFalse((self.root / ".auto-move").exists())
        self.assertFalse((self.home / ".bash_history").exists())
        self.assertFalse(list(self.root.glob(".terminal.*")))

    def test_bash_navigation(self):
        self.exercise_navigation("bash")

    @unittest.skipUnless(shutil.which("zsh"), "zsh unavailable")
    def test_zsh_navigation(self):
        self.exercise_navigation("zsh")


if __name__ == "__main__":
    unittest.main()
