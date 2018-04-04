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

`dotenv` is a *dotfiles manager* that is designed to make it possible
to share and extend profile environments. With dotenv, it is possible
to use an existing set of configuration files and extend them locally, without
breaking upstream compatibility.

This makes `dotenv` best suited for environments where many developers want to
share a common setup, while allowing each for individual configuration and 
customization.

Features:

- Profile templates: templates can be defined and applied to a user profile,
  with overriding of specific configuration variables.

- Multiple profiles: different sets of dotfiles can be installed and managed
  
- Safe: dotenv will never override a file that it does not manages

- Easy transition: you can gradually migrate your dotfiles to `dotenv`


## Quick Start

To install `dotenv`, run:

```shell
curl https://raw.githubusercontent.com/sebastien/dotenv/master/install.sh | bash
```

This will install `dotenv` in `~/local/{bin|share}`, you can then start
managing files:

``` 
dotenv-manage ~/.bashrc ~/.vimrc ~/.vim
```

## Dependencies

`dotenv-manage ~/.bashrc`

`bash`, `sed`, `find`.

## Commands


- `dotenv PROFILE?`

    With no argument, returns the currently list of available profiles. With an argument,
    applies the given profile. If a profile is already applied, it will be
    reverted first.

- `dotenv-manage FILE…`

- `dotenv-apply TEMPLATE PROFILE`

    Applies the given `TEMPLATE` to the given `PROFILE` (or `default`). The
    profile's `config.sh` configuration will be automatically updated and 
    edited with `$EDITOR` if there is any change.

- `dotenv-configure PROFILE`

- `dotenv-merge PARENT TEMPLATE`

    Creates or updates the `TEMPLATE` so that it is derived from the
    `PARENT` template. All files of the `PARENT` template will be symlinked
    to the destination `TEMPLATE`.

- `dotenv-revert`

    Reverts any change that dotenv has made. The environment is restored exactly
    as it was before any profile was applied by dotenv.

- `dotenv-edit PATH?`

    Edits the original file that created the given dotenv-managed file.

- `dotenv-managed PATH?`

    Tells if the file at the given path is managed by dotenv. If no path is
    given, lists the files that are currently managed by dotenv.

## Similar tools

[GNU Stow](https://www.gnu.org/software/stow/) ― manages symlinks from 
a source directory to a target directory, and is popular for managing dotfiles.

[jbernard/dotfiles](https://github.com/jbernard/dotfiles) ― creates symlinks from
a dotfiles directory to your home directory, detecting if some dotfiles are not
linked.
