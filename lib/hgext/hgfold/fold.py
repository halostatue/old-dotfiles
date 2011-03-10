#coding: utf-8
"""merge filename case collisions on NTFS or VFAT

Copyright 2009. Brad Olson.

This software may be used and distributed according to the terms
of the GNU General Public License, incorporated herein by reference.

No warrantees, express or implied, are made on this software. I only put my copyright atop
to assert the GPL. You can reach me at brado@movedbylight.com.

Contributors:
Mercurial Wiki - analysis and discussion of the case-folding problem (initiated by MPM).
Brad Olson - folding plan and prototype plugin.
Steve Borho - docstring formatting and syntax fix.
Stefan Richter - update for Mercurial 1.6.

-----COMMAND LINE DESCRIPTION-----

hg update --fold #reflexive fold, lets NTFS folks update to a changeset with collisions

hg merge --fold  #merge fold, lets you carry out a merge when the 2nd head produces collisions.


----- FUTURE DIRECTIONS -----
It would be nice if:

hg clone --fold         #if clone fails to update local repo because of local collisions, uses update --fold
hg init --fold          #adds fold to requires, then all affected commands presume --fold OR
.hgfold                 #signals case-folding project, list preferred forms of filenames in order
hg ci --fold            #coerces filenames on manifest to exact case in manifest
hg add/addrem --fold    #collissions are treated like trying to add files already on manifest
hg rename --fold        #prevent renaming to a name that would collide
"""
import sys, os, os.path, errno
from mercurial.i18n import _, gettext
import mercurial
from mercurial import cmdutil, commands, context, filemerge, merge, node, revlog, util
#~ import rpdb2; rpdb2.start_embedded_debugger("pw")

"""------------ CODE FROM mercurial.merge (KEEP THIS AS IN SYNC AS POSSIBLE) ------------
Here's the dilemma, Hg's core merge code is written in a very functional style, which is great.
But to better handle filename collisions, we need to adjust how the main merge routine,
mercurial.merge.update, acts. Since it's not a class, we can't override behavior. And since
this code is so central to core mercurial commands (hg update, hg merge), we want this to act
as much like hg's code as possible.

So...until it's clearer what/if the community wants to do about filename collisions, it seems
safest to include a slightly hacked version here. See the docstring for notes


"""
def hgupdate(repo, node, branchmerge, force, partial):
    """Slightly hacked mercurial.merge.update()
    (To see changes, diff it with version 1.1.2. Please keep this version number up-to-date
    if you change the derived version.)

    Perform a merge between the working directory and the given node

    node = the node to update to, or None if unspecified
    branchmerge = whether to merge between branches
    force = whether to force branch merging or file overwriting
    partial = a function to filter file lists (dirstate not updated)

    The table below shows all the behaviors of the update command
    given the -c and -C or no options, whether the working directory
    is dirty, whether a revision is specified, and the relationship of
    the parent rev to the target rev (linear, on the same named
    branch, or on another named branch).

    This logic is tested by test-update-branches.

    -c -C dirty rev | linear same cross
    n n n n | ok (1) x
    n n n y | ok ok ok
    n n y * | merge (2) (2)
    n y * * | --- discard ---
    y n y * | --- (3) ---
    y n n * | --- ok ---
    y y * * | --- (4) ---

    x = can't happen
    * = don't-care
    1 = abort: crosses branches (use 'hg merge' or 'hg update -c')
    2 = abort: crosses branches (use 'hg merge' to merge or
    use 'hg update -C' to discard changes)
    3 = abort: uncommitted local changes
    4 = incompatible options (checked in commands.py)
    """

    wlock = repo.wlock()

    try:
        wc = repo[None] ###working copy change context
        if node is None: ###see nothing passing it node
            # tip of current branch
            try:
                node = repo.branchtags()[wc.branch()]
            except KeyError:
                if wc.branch() == "default": # no default branch!
                    node = repo.lookup("tip") # update to tip
                else:
                    raise util.Abort(_("branch %s not found") % wc.branch())
        overwrite = force and not branchmerge
        pl = wc.parents() ###ParentList of working copy
        p1, p2 = pl[0], repo[node] ### MyChangeContext, MergeChangeContet
        pa = p1.ancestor(p2) ### CommonAncestorChangeContext
        fp1, fp2, xp1, xp2 = p1.node(), p2.node(), str(p1), str(p2) ##changeset hashes & short hashes
        fastforward = False

        ### check phase
        if not overwrite and len(pl) > 1: ### wc has multiple parents
            raise util.Abort(_("outstanding uncommitted merges"))
        if branchmerge:
            if pa == p2: ###she is the common ancestor
                raise util.Abort(_("can't merge with ancestor"))
            elif pa == p1: ###me is the common ancestor
                if p1.branch() != p2.branch(): ###...but we are different named branches (usually 'default')
                    fastforward = True ### Merging a branch back into common ancestor
                else:
                    raise util.Abort(_("nothing to merge (use 'hg update'"
                                       " or check 'hg heads')"))
            if not force and (wc.files() or wc.deleted()): ### edits, adds, or mods in wc
                raise util.Abort(_("outstanding uncommitted changes"))
        elif not overwrite:
            if pa == p1 or pa == p2: # linear
                pass # all good
            elif p1.branch() == p2.branch():
                if wc.files() or wc.deleted():
                    raise util.Abort(_("crosses branches (use 'hg merge' or "
                                       "'hg update -C' to discard changes)"))
                raise util.Abort(_("crosses branches (use 'hg merge' "
                                   "or 'hg update -C')"))
            elif wc.files() or wc.deleted():
                raise util.Abort(_("crosses named branches (use "
                                   "'hg update -C' to discard changes)"))
            else:
                # Allow jumping branches if there are no changes
                overwrite = True

        ### calculate phase
        action = []
        if not force:
            merge._checkunknown(wc, p2)
        #~ if not util.checkcase(repo.path):
            #~ _checkcollision(p2)
        action += merge._forgetremoved(wc, p2, branchmerge)
        action += merge.manifestmerge(repo, wc, p2, pa, overwrite, partial)

        ### apply phase
        if not branchmerge: # just jump to the new rev
            fp1, fp2, xp1, xp2 = fp2, mercurial.node.nullid, xp2, ''
        if not partial:
            repo.hook('preupdate', throw=True, parent1=xp1, parent2=xp2)

        stats = merge.applyupdates(repo, action, wc, p2, pa)

        #added: I want to record updates even if partial merge
        #merge.recordupdates(repo, action, branchmerge)

        if not partial:
            repo.dirstate.setparents(fp1, fp2)
            merge.recordupdates(repo, action, branchmerge)
            if not branchmerge and not fastforward:
                repo.dirstate.setbranch(p2.branch())

    finally:
        wlock.release()

    if not partial:
        repo.hook('update', parent1=xp1, parent2=xp2, error=stats[3])
    return stats

class folddest(object):
    """A file context that can read contents from the filelog (history) or the working copy.

    Mercurial deals with versioned files through file context objects. There are 2 types,
    both defined in mercurial.context. Each deals with the contents (and name, attributes,
    etc.) of a file at a particular point in time, aware of its lineage.

    Class filectx deals with files in history. It has changeid's and can read it's
    immutable data from history.

    Class workingfilectx is almost the same, but it reflects the live, possibly uncommitted,
    state of a file in the working copy. It knows about its lineage, but has no changeid
    (and no revision or data node in history). It reads it's mutable data from the working
    copy.

    This is a perfect distinction for a normal merge: you merge another filectx into a
    workingfilectx.

    But folding needs something more. Sometimes, the seemingly correct version is in history.
    Take the extreme case where the working copy has no collisions and you want to merge into
    it a changeset that has a three-way collision. You have to perform 2 merges on a live file
    that doesn't yet exist in the working copy.

    So you need to make the first copy of the data from history (something only a filectx
    can do) but subsequenly read it from disk (something only a workingfilctx can do).

    """

    def __init__(self, filectx):
        """filectx can be a context.filectx or a context.workingfilectx
        if useworking is true, this object acts more like a workingfilectx,
        otherwise it acts more like a filectx."""
        self.original = filectx
        try:
            data = filectx.data() #read from default place, history (filectx) or wc (workingfilectx)
        except:
            data = filectx.filectx(self.parent()).data()
        self.originaldata = data
        if isinstance( filectx, context.workingfilectx):
            self.proxy = filectx #can handle it's own calls except those we override
        else:
            self.proxy = context.workingfilectx(
                filectx._repo, filectx.path(),
                filelog = filectx.filelog()
                )
        #at this point, the folddest should have everything a workingfilectx has
        #except guaranteed live data in the working directory

    def __getattr__( self, name):
        """If we don't define a method, just let the underlying workingfilectx handle it."""
        return getattr( self.proxy, name)

    def parents(self):
        return self.original._repo.dirstate.parents()

    def parent(self):
        #TODO: can be empty list, what then? nullid?
        parents = self.parents()
        if len(parents) < 1:
            return node.nullid
        return parents[0]

    def ancestor(self, other):
        try:
            # This can produce a None result. We want an empty context instead
            fca = self.proxy.ancestor(other)
        except:
            fca = None
        if not fca:
            fca = self.filectx(node.nullid)
        # we also need to make sure the ancestor can give data, even if it's empty
        try:
            dummy = fca.data()
        except revlog.LookupError:
            fca.data = lambda: "" #stub function returning empty string
        return fca

    def data(self):
        try:
            return self.proxy.data() #test: should always read working copy if available
        except:
            return self.originaldata

class foldsource( object):
    """a file to fold from"""
    def __init__(self, filectx):
        """filectx can be a context.filectx or a context.workingfilectx
        if useworking is true, this object acts more like a workingfilectx,
        otherwise it acts more like a filectx."""
        self.original = filectx
        if isinstance( filectx, context.workingfilectx):
            ctx, node, id = self.fakeCtx( filectx)
            self.proxy = context.filectx(filectx._repo, filectx.path(),
                filelog = filectx.filelog(),
                changectx = ctx, changeid = node, fileid = id)
        else:
            self.proxy = filectx

    def fakeCtx(self, wfctx):
        """Given a working file context we want to fold FROM, return appropriate values
        for changectx, changeid, fileid."""
        repo = wfctx._repo #glad mercurial didn't bury this with __!
        def getNull(): #return null contexts
          return repo[node.nullrev], node.nullrev, node.nullid
        try:
            parents = repo.dirstate.parents()
            if len(parents) > 0:
                cid = parents[0] #changectx id
                ctx = repo[cid] #change context
                fid = ctx.filectx(wfctx.path()).filenode() #filenode
            else:
                ctx, cid, fid = getNull()
        except:
            #looking up the fildnode (fid) can fail in cases where an
            #unpreferred fold name occurs only in the working directory
            #could grab the data from working dir, but you can't know it's
            #clean (could have been collided over).
            ctx, cid, fid = getNull()
        return ctx, cid, fid

    def __getattr__( self, name):
        """If we don't define a method, just let the underlying workingfilectx handle it."""
        return getattr( self.proxy, name)

    def parent(self):
        #TODO: can be empty list, what then? nullid?
        parents = self.parents()
        if len(parents) < 1:
            return node.nullid
        return parents[0]

"""------------MERGE STATISTICS, MERGE ACTIONS, MERGE STATE (APPLIES ACTIONS) ------------"""
class mergeStats():
    def __init__(self, stats = [0,0,0,0]):
        """stats can be a mercurial style statlist:
        [updated, merged, removed, unresolved]
        """
        self.updated = stats[0]
        self.merged = stats[1]
        self.removed = stats[2]
        self.unresolved = stats[3]
        self.foldmerged = 0
        self.foldunresolved = 0

    def __str__(self):
        if self.foldmerged or self.foldunresolved:
            folddetail = ((self.foldmerged, _("merged")), (self.foldunresolved, _("unresolved")))
            folddetail = ", ".join( [ _("%d %s") % x for x in folddetail])
            folddetail = "folded (%s)" % folddetail
            statlist = ((self.updated, _("updated")),
                (self.removed, _("removed")),
                (self.foldmerged + self.foldunresolved, folddetail))
        else:
            statlist = ((self.updated, _("updated")),
                (self.merged, _("merged")),
                (self.removed, _("removed")),
                (self.unresolved, _("unresolved")))
        return ", ".join([_("%d files %s") % x for x in statlist])

    def formatFolded(self):
        return ''

    def formatStandard(self):
        return ''

    def getList(self):
        """Mercurial merge.py compatible list of stats"""
        return self.updated, self.merged, self,removed, self.unresolved


class actionBase(object):
    def __init__(self, fctx):
        self.fctx = fctx
        self.order = 0 #lower gets done first

    def __cmp__(self, other):
        result = cmp(self.order, other.order)
        if result: return result
        #same action, so sort by filename
        return cmp(self.fctx.path(), other.fctx.path())

    def __str__(self):
        return _("Do nothing action on %s") % self.fctx.path()

    def apply( self, repo, auditor, stats):
        pass
        #repo.ui.debug(_("Applying nothing"))

    def record( self, repo):
        pass
        #repo.ui.debug(_("Recording nothing"))

class actionGetClobbering(actionBase):
    """Get a file, not worrying if filename collisions cause overwrites."""

    def __str__(self):
        return _("Get %s, allowing filname collisions.") % self.fctx.path()

    def apply( self, repo, auditor, stats):
        fctx = self.fctx
        name = fctx.path()
        flags = fctx.flags()
        data = fctx.data()
        repo.wwrite( name, data, flags)
        stats.updated += 1

    def record( self, repo):
        repo.dirstate.normal(self.fctx.path())

class actionTryRemove(actionBase):
    """removes a file form the wc and manifest if possible, silent if it fails becasue
    the file doesn't exist or can't be removed."""
    def __init__(self, fctx):
        actionBase.__init__(self,fctx)
        self.order = -10 #removes happen early

    def __str__(self):
        return _("Remove %s") % self.fctx.path()

    def apply( self, repo, auditor, stats):
        name = self.fctx.path()
        auditor(name)
        name = repo.wjoin(name)
        self._apply(name)
        stats.removed += 1

    def _apply(self, filename):
        try:
            util.unlink(filename)
        except OSError, inst:
            pass

    def record( self, repo):
        name = self.fctx.path()
        #~ repo.ui.debug(_("Forgetting %s") % name)
        entry = repo.dirstate[name]
        if entry[0] != "?":
            repo.dirstate.remove(name) #remove or foget?
        #forget seems to be for un-adding
        #remove seems to be the way for actually taking out of the dirstate

def actionRemove( actionTryRemove):
    """Remove a file, warning if there's a problem."""
    def _apply(self, filename):
        try:
            util.unlink(filename)
        except OSError, inst:
            if inst.errno != errno.ENOENT:
                repo.ui.warn(_("update failed to remove %s: %s!\n") %
                             (filename, inst.strerror))

class action2Way(actionBase):
    """Requests a merge of two files without any common ancestor needed because not all
    folding conflicts have a common ancestor. If there is one, however, it will try to find
    it and use it in the merge."""
    def __init__(self, destFctx, peerFctx, parentNode):
        """peerFctx = other file context whose content we want to merge into dest
        though we probably won't find a common ancestor.
        """
        actionBase.__init__(self, destFctx)
        self.peerFctx = peerFctx
        self.parent = parentNode
        self.order = 10

    def __str__(self):
        return _("Merge %s content into %s.") % (self.peerFctx.path(), self.fctx.path())

    def resolve(self, repo, fctx1, fctx2):
        """Merge files."""
        path = fctx1.path()                 #original local filename before merge
        fcd = fctx1                         #destination file context (merge into this)
        fco = fctx2                         #other file context

        fca = fcd.ancestor(fco)
        if not fca:
            fca = fcd.ancestor(fco)

        # It'd be nice if filemerge just merged strings.
        failure = filemerge.filemerge(repo, self.parent, path, fcd, fco, fca)
        return not failure

    def apply( self, repo, auditor, stats):
        #?auditor(self.fctx.path())
        if self.resolve(repo, self.fctx, self.peerFctx):
            stats.merged += 1
        else:
            stats.unresolved += 1

    def record( self, repo):
        name = self.fctx.path()
        repo.dirstate.merge(name) #I think arg is supposed to be the destination file

        #~ f2, fd, flag, move = a[2:]
        #~ if branchmerge:
            #~ # We've done a branch merge, mark this file as merged
            #~ # so that we properly record the merger later
            #~ repo.dirstate.merge(fd)
            #~ if f != f2: # copy/rename
                #~ if move:
                    #~ repo.dirstate.remove(f)
                #~ if f != fd:
                    #~ repo.dirstate.copy(f, fd)
                #~ else:
                    #~ repo.dirstate.copy(f2, fd)
        #~ else:
            #~ # We've update-merged a locally modified file, so
            #~ # we set the dirstate to emulate a normal checkout
            #~ # of that file some time in the past. Thus our
            #~ # merge will appear as a normal local file
            #~ # modification.
            #~ repo.dirstate.normallookup(fd)
            #~ if move:
                #~ repo.dirstate.forget(f)

class mergeState(object):
    def __init__(self, repo):
        self.repo = repo
        self.actions = []
        self.applied = False
        self.recorded = False

    def __iadd__(self, other):
        """ Operator: self += action"""
        self.actions.append(other)
        return self

    def debug(self, msg):
        self.repo.ui.debug(msg)

    def apply(self):
        assert not self.applied, _("Need to clear self.applied if you really want to re-apply actions")
        self.debug(_("Sorting actions\n"))
        self.actions.sort()
        #start transaction?
        self.debug(_("Performing actions:\n"))
        auditor = util.path_auditor(self.repo.root)
        self.stats = mergeStats()
        for a in self.actions:
            if a.fctx.path()[0] == "/": continue #no rooted paths allowed for security
            self.debug( "  %s\n" % str(a))
            a.apply( self.repo, auditor, self.stats)
        self.applied = True
        return self.stats

    def record(self):
        assert not self.recorded, _("Need to clear self.recorded if you really want to re-record actions")
        self.debug(_("Saving changes to dirstate.\n"))
        for a in self.actions:
            a.record( self.repo)
        self.recorded = True
        return self.stats

    def applyrecord(self):
        stats = self.apply()
        self.record()
        return stats

"""------------ FILENAME COLLISION HANDLERS, RESOLVERS, MERGERS ------------"""
class collisionFinder(object):
    """handle  filename collision tests """

    def __init__( self, repo, revisionToFold=None):
        self.repo = repo
        self.wc = repo[None]
        self.parents = self.wc.parents()
        if self.hasUncommittedMerges():
            raise util.Abort(_("uncommitted merges, please commit or revert before folding"))
        self.parent = self.parents[0]
        self.branch = self.wc.branch()
        self.heads = self.repo.branchheads(self.branch)
        foldNode = revisionToFold or self.defaultRev()
        self.foldCtx = repo[foldNode]
        self.foldRev = self.foldCtx.rev()
        self.manifest = self.foldCtx.manifest()
        self.conflicts = self.findConflicts(self.foldCtx, self.wc)

    def defaultRev( self):
        """Handle the default revision for an 'hg update' command.
        Note: different commands imply different things when you don't specifiy a --rev option
        Update: None = tip of current branch
        Merge: None = second head of two
        """
        try:
            return self.repo.branchtags()[self.branch]
        except KeyError:
            if self.branch() == "default": # no default branch!
                return self.repo.lookup("tip") # update to tip
            else:
                raise util.Abort(_("branch %s not found") % wc.branch())

    def canonize(self, path):
        """This defines what paths collide. Paths with the same canonical form are collisions."""
        return path.lower()

    def prefer(self, path1, path2):
        """This defines which path form to prefer when history doesn't provide enough hints."""
        return cmp(path2, path1)

    def hasUncommittedMerges(self):
        return len(self.parents) > 1

    def hasUncommittedChanges(self):
        return self.wc.files() or self.wc.deleted()

    def findConflicts(self, ctx1, ctx2):
        """Set's self.conflicts to a dictionary of {
          lowercaseFileName: [ (changeContext, actualFileName), ...],
        }
        """
        # Form a dictionary of all the filenames in both parents
        result = {}
        def _addFile(fctx):
            key = self.canonize(fctx.path())
            entries = result.get(key, [])
            entries.append( fctx )
            result[key] = entries

        def _addChangeset(ctx):
            if not ctx: return
            for filename in ctx:
                _addFile( ctx[filename])

        # Add entries
        _addChangeset(ctx1)
        _addChangeset(ctx2)

        # Remove entries with only one case representation
        def hasConflicts( fctxList):
            uniqueNames = set( [fctx.path() for fctx in fctxList])
            return len(uniqueNames) > 1
        toRemove = [k for k,v in result.items() if not hasConflicts(v)]
        for k in toRemove: del result[k]
        return result

    def formatConflicts( self):
        """Print the conflicts in a parsable way."""
        if not self.conflicts: return ""
        def fmtInstance( fctx):
            return "%s.%s" % (fctx.path(), fctx.rev())
        def fmtConflict( key):
            conflict = self.conflicts[key]
            instances = [fmtInstance(x) for x in conflict]
            instances = ",".join(instances)
            return "%s: %s" % (key, instances)
        keys = self.conflicts.keys()
        keys.sort()
        lines = [fmtConflict(x) for x in keys]
        lines = "\n".join(lines)
        return _("Collisions: %d\n%s") % (len(self.conflicts), lines)

    def debug(self, msg):
        self.repo.ui.debug(msg)

class collisionClobberer( collisionFinder):
    """Allows destructively updating to a revision with filename collisions."""


    def cmpColliders(self, fctx1, fctx2):
        """Sorts file change contexts in order of preference in filename folding.
        -1 means prefer fctx1, +1 means prefer fctx2. 0 means they are the same.
        """
        #prefer the one that is ancestor to the other
        ancestor = fctx1.ancestor(fctx2)
        if ancestor == fctx1:
            return -1
        if ancestor == fctx2:
            return 1

        #prefer the one with more revisions
        rev1, rev2 = fctx1.filerev(), fctx2.filerev()
        if rev1 != rev2: return cmp(rev2, rev1)

        #otherwise go by our string standards
        return self.prefer( fctx1.path(), fctx2.path())

    def rankForms(self):
        """Modifies self.conflicts, putting preferred filename form first in list of alternatives."""
        #if one is actually a rename of another, prefer the original
        #prefer the one added earlier
        #or that appears in more changesets
        #otherwise sort by the prefer function
        self.debug( _("Finding preferred form of filenames\n"))
        #c = self.conflicts.values()
        build = {}
        self.unpreferredNames = set()
        for k,v in self.conflicts.items():
            colliders = list(set(v)) #remove duplicates
            colliders.sort(lambda a, b: self.cmpColliders(a,b))
            #now the preferred name will be the first items,
            #It needs to get data from wc; all others, from history.
            colliders = [(n==0) and folddest(fctx) or foldsource(fctx)
                for n, fctx in enumerate(colliders)]
            build[k] = colliders
            self.unpreferredNames.update([fctx.path() for fctx in colliders[1:]])
        self.conflicts = build

    def collides(self, filename):
        return self.conflicts.has_key( self.canonize( filename))

    def clobberup(self):
        """Update to the changeset in self.foldCtx, allowing colliding filenames to overwrite
        each other
        """
        wlock = self.repo.wlock()
        self.debug(_("updating working copy to %s, allowing filename collisions.") % self.foldCtx.rev())
        try:
            stats = self.bareClobberup()
            self.finalize( stats)
        finally:
            del wlock

    def bareClobberup(self):
        """Update to the changeset in self.foldCtx, allowing colliding filenames to overwrite
        each other, but do not enclose in locks or finalize things like parents and branch
        """
        # Get a working copy that thinks we have everything
        # Even though collisions will have overwritten some files
        statlist = hgupdate(self.repo, self.foldRev, False, True, None)
        stats = mergeStats(statlist)

        self.rankForms()
        self.deleteUnpreferred( stats)
        self.getPreferred( stats)
        return stats

    def getPreferred(self,stats):
        """Of the colliding file names, make sure the forms we want exist in the working
        copy."""
        actions = mergeState( self.repo)
        for fctxList in self.conflicts.values():
            actions += actionGetClobbering(fctxList[0]) #recover contents
        actions.applyrecord()

    def deleteUnpreferred(self, stats):
        """Look at the list of colliding file names and remove the forms
        we don't want."""
        actions = mergeState( self.repo)
        for fctxList in self.conflicts.values():
            for fctx in fctxList[1:]:
                actions += actionTryRemove(fctx) #delete all conflicts
        actions.applyrecord()

    def finalize(self, stats):
        parent1, parent2 = self.foldCtx.node(), node.nullid
        hash1, hash2 = str(self.foldCtx), ""
        branch = self.foldCtx.branch()
        self.repo.dirstate.setparents( parent1, parent2)
        self.repo.dirstate.setbranch(branch)
        self.repo.hook( "update", parent1=hash1, parent2=hash2, error=stats.unresolved)

class collisionUpdater( collisionClobberer):
    """handle folding of collisions within a single revision by transforming them into merges"""

    def fold(self):
        """Transform filename collisions into a series of merges.
        A big complication is that it's possible for one changeset to have more than two
        collisions on the same filename (e.g. "Apple", "APPLE", "apple"). The result we're
        aiming for is two deletes and a modification (merge):
            M Apple
            R APPLE
            R apple
        If the files all match, then there will be no modified Apple
        """
        wlock = self.repo.wlock()
        self.debug(_("updating working copy to %s, allowing filename collisions.") % self.foldCtx.rev())
        try:
            stats = self.bareFold()
            self.finalize( stats)
        finally:
            wlock.release()
        return stats

    def bareFold(self):
        stats = self.bareClobberup() #delete colliders except for preferred versions
        self.mergeCollisions(stats)
        return stats

    def mergeCollisions(self, stats):
        actions = mergeState( self.repo)
        wcparent = self.parent.node() #node of first parent of working copy
        for fctxList in self.conflicts.values():
            dest = fctxList[0]
            for peer in fctxList[1:]:
                actions += action2Way( dest, peer, wcparent) #merge it's contents
        extrastats = actions.applyrecord()
        stats.foldmerged += extrastats.merged
        stats.foldunresolved += extrastats.unresolved

class collisionMerger( collisionUpdater):
    """Add branch merging ability to collision folder"""


    def __init__(self, *args):
        collisionUpdater.__init__( self, *args)
        if self.hasUncommittedChanges():
            raise util.Abort(_("uncommitted changes, please commit or revert before merging"))

    #~ def OBSOLETEsetMergeRev(self, nodespec=""):
        #~ """Identify the revision to merge with. If empty, implies merge with a second head."""
        #~ self.mergeCtx = None
        #~ if not nodespec: #implicit merge with second head
            #~ self.mergeRev = self._implicitMergeRev()
            #~ self.mergeCtx = self.repo[self.mergeRev]
        #~ else:
            #~ self.mergeCtx = self.repo[nodespec]
            #~ self.mergeRev = self.mergeCtx.rev()
        #~ #adding a merge context means more possibilities for collisions, so revise that list
        #~ self.conflicts = self.findConflicts(self.foldCtx, self.mergeCtx)

    def defaultRev(self):
        """No merge revision specified, so let's use the second head if that's legal, otherwise
        tell how to correct it.
        """
        nHeads = len(self.heads)
        if nHeads == 2:
            return self.heads[1] #merge with the second head implied

        # Anything else is an error, but let's help figure out the problem
        if nHeads > 2: #need explicit merge if more than 2 heads
            raise util.Abort(_("branch '%s' has %d heads - "
                               "please merge with an explicit rev") %
                             (self.branch, nHeads))
        #Single head only, clarify our feedback
        if len(self.repo.heads()) > 1: #...there's a named branch merge, requiring explicit --rev
            raise util.Abort(_("branch '%s' has one head - "
                               "please merge with an explicit rev") %
                             self.branch)
        #...or merging isn't an option
        msg = _('there is nothing to merge')
        if parent != repo.lookup(repo[None].branch()):
            msg = _('%s - use "hg update" instead') % msg
        raise util.Abort(msg)

    def merge(self, force=False):
        """branch merge treating filename collisions s conflicts, resolving changes"""
        wlock = self.repo.wlock()
        self.debug(_("merging with %s, resolving filename collisions.") % self.foldRev)
        try:
            stats = self.bareMerge(force)
            self.finalize( stats)
        finally:
            del wlock
        return stats

    def bareMerge(self, force):
        self.rankForms()
        def hasNoConflicts( filename):
            return filename not in self.unpreferredNames
        #tell mercurial to merge everything but our conflicting files.
        statlist = hgupdate( self.repo, self.foldRev, True, force, hasNoConflicts)
        stats = mergeStats( statlist)
        self.deleteUnpreferred(stats) #rm only if in dirstate
        self.getPreferred(stats)
        #need to make sure preferreds are all workingfilectx's WITH data from current changeset present
        self.mergeCollisions(stats)
        return stats

    def finalize( self, stats):
        self.repo.dirstate.setparents( self.parent.node(), self.foldCtx.node())


"""------------ COMMAND IMPLEMENTATION ------------"""

def foldUpdate(ui, repo, unnamedRev=None, **opts):
    #def update(ui, repo, node=None, rev=None, clean=False, date=None):
    #Original 'node' seems to be used to catch revision when sent as an unnamed CLI arg
    #so testing for that
    '''Fold Extension Help:
    Your system has a mercurial extension that changes how file name
    collisions are handled.

    If the --fold option is used, this extension transforms filenames that
    differ only by case into a merge on the same file.  This performs like an
    update: your working copy files are updated to --rev.  (If no --rev
    stated, uses the revision of the current working copy.) But unlike a
    normal update, it can result in deleted and merged files.

    For example suppose a manifest contains the files: "Apple", "APPLE", and
    "apple").  The result will be two deletes and a possible modification
    (merge):
            M Apple
            R APPLE
            R apple
    (If the files all match, then there will be no modification tag on
    "Apple".)

    This extension attempts to guess the filename form that is preferred name
    form, but this is dicey. (If you think about it, the diciness goes deep,
    stemming from filesystems that "sort of" care about case--case-sensitive
    or case-coercing are the only self- consistent approaches.) It looks at
    the form that has the most versions. Failing that, it takes the first form
    if you sort them lower-case first.
    '''
    original, rev, fold, dryrun = [opts.get(o) for o in 'original rev fold dry-run'.split()]
    if not fold: return original()

    if rev and unnamedRev:
        raise util.Abort(_("please specify just one revision"))
    if not rev:
        rev = unnamedRev

    folder = collisionUpdater(repo, rev)

    if dryrun: #dry run, just list conflicts
        if folder.conflicts:
            repo.ui.status(folder.formatConflicts() + '\n')
            #it'd be nice to return the number of conflicts as the errorlevel
    else: #do fold
        if folder.conflicts:
            stats = folder.fold()
            repo.ui.status( str(stats) + "\n")
        else: #no conflicts, so be safe and use vanilla mercurial
            original()

def foldMerge(ui, repo, unnamedRev = None, **opts):
    #definition in commands.py: merge(ui, repo, node=None, force=None, rev=None):
    #Original 'node' seems to be used to catch revision when sent as an unnamed CLI arg
    #so testing for that
    '''Fold Extension Help:
    Your system has a mercurial extension that changes how file name
    collisions are handled.

    Suppose a manifest contains the files: "Apple", "APPLE", and "apple"). If
    you use the --fold option and merge with a changeset has an edited version
    of "apple" The result will be two deletes and a possible modification
    (merge):
            M Apple
            R APPLE
            R apple
    You will get a chance to merge apple & apple, then Apple & APPLE, then
    Apple & apple.  (If the files all match, then there will be no
    modification tag on "Apple".)

    For additional help, see 'hg update'
    '''
    original, rev, fold, dryrun, force= [
        opts.get(o) for o in
        'original rev fold dry_run force'.split()]

    if rev and unnamedRev:
        raise util.Abort(_("please specify just one revision"))
    if not rev:
        rev = unnamedRev

    #force fold if requires fold?
    if not fold: return original()

    merger = collisionMerger(repo, rev)

    if dryrun: #dry run, just list conflicts
        if merger.conflicts:
            repo.ui.status(merger.formatConflicts() + '\n')
    else: #do fold
        if merger.conflicts:
            stats = merger.merge(force=force)
            repo.ui.status( str(stats) + "\n")
        else:
            original()

"""------------  COMMAND TABLE CONSTRUCTION------------"""


def extendCommand( commandName, newFunction, moreOptions, moreSyntax):
    """Attempt to add options and syntax to an existing mercurial command.
    commandName - string name of existing mercurial command
    newFunction - function that will handle that command now. This function must accept
                  a named argument, "original" which will contain the function
                  Mercurial would normally call for the command.
    moreOptions - additional options formatted like the normal command-table options lists
    moreSyntax  - additional syntax help string, with a %s where old syntax will be inserted
    """
    def findCmd( cmdName):
        keys = [(k,v) for k,v in commands.table.items() if k.lstrip("^").startswith(cmdName)]
        if not keys:
            util.Abort( _("Unable to find existing command to extend: %s.") % cmdName)
        if len(keys)> 1:
            util.Abort( _("Ambiguous command requested for extension: %s.") % cmdName)
        return keys[0]
    def allopts( opts):# set of all short and long options for a command
        return set( [x[0] for x in opts] + [x[1] for x in opts])
    #look up existing command table entry
    fullNames, oldCmd = findCmd( commandName)
    oldFunc, oldOpts, oldSyntax = oldCmd
    #make sure none of our additional options conflict
    if allopts(oldOpts) & allopts(moreOptions):
        msg = _("Extension trying to add conflicting options to %s") % commandName
        util.Abort(msg)
    #create a replacement command tableentry that calls our function instead
    def wrapper( ui, repo, *args, **opts):
        cleanOpts = opts.copy()
        for opt in moreOptions: #remove our added options from passthrough
            key= opt[1].replace("-","_")
            del cleanOpts[key]
        def callOriginal():
            return oldFunc( ui, repo, *args, **cleanOpts)
        return newFunction( ui, repo, original=callOriginal, *args, **opts)
    options = oldOpts + moreOptions
    syntax = moreSyntax % oldSyntax
    # the functionn doc string is called by 'hg help'
    # we just follow the pattern and add our extension help
    wrapper.__doc__ = gettext(oldFunc.__doc__) + "\n\n" + gettext(newFunction.__doc__)
    # replace the commad table entry with our own
    commands.table[fullNames] = (wrapper, options, syntax)

foldopts = commands.dryrunopts + [
    ("", "fold", None, _("treat filename collisions as the same file, merging as needed"))
    ]

#~ import rpdb2; rpdb2.start_embedded_debugger("a")
foldingUpdate = extendCommand( "update", foldUpdate, foldopts, "--fold %s")
foldingMerge = extendCommand( "merge", foldMerge, foldopts, "--fold %s")

#commands.norepo += ' ptapi ptcheckinstall ptcodes ptcommands'

cmdtable = {
    #~ "fupdate": foldCommandSpec(),
    #~ "fmerge": mergeCommandSpec(),
}

