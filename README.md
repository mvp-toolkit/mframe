# MFrame

MFrame is used as a package manager throughout MVP Toolkit. The main idea is
that a package is just a separate repository which is installed (by taking a
snapshot of it) into another repository (i.e.: the main app). Changes made to
an installed package can be pushed upstream (to the package's repo) and then
the package can be updated (pulled) in all the other apps it is being used.

Under the hood, MFrame is a CLI wrapper for [git-subrepo][git-subrepo] written
as a [Makefile][make].

**_MFrame is part of [MVP Toolkit][mvp-toolkit], a premium collection of starter
kits and reusable subrepos for fast MVP development._**

## Table of Contents

* [Getting Started](#getting-started)
  * [System Requirements](#system-requirements)
  * [Installation](#installation)
  * [Configuration](#configuration)
* [Workflow](#workflow)
* [Commands](#commands)
* [Lifecycle Hooks][hooks]
  * [Subrepo Hooks](#subrepo-hooks)
  * [Global Hooks](#global-hooks)
* [Crash Recovery](#crash-recovery)
* [Extending MFrame](#extending-mframe)

## Getting Started

### System Requirements

  * [make][make]
  * [git-subrepo][git-subrepo] (>= 0.4.0)
  * [perl][perl] or [envsubst][envsubst]

### Installation

Create a new project (GIT repo), unless you already have one:
```bash
mkdir my-project && cd my-project
git init && git commit --allow-empty -m 'feat: Initial commit'
```

Add MFrame as a _subrepo_:
```bash
git subrepo clone -b v1 git@github.com:mvp-toolkit/mframe subrepos/mframe
```

Create a `Makefile` in your project's root directory. Check out the
[Configuration](#configuration) for all available options:
```makefile
# MFrame Configuration:
ROOT_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# include MFrame:
include subrepos/mframe/init.mk
```

MFrame is now installed and typing `make` will show a list of [available
commands](#commands).

### Configuration

MFrame is configured by the following parameters, which must be defined at the
top of your `Makefile`.

| Param | Description | Required | Default Value |
| - | - | :-: | - |
| `ROOT_DIR` | The absolute path to your project's root directory | `Yes` | |
| `MFRAME_DIR` | The relative path (from `${ROOT_DIR}`) to a directory where subrepos should live | `No` | The directory where MFrame is installed |
| `MFRAME_GIT` | The base URL of your GIT server; if defined, will be used to infer the repository URL for a new subrepo based on its name | `No` | |
| `MFRAME_TPL` | A default template to be used when creating new subrepos | `No` | `empty` |

## Commands

In the commands below, the `name` parameter must point to a package, either by
its local directory name or by its GIT repository URL.

### `make subrepo name=...`

Create a new, initially unpublished, subrepo. This command is interactive and
will ask you to provide or confirm the subrepo's future upstream repository.

Optionally, you can provide a subrepo template to be used. If the template is a
GIT repository URL, the new subrepo will be created by cloning that repository,
otherwise the template will be expected in `${MFRAME_DIR}/.<template-name>`.
If this directory is not found, or no template is provided, an empty subrepo
will be created (based on an internal template provided by MFrame).

All files within the newly created subrepo will be parsed and the following
variables will be substituted, if found:

- `${REPO}` with the new subrepo's repository URL
- `${NAME}` with the new subrepo's name

This command will call the `_subrepo-created` [lifecycle hook][hooks].

### `make subrepo-clone name=... [v=latest]`

Clone (and install) a subrepo.

This command will call the subrepo's `cloned` hook as well as the global
`subrepo-cfgadd` and `_subrepo-cloned` [lifecycle hooks][hooks].

### `make subrepo-pull name=...`

Update an installed subrepo by getting any new commits from its upstream, but
without changing its version.

If you want to upgrade/downgrade to another version, use the `subrepo-clone`
command.

This command will call the `_subrepo-pulled` [lifecycle hook][hooks].

### `make subrepo-push name=...`

This command is used to initially push a subrepo as well as to push any changes
upstream.

This command will call the `_subrepo-pushed` [lifecycle hook][hooks].

### `make subrepo-remove name=...`

Remove a subrepo.

This command will call the subrepo's `remove` hook as well as the global
`subrepo-cfgrem` and `_subrepo-removed` [lifecycle hooks][hooks].

### `make subrepo-status [name=...]`

Show brief status information about one or all installed subrepos. This command
will print the number of commits ahead/behind of the installed subrepo compared
to its upstream version.

### `make subrepo-info [name=...]`

Show more detailed information about one or all installed subrepos. This command
will print the actual commits a subrepo is ahead or behind its upstream.

## Lifecycle Hooks

Using the hooks below, subrepos can better integrate with the host applications
they are installed into and MFrame can better integrate into your workflow.

All hooks are optional.

### Subrepo Hooks

These hooks are implemented in subrepos.

#### `_<subrepo-name>-cloned`

Called when the subrepo is cloned.

#### `_<subrepo-name>-remove`

Called just before the subrepo is removed.

### Global Hooks

These hooks should be implemented in your `Makefile` and they are all called
with the following parameters:

- `repo` the subrepo's repository URL
- `name` the subrepo's name

#### `_subrepo-created`

Called after a new subrepo is successfully created.

#### `_subrepo-cloned`

Called after a subrepo is cloned.

#### `subrepo-cfgadd`

Called after a subrepo is cloned. The main purpose of this hook should be to
merge the subrepo's (default) configs into the main app's config. It's a separate
hook from `_subrepo-cloned` because you might want to call this multiple times
manually.

#### `_subrepo-pulled`

Called after a subrepo is updated with changes from upstream.

#### `_subrepo-pushed`

Called after a subrepo is pushed upstream.

#### `_subrepo-removed`

Called after a subrepo is removed.

#### `subrepo-cfgrem`

Called after a subrepo is removed. The main purpose of this hook should be to
remove the subrepo's configs from the main app's config.

## Crash Recovery

A lot of the git-subrepo commands that are used to manage subrepos require that
your GIT working directory is "clean" (i.e.: there are no uncommitted changes).

Before running subrepo related commands, MFrame checks for uncommitted changes
and stashes them. Further more, any operation that requires a change to your
repository (i.e.: new commits) is performed on a separate temporary branch and
once the command completes successfully that branch is merged into your original
branch.

Recovering from an unexpected crash is therefore pretty simple:

1. Check if the GIT repository is on a temp branch and switch to the original
branch
2. Check if there are any stashed files and unstash them

Following the above 2 steps should bring your repository back to the exact same
state as before executing the command that crashed.

## Extending MFrame

MFrame can be extended through subrepos by creating a `makefile.mk` file as part
of the subrepo. This file gets loaded by MFrame and its targets become
additional commands that you can use.

Some examples of subrepos that extend MFrame range from having cloud deployment
scripts or database management utilities that can be (re)used across multiple
projects.

## License

[MIT](LICENSE)

[mvp-toolkit]: https://mvp-toolkit.com
[git]: https://git-scm.com
[git-subrepo]: https://github.com/ingydotnet/git-subrepo
[make]: https://www.gnu.org/software/make/
[envsubst]: https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html
[perl]: https://perl.org
[hooks]: #lifecycle-hooks
