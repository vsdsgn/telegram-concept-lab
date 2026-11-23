"""Offline checks for real-client experiments: never use actual Telegram sources."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import native


def git(path,*args):
    r=subprocess.run(['git',*args],cwd=path,text=True,capture_output=True)
    if r.returncode: raise AssertionError(r.stderr)
    return r.stdout.strip()


class NativePipelineTest(unittest.TestCase):
    def test_real_repos_are_isolated_and_not_pushed(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            sources={}
            for plat in ('ios','android'):
                src=root/('Telegram-'+plat)
                src.mkdir()
                git(src,'init','-b','main')
                git(src,'config','user.name','Test')
                git(src,'config','user.email','test@example.invalid')
                (src/'Readme.txt').write_text('genuine source fixture')
                git(src,'add','.')
                git(src,'commit','-m','initial')
                git(src,'switch','-c','concept-lab/reaction-wheel')
                sources[plat]=src
            original=(native.STATE,native.JOBS,native.SOURCES)
            native.STATE=root/'lab/native'
            native.JOBS=native.STATE/'jobs.json'
            native.SOURCES=sources
            try:
                with mock.patch.object(native,'validate_source',side_effect=lambda p: sources[p]):
                    paths=native.prepare('feature-test','Reaction interaction concept')
                for plat in ('ios','android'):
                    self.assertEqual(git(paths[plat],'branch','--show-current'),'concept-lab/feature-test')
                    self.assertEqual(git(sources[plat],'branch','--show-current'),'concept-lab/reaction-wheel')
                    self.assertEqual(git(paths[plat],'status','--porcelain'),'')
                spec=native.STATE/'feature-test/SPEC.md'
                self.assertIn('Reaction interaction',spec.read_text())
                self.assertFalse((paths['ios']/'SPEC.md').exists())
                self.assertEqual(native.registry()['feature-test']['phase'],'prepared')
            finally:
                native.STATE,native.JOBS,native.SOURCES=original

    def test_protect_test_backend_and_auth(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            git(root,'init')
            git(root,'config','user.name','Test')
            git(root,'config','user.email','test@example.invalid')
            (root/'NormalUI.swift').write_text('initial')
            (root/'AppDelegate.swift').write_text('testdc')
            git(root,'add','.')
            git(root,'commit','-m','base')
            (root/'NormalUI.swift').write_text('new')
            self.assertEqual(native.inspect_source_changes('ios',root),['NormalUI.swift'])
            (root/'AppDelegate.swift').write_text('unsafe')
            with self.assertRaisesRegex(RuntimeError,'protected source edit'):
                native.inspect_source_changes('ios',root)

if __name__ == '__main__': unittest.main()
