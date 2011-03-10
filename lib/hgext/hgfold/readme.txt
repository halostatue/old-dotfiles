** DESCRIPTION

Fold (Mercurial wiki: CaseFoldPlugin) is a Mercurial extension that helps
Windows users deal with filename case collisions on VFAT and NTFS.

It adds options to the following Mercurial commands. Type "hg help <command>"
for more information:
  up    - allows you to update to a revision with filename collisions
  merge - allows you to merge with a changeset that would create filename
          collisions
    
The extension does not currently do anything to prevent filename collisions.
See discussion on the Mercurial Wiki

** LICENSE, CONTACTS
See Mercurial Wiki and comments in source code.

** INSTALLATION
To test the use of this plugin, you can specify it on the Mercurial command
line like this:

    hg --config "extensions.fold=c:\proj\hgfold\fold.py" status

You'll have to edit the path to reflect fold.py's location on your system.

You may want to add it to your Mercurial.ini or a repository's hgrc like this:

    [extensions]
    fold=c:\proj\hgfold\fold.py
    
If you do this, you can omit the --config command-line option.

** WARNINGS

Like all merge operations, fold.py has to change the parents of the working
directory. It is still in early testing, so use with caution.

If you get an error about an unknown changeset after running "hg recover", try
"hg debugsetparents <number of tip revision>". You can find the number of the
tip revision by running "hg log -l 2".
