# MFrame

MFrame is a CLI tool written as a Makefile for managing modules across
applications, regardless of technology stack. The only infrastructure needed is
to have your codebase under [GIT][git].

Under the hood, MFrame uses [git-subrepo][git-subrepo] and treats each module as
a _subrepo_ (an alternative to GIT submodules). Most commands are wrappers
around git-subrepo commands, plus extra logic for module versioning and
integration into the host application.

**_MFrame is part of [MVP Toolkit][mvp-toolkit], a premium collection of starter
kits, modules and best practices for fast MVP development._**

## Table of Contents

* [Use Case](#use-case)
* [Getting Started](#getting-started)
  * [System Requirements](#system-requirements)
  * [Installation](#installation)
  * [Usage](#usage)
  * [Configuration](#configuration)
* [Commands](#commands)
* [Lifecycle Hooks](#lifecycle-hooks)
  * [Module Hooks](#module-hooks)
  * [Global Hooks](#global-hooks)
* [Module Versioning](#module-versioning)
* [Crash Recovery](#crash-recovery)
* [Extending MFrame](#extending-mframe)

## Use Case

You start building a new web app and decide to use MFrame. You create a new
module to keep all logic around authentication (login, password reset, etc...)
in one place. Once everything is working as expected, you create a new GIT repo
for this module and use MFrame to "push" the initial version.

Assuming you built the auth module to be reusable, on your next app, you can
simply use MFrame to "clone" the module, possibly change its configuration, and
then have all the auth functionality in the new app as well, without spending
any more time on it.

Some time passes and someone reports an issue with authentication in one of the
apps. You investigate and discover a bug in the auth module. Once fixed and
validated, you use MFrame to "push" the updates upstream and then "pull" in the
other app.

The same process is applied when adding new features. Once a module is extended,
MFrame makes it easy to update all other apps that use the module.

Note that whenever you work on a module you don't need to treat it in
isolation. If you'd do that, you'd need some sandbox environment that would
simulate the app, which might require a lot of work. Instead, with MFrame, you
evolve your modules directly in the apps they're used in, and then simply "pull"
the updates in the other apps.

**_If you don't already have a library of modules, you may want to try
[MVP Toolkit][mvp-toolkit], a premium collection of starter kits, modules and
best practices for fast MVP development._**

## Getting Started

### System Requirements

  * [make][make]
  * [git-subrepo][git-subrepo] (>= 0.4.0)
  * [perl][perl] or [envsubst][envsubst]
  * [standard-version][standard-version] (optional, see [Module Versioning][versioning])

### Installation

Assuming you have a GIT repository cloned in `my-app` and you want your modules
to live in `my-app/src/modules`, MFrame can be installed using these steps:

Add MFrame as a _subrepo_:
```bash
cd my-app
mkdir -p src/modules
git subrepo clone git@github.com:mvp-toolkit/mframe src/modules/mframe
```

Create a `Makefile` in your app's root directory, with at least the following
contents:
```makefile
# MFrame Configuration:
ROOT_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# include MFrame:
include src/modules/mframe/init.mk
```

MFrame is now installed and typing `make` will show a list of [available
commands](#commands).

### Usage

Assuming your top `Makefile` looks like this:
```makefile
# MFrame Configuration:
ROOT_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
MODULES_GIT := git@github.com:my-company

# include MFrame:
include src/modules/mframe/init.mk
```

Given the above configuration, here's what MFrame will do if you type these
commands:

#### `make module id=test`

Will create a module named `test` in `src/modules/test`.

#### `make module-push id=test`

Will push the module to `git@github.com:my-company/test`.

#### `make module-clone id=auth`

Will clone the latest version of the "auth" module from
`git@github.com:my-company/auth` into `src/modules/auth`.

For more information about these and other commands that you can use, see the
[Commands](#commands) section.

### Configuration

MFrame is configured by the following parameters, which must be defined at the
top of your `Makefile`.

| Param | Description | Required | Default Value |
| - | - | :-: | - |
| `ROOT_DIR` | The absolute path to your application's root directory | `Yes` | n/a |
| `MODULES_DIR` | The relative path (from `${ROOT_DIR}`) to a directory where modules should live | `No` | The directory where MFrame is installed |
| `MODULES_GIT` | The base URL for your GIT repositories; if defined, will be used to infer a module's repository URL from its name | `No` | n/a |
| `MODULES_TPL` | A default module template to be used when creating new modules | `No` | `blank` |
| `MODULES_PFX` | Common prefix for module GIT directories. If defined, must be used consistently across all seeds and applications | `No` | `blank` |

## Commands

In the commands below, the `id` parameter can be a GIT repository URL, a module
name or a local directory (for already cloned modules).

### `make module id=...`

Create a new, initially unpublished, module. This command is interactive and will
ask you to provide or confirm the module's future upstream repository.

Optionally, you can provide a module template to be used. If the template is a
GIT repository URL, the new module will be created by cloning that repository,
otherwise the template will be expected in `${MODULES_DIR}/.<template-name>`. If
this directory is not found, or no template is provided, a blank module will be
created (based on an internal template provided by MFrame).

All files within the newly created module will be parsed and the following
variables will be substituted, if found:

- `${REPO}` with the new module's repository URL
- `${NAME}` with the new module's name

This command will call the `_module-created` [lifecycle hook][hooks].

### `make module-clone id=... [v=latest]`

Clone (and install) a module.

This command will call the module's `cloned` hook as well as the global
`module-cfgadd` and `_module-cloned` [lifecycle hooks][hooks].

### `make module-pull id=...`

Update an installed module by getting any new commits from its upstream, but
without changing its version (see [Module Versioning][versioning]).

If you want to upgrade/downgrade to another version, use the `module-clone`
command.

This command will call the `_module-pulled` [lifecycle hook][hooks].

### `make module-push id=... [v=...]`

This command is used to initially push a module as well as to push any changes
upstream.

If the `v` parameter is specified, it is assumed you want to manually
control versioning. Otherwise, if [standard-version][standard-version] is
available, the module version is determined by looking at the
commits that are being pushed. For more information, please see the
[Module Versioning][versioning] section.

This command will call the `_module-pushed` [lifecycle hook][hooks].

### `make module-remove id=...`

Remove a module.

This command will call the module's `remove` hook as well as the global
`module-cfgrem` and `_module-removed` [lifecycle hooks][hooks].

### `make module-status [id=...]`

Show brief status information about one or all installed modules. This command
will print the number of commits ahead/behind of the installed module compared
to its upstream version.

### `make module-info [id=...]`

Show more detailed information about one or all installed modules. This command
will print the actual commits a module is ahead or behind its upstream.

## Lifecycle Hooks

Using the hooks below, modules can better integrate with the host applications
they are installed into and MFrame can better integrate into your workflow.

All hooks are optional.

### Module Hooks

These hooks are implemented in modules.

#### `_<module-name>-cloned`

Called when the module is cloned.

#### `_<module-name>-remove`

Called just before the module is removed.

### Global Hooks

These hooks should be implemented in your `Makefile` and they are all called
with the following parameters:

- `repo` the module's repository URL
- `name` the module's name

#### `_module-created`

Called after a new module is successfully created.

#### `_module-cloned`

Called after a module is cloned.

#### `module-cfgadd`

Called after a module is cloned. The main purpose of this hook should be to
merge the module's (default) configs into the main app's config. It's a separate
hook from `_module-cloned` because you might want to call this multiple times
manually.

#### `_module-pulled`

Called after a module is updated with changes from upstream.

#### `_module-pushed`

Called after a module is pushed upstream.

#### `_module-removed`

Called after a module is removed.

#### `module-cfgrem`

Called after a module is removed. The main purpose of this hook should be to
remove the module's configs from the main app's config.

## Module Versioning

If you specify a `v`ersion parameter when publishing your module, MFrame
assumes you want to manually manage versioning and will publish to the specified
version.

If no version is specified and [standard-version][standard-version] is found in
your path, MFrame will try to infer the new module version by looking at your
commit messages (check the documentation of standard-version to learn more about
how this works).

Version numbers look like [semver](https://semver.org) versions, but MFrame
uses these 2 rules:

  1. Non-breaking changes always increase the `patch` number
  2. Breaking changes increase the `major` number if the change happens on the
     latest `major`, the `minor` number if it happens on the latest `minor` or
     the `patch` version in all other cases

### Example

Assume latest published versions for a module are: `2.0.5`, `1.0.0`, `1.1.6`.

#### Non-breaking Change

  - `2.0.5` -> `2.0.6` (on the same `v2` branch)
  - `1.0.0` -> `1.0.1` (on the same `v1` branch)
  - `1.1.6` -> `1.1.7` (on the same `v1.1` branch)

#### Breaking Change

  - `2.0.5` -> `3.0.0` (on a new `v3` branch)
  - `1.0.0` -> `1.0.1` (on the same `v1` branch)
  - `1.1.6` -> `1.2.0` (on a new `v1.2` branch)

## Crash Recovery

A lot of the git-subrepo commands that are used to manage modules require that
your GIT working directory is "clean" (i.e.: there are no uncommitted changes).

Before running module related commands, MFrame checks for uncommitted changes
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

MFrame can be extended through modules by creating a `makefile.mk` file as part
of the module. This file gets loaded by MFrame and its targets become
additional commands that you can use.

Some examples of modules that extend MFrame range from having cloud deployment
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
[standard-version]: https://github.com/conventional-changelog/standard-version
[hooks]: #lifecycle-hooks
[versioning]: #module-versioning
