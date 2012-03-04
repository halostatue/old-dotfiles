# Austin's zsh plug-in system

This is a fairly simple plug-in system for zsh. A plug-in under this system is
a directory that contains a detection file (`detect`) and at least one item that
changes the environment:

* an `init` directory with one or more scripts inside;
* an `init` script;
* a `functions` directory with one or more zsh function scripts inside;
* a `functions` script; or
* a `bin` directory with one or more binaries inside.

For example, a zsh plug-in for `git` might look like this:

    plugins/
      git/
        bin/
          git-tag-versions
          git-darcs-record
          hub
          githack
          gitship
        detect
        functions/
          zgitinit
        init

## Plug-in Detection

A plug-in is detected thorugh the use of a script called `detect`. This is
*not* a zsh script. The general format for the `detect` script is:

    DIRECTIVE PARAMETERS

The known directives are:

* command
* alternates
* do
* do-return
* directory
* file
* executable

A plug-in will only be activated if **all** of the directives in the detection
script pass and should be kept fairly simple for speed purposes.

### command, alternates

    command COMMAND
    alternates COMMAND+

The `command` directive tests to see if the provided *COMMAND* is a program,
script, or shell function that exists. By default, the word `command` is
optional; any a *COMMAND* that appears on a line by itself will be treated as
having an implicit `command` directive.

This returns true if the output of the zsh builtin `command -v` returns any
value.

    command git

This will be true if `git` is in your `$PATH`.

The `alternates` directive works exactly like the `command` directive if only
one *COMMAND* is provided. If more than one *COMMAND* is provided, the
`command` test is run for each *COMMAND* provided, but only **one** of the
provided *COMMAND* parameters must exist for the result to be true.

    alternates jruby macruby ruby

This will be true if `jruby`, `macruby`, or `ruby` are in your `$PATH`.

### do, do-return

    do COMMAND [PARAMETERS]
    do-return VALUE COMMAND [PARAMETERS]

The `do` directive is followed by a *COMMAND* that will be executed with the
(optionally) provided PARAMETERS. Any output (both `stdout` and `stderr`) is
discarded and the shell return value (`$?`) will be used to determine whether
this directive passes in the usual shell manner (e.g., `$?` must be 0 to be
true).

    do is-mac

This will be true if the shell function `is-mac` returns true (in this case, if
`$OSTYPE` matches `*darwin*`).

The `do-return` directive executes the named *COMMAND* with the (optionally)
provided *PARAMETERS*, discarding any output. The shell return value must match
the provided *VALUE*, not zero.

    do-return 1 is-mac

This will be true if the shell function `is-mac` does *not* return true (in this case, if `$OSTYPE` does *not* match `*darwin*`).

### directory, file, executable

    directory PATH+
    file PATH+
    executable PATH+

These directives will test to see if one or more provided *PATH* value exist.
`directory` uses the result of `test -d`; `file` uses the result of `test -f`;
and `executable` uses the result of `test -x`. Before testing the provided
*PATH* values, the *PATH* list is eval-echoed (`mypath=$(evaul "echo PATH")`)
so that environment variables and glob expansions are resolved. As with
`alternates`, only one of the resolved paths must match the condition to be
true.

> **Note** that the `directory`, `file`, and `executable` directives won't work
> with paths that have spaces in them, even if they are quoted or escaped.

    directory ~/.rvm

This will be true if the directory `.rvm` exists in the user's home directory.

    file /etc/debian_version

This will be true if the file `/etc/debian_version` exists.

    executable ${GOROOT:-${HOME}/go}/src/all.bash

This will be true if the file `${GOROOT}/src/all.bash` exists and is
executable; should the environment variable `${GOROOT}` not exist, the
default value `${HOME}/go` will be used, looking for
`${HOME}/go/src/all.bash`.
