# dotenv ― profile templates and multiple profiles per user

```
     __          __
    /\ \        /\ \__
    \_\ \    ___\ \ ,_\    __    ___   __  __
    /'_` \  / __`\ \ \/  /'__`\/' _ `\/\ \/\ \
   /\ \L\ \/\ \L\ \ \ \_/\  __//\ \/\ \ \ \_/ |
   \ \___,_\ \____/\ \__\ \____\ \_\ \_\ \___/
    \/__,_ /\/___/  \/__/\/____/\/_/\/_/\/__/
```

`dotenv` is a *dotfiles manager* that is designed 
to **share and extend profile environments**. With dotenv, it is possible
to use an existing set of configuration files and extend them locally, without
breaking upstream compatibility.

This makes `dotenv` best suited for environments where many developers want to
share a common setup, while allowing  for individual configuration and 
customization.

`dotenv` also works well in a single-user setup where you have multiple
environments on the same machine, or an environment with machine-specific changes.

Features:

- **Profile templates**: dotfiles templates can be combined and filled in
  with profile-specific variables.

- **Multiple profiles**: instantly switch between different sets of dotfiles
  without losing any change.
  
- **Safe**: `dotenv` will never override a file that it does not manages, and keeps
  backups of existing files it replaces.

- **Gradual transition**: progressively migrate your dotfiles using `dotenv-manage`


## Quick Start

To install `dotenv` in `~/local`, run:

```shell
$ curl https://raw.githubusercontent.com/sebastien/dotenv/master/install.sh | bash
```

Now, start managing your existing configuration files and directories using `dotenv`

``` 
$ dotenv-manage ~/.bashrc ~/.vimrc ~/.vim
```

This will move these files to `~/.dotenv/profiles/default` and create symlinks
for them. If you'd like to see the files managed by dotenv at any time:

```
$ dotenv
~/.bashrc → ~/.dotenv/managed/bashrc
~/.vimrc → ~/.dotenv/managed/vimrc
~/.vim → ~/.dotenv/managed/vim
```

## What can dotenv do?

Dotenv can essentially be seen as a way to share your dotfiles between machines
and co-workers. The core concept of dotenv is the **profile**: a profile is a
set of files (and directories) linked to your `$HOME` directory, and prefixed
with a dot. By default, profiles are stored in `~/.dotenv/profiles` and your
**active profile** is symlinked to `~/.dotenv/active`.

Now, imagine that you're working at a company that has some default
configuration files (shell setup, editor defaults, gitrc/hgrc, etc), and that
you'd like to bring your own dotfiles as well. Without dotenv, you'd copy the
files and edit them locally. But what happens if you've updated your dotfiles at 
home and would like to propagate the update to the files at work? What if the
company has updated the original configuration files?

### Profile templates

Dotenv introduces the notion of **profile template** to do just that: a profile
template is a collection of files (just like a profile) that can be **merged into
a profile**. You can have a *company profile template* (`~/.dotenv/templates/company`)
and a *personal profile template* (`~/.dotenv/templates/personal`) and **merge
both** into your default dotenv profile:

```
$ dotenv-apply company
@default/bash/company_setup.sh ← company:bash/company_setup.sh
@default/vim/company_setup.vim ← company:vim/company_setup.vim

$ dotenv-apply personal
@default/bashrc ← personal:bashrc
@default/bash/local.sh ← personal:bash/local.sh
@default/vimrc ← company:vimrc
```

### File templates

Now, the company might provide files that contain placeholders to be filled
in with specific information, such as your name and email address. For instance, an
`~/.hgrc` file that looks like this:

```
[ui]
username =${NAME} <${EMAIL}>
```

Normally, you'd copy that file template and replace the placeholders with
your actual information. But what if the file changes and contains more 
information? To handle this situation, dotenv introduces the notion of 
**file template**. A file template ends up with the `.tmpl` extension and
will have any string contained in `${…}` be replaced by the contents of
the corresponding environment variable. `Hello ${NAME}` will be replaced
with `Hello, John` if `NAME="John"`. If the company ships the above `.hgrc`
file as `~/dotenv/company/hgrc.tmpl`, the file template will be expanded to
`~/.hgrc` based on the available environment variables.

### Profile configuration

Because you might not want to leak all these variables in an exported
environment each profile contains a **profile configuration**
(`~/.dotenv/profiles/*/config.dotenv.sh`), which is a bash script that defines
the variables to be expanded when updating a template file.

### File fragments

Now we have a configurable `~/.hgrc` file that is always going to be in
sync with upstream updates. But what if you'd like to add your own customization
to the `~/.hgrc` file? If you edit it manually, it might be overridden by a future
update (or at least, create a conflict). Ideally, you would
combine the company template file with you own personal extensions. Dotenv
makes it possible with **file fragments**. A file fragment is defined in a
*profile* or a *profile template* and is suffixed with `.pre`, `.post` or
`.pre.N`, `.post.N` (where `N` is a number).

When applying a profile, dotenv will *assemble* the fragments into one file:

```
$ dotenv-apply
~/.hgrc ← personal:hgrc.pre company:hgrc.tmpl personal:hgrc.post
```

If there are many fragments, like `hgrc.pre hgrc.pre.0 hgrc.tmpl hg.post.tmpl`,
they will be assembled in stages: `*.pre .pre.* | sort | uniq` first,  then
the file, then `*.post .post.* | sort | uniq`. Any file ending in `.tmpl` (once
the `.pre*` and `.post*` suffixes were removed) will be expanded using the
profile configuration.

## How does it work?

Dotenv acts a little bit like a primitive build system that makes
use of the following directories:

- `~/.dotenv/templates/*`, which contains the files, file templates and fragments
   that make a **profile template**. Profile templates can be managed with
   a version control tool or rsync'ed from somewhere. The templates
   are really only useful if you'd like multiple profiles to share some elements.

- `~/.dotenv/profiles/*`, which contains files merged from profile templates (`dotenv-apply TEMPLATE…`),
  *profile configuration* as well as additional files, file templates and file fragments.

- `~/.dotenv/managed`, which contains all the files resulting from the 
  application of the active profile (`dotenv-apply PROFILE?`). These files are 
  going to be read-only if resulting from templates or file fragments, otherwise
  they will be a symlink to the original file in the profile.

- `~/.dotenv/backup`, which contains backups of any dotenv-managed files, so 
  that you can rollback to the environment exactly as it was.

Here's a table that illustrates how the dotfiles are built:

| Template    | Profile               | Managed                    | $HOME
| ---------   | ---------------       | ------------               | -------------------
| *∅*             | **`inputrc`**             | *`inputrc`* *symlink*        | *`~/.inputrc`* *symlink*
| *∅*             | **`hgrc.pre`**            | `hgrc.pre` *read-only*     | ↴
| **`hgrc.tmpl`** | *`hgrc.tmpl`* *symlink* | `hgrc.tmpl` *read-only*    | ↴
| **`hgrc.post`** | *`hgrc.post`* *symlink* | `hgrc.post` *read-only*    | ↴
|  *∅*            | `hgrc.post.1`         | `hgrc.post.1` *read-only*  | *`~/.hgrc`* *read-only symlink*


## How-to

## Create a dotenv profile

```
$ dotenv personal
~/.dotenv/profile/personal
```

## Add a file to your dotenv profile

```
$ dotenv -a ~/.bashrc
~/.bashrc → ~/.dotenv/profile/personal/bashrc
```

```
$ dotenv -l
~/.bashrc → ~/.dotenv/profile/personal/bashrc
```

## Use cases

### Manage my configuration files on one machine

### Manage my configuration files on MANY machines

### Manage multiple profiles on one machine

### Create a dotfile template for new members of an organization

## Command-line reference

### Profiles

- `dotenv PROFILE` ― activates the given PROFILE, which will then
   be located at `~/.dotenv/profile/active`. Any file overridden by
   the profile will be backed up in `~/.dotenv/backup`.

- `dotenv PROFILE?` ― creates the profile with the given name,
   using "`default`" in case `PROFILE` is not specified.

- `dotenv -p|--profiles` ― lists the available profiles, where active
   profiles are prefixed with `*`.

- `dotenv -c|--configure` ― edits the profile's configuration and
   re-generates any file that depends on the configuration.

### Managing files

- `dotenv -a|--add FILE…` ― adds the given dotfiles to the active profile, 
   saving a backup of the original file.

- `dotenv -r|--revert FILE…` ― restores the given FILES (in your `$HOME`) to
   their original value.

- `dotenv -u|--update` ― updates and rebuilds the managed files, making sure
  all the files are up to date.

- `dotenv -l|--list` ― lists the files managed by the active profile.

- `dotenv -e FILE…` ― edits the original file(s) that were used to create the
  given files and re-apply the profile.

### Templates

Templates are similar to profiles (they contain a set of dotfiles), and can
be combined with a profile.

- `dotenv -A|--apply-template TEMPLATE…` ―  applies the given template
   to the given profile (active profile by default).

- `dotenv -R|--remove-template TEMPLATE…` ―  unapplies the given template from
  the active profile.

- `dotenv -L|--list-templates` ―  lists the available templates

- `dotenv -L|--list-template TEMPLATE` ―  lists the files available in the given
  template.

### Building and syncing

NOTE: This needs to interface with a version control system.

- `dotenv -s|--sync PUSH` ― pushes the given profiles and/or templates
   all by default.

- `dotenv -s|--sync PULL ` ― pushes the given profiles and/or templates
   all by default.

- `dotenv -s|--sync SAVE PROFILE?` ― saves the changes made to the given 
   profile.

- `dotenv -P|push PROFILE? TEMPLATE?` ― pulls the given profiles and/or templates,
   all by default.

### Advanced

- `dotenv --api COMMAND ARGS…`

## Similar tools

[GNU Stow](https://www.gnu.org/software/stow/) ― manages symlinks from 
a source directory to a target directory, and is popular for managing dotfiles.

[jbernard/dotfiles](https://github.com/jbernard/dotfiles) ― creates symlinks from
a dotfiles directory to your home directory, detecting if some dotfiles are not
linked.
