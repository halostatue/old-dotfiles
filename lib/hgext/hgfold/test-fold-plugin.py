#coding: utf-8
"""Exercise the fold plugin.

Jargon:
CF = case-folding
CFFS = case-folding file system
"""

from os import chdir, getcwd, makedirs, mkdir, system, tempnam
from distutils.dir_util import remove_tree
from os.path import abspath, dirname, exists, join
from subprocess import Popen

class hg(object):

    def __init__(self):
        self.cwd = None #current working directory
        self.cmdbase = "hg %s"

    def hg(self,hgcmd):
        """run mercurial from the commandline"""
        cmd = self.cmdbase % hgcmd
        print "RUNNING: %s." % cmd
        #~ p = Popen(cmd, cwd=self.cwd)
        #~ p.wait()
        system(cmd)

class testSet(hg):
    def __init__(self):
        hg.__init__(self)
        self.root = dirname( abspath( __file__))
        self.cmdbase = 'hg --config "extensions.fold=%s" %%s' % join(self.root,"fold.py")
        self.testroot = join( self.root, "testdata")
        self.repoA = join(self.testroot, "alpha")
        self.repoB = join(self.testroot, "beta")
        self.setrepo(self.repoA)

    def clean(self):
        """Remove byproducts of testing"""
        chdir(self.root)
        if exists( self.testroot):
            remove_tree(self.testroot)

    def setrepo(self, repo):
        self.cwd = repo
        if exists(repo):
            chdir( repo)

    def makerepos(self):
        self.clean()
        makedirs( self.repoA)
        self.setrepo(self.repoA)
        self.hg("init -v")
        self.write("test.txt", """This is a
            simple text file
            to test merging
            and folding.
            """
        )
        self.hgcommit("Adding simple file test.txt.")
        chdir(self.testroot)
        self.hg("clone %s %s" % (self.repoA, self.repoB))
        chdir(self.root)

    def write(self, filename, text):
        lines = [x.strip() for x in text.split("\n")]
        text = "\n".join(lines)
        f = file(filename,'w')
        try:
            f.write(text)
        finally:
            f.close()

    def hgcommit( self, message):
        self.hg("addrem")
        # message in single quotes fails on windows
        self.hg('ci -u tests -m "%s"' % message)

    def hgmove(self, source, dest):
        tmp = source + ".temp"
        self.hg("rename %s %s" % (source, tmp))
        self.hgcommit("moving %s to temp file" % source)
        self.hg("rename %s %s" % (tmp, dest))
        self.hg("finished moving %s to %s" % (source, dest))

    def jam(self):
        """Create a filename folding situation that is normally impossible
        to update on a CFFS file system. repoB will have a changeset that
        has a conflicting filename."""
        self.makerepos()
        txt = """This is some
            more sample text
            to see if we can merge
            a filename collision
            conflict"""
        chdir(self.repoA)
        self.write("another.txt", txt)
        self.hgcommit("Adding another.txt")
        chdir(self.repoB)
        self.write("Another.txt", txt)
        self.hgcommit("Adding Another.txt")
        self.hg( "pull")
        self.hg( "merge")
        self.hgcommit( "This merge causes a filename collision on case-folding file systems. Try hg up to see the problem.")
        chdir(self.root)

    def resolve(self):
        chdir(self.repoB)
        self.hg("up --fold")
        self.hgcommit("resolved case-folding merge")
        self.hg("status -v")
        chdir(self.root)

def runAllTests():
    pass

tests = testSet()
tests.jam()
tests.resolve()
