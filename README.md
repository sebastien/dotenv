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
share a common setup, while allowing each for individual configuration and 
customization.

Features:

- **Profile templates**: templates can be defined and applied to a user profile,
  with overriding of specific configuration variables.

- **Multiple profiles**: different sets of dotfiles can be installed and switched
  at any point.
  
- **Safe**: dotenv will never override a file that it does not manages, and keeps
  backups of existing files it replaces.

- **Gradual transition**: progressively migrate your dotfiles using `dotenv-manage`


## Quick Start

To install `dotenv` in `~/local/{bin|share}`, run:

```shell
curl https://raw.githubusercontent.com/sebastien/dotenv/master/install.sh | bash
```

Now, start managing your existing files and directories using `dotenv`

``` 
dotenv-manage ~/.bashrc ~/.vimrc ~/.vim
```

This will move these files to `~/.dotenv/profiles/default` and create symlinks
for them. If you'd like to see the files managed by dotenv at 


## Quick reference


### Activate/deactivate a profile

- `dotenv` ― outputs the name of the currently active profile

- `dotenv --list` ― outputs the name of the currently active profile

- `dotenv PROFILE` ― activates the give PROFILE, which will then
-  be located at `~/.dotenv/profile/active`. Any file overridden by
   the profile will be backed up in `~/.dotenv/backup`.

- `dotenv none` ― deactivates the current profile, restoring the
  state of the system as it was before.

### Add/remove files to profile

- `dotenv-manage FILE…` ― adds the given files to the given profile, moving
   them to the profile directory (`~/.dotenv/profile/active`) and creating
   symlinks in place of them.

- `dotenv-unmanage FILE…` ― moves the file back from the profile directory
  to their canonical location.

- `dotenv-managed PROFILE?` ― outputs the list of files managed by the given
   profile, or the active profile by default.

## Similar tools

[GNU Stow](https://www.gnu.org/software/stow/) ― manages symlinks from 
a source directory to a target directory, and is popular for managing dotfiles.

[jbernard/dotfiles](https://github.com/jbernard/dotfiles) ― creates symlinks from
a dotfiles directory to your home directory, detecting if some dotfiles are not
linked.
