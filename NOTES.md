# How profiles are built

The basic idea behind `dotenv` is that environment files are built from 
templates that can be assembled, configured and expanded using commonly
available shell tools.

The *templates directory* defines templates made of text files and subdirectories.
File ending in `.tmpl` will be processed and expressions like `${NAME}` will
be replaced by their corresponding value (sourced from the profile's `config.sh` script).

```
.dotenv/templates/company
	hgrc.tmpl
	vimrc
	ctags
	vim/snippets/customlanguage.snippets
	vim/syntax/customlanguage.vim
```

Templates can be composed together using symlinks and special `.pre` and `.post`
extension. A file like `NAME.pre` will be prepended to the file `NAME`,
conversely, a file like `NAME.post` will be appended to the file `NAME`. This
also works for template files, in which case `NAME.tmpl` would have
`NAME.tmpl.pre` and `NAME.tmpl.post`. The same logic applies to directories,
where the contents will be merged. 

```
.dotenv/templates/me
	hgrc.tmpl → ../company/hgrc.tmpl
	hgrc.post
	ctags     → ../../company/ctags
	vimrc     → ../../company/vimrc
	vim       → ../../company/vim
	vim.post/syntax/myotherlanguage.vim
```

A template directory can then be applied to a `profile` with a corresponding `config.sh`
configuration file and `config.template` directory. The application of the template to the configuration file
generates the files prefixed with `R` ans `S` below. `R` files will be read-only
while `S` files will be symlinks.

```
.dotenv/profile/default
    config.sh
    config.template.0 → ../../templates/me
R   config.manifest
R   hgrc
S   vimrc → ../../templates/me/vimrc
S   vim/syntax/myotherlanguage.vim  → ../../templates/me/vim.post/syntax/myotherlanguage
S   vim/snippets/…
```

The `config.manifest` will hold a mapping of the generate files along with
their signature. The manifest allows for the verification of any change made to
the generate files.

Finally, a profile can be deployed to the user's `$HOME`. Before the deployment
happens, any file or directory that would be overridden by the deployment is archived
and backed up.

```
.hgrc  » ~/.dotenv/backup/default/hgrc
.vimrc » ~/.dotenv/backup/default/vimrc
.vim   » ~/.dotenv/backup/default/vim
```

Once the files and directories are backed up the, symlinks are created to
from the `$HOME` to the profile files and directories.

```
.hgrc  → ~/.dotenv/profile/default/hgrc
.vimrc → ~/.dotenv/profile/default/vimrc
```

Now, if a profile was previously applied, the profile will be *reverted*, which
means that the backed up files will all be restored.

If a profile is being reverted but some of the *generated files were changed*, the
revert will backup the file in a `dotenv-$PROFILE-$DATE.backup` directory and
notify the user of an error.

If a *generated file is missing*, a warning will be issued and the process
will continue.

If *files were added* to managed directories, a list of these
extra files will be issued at the end of a revert and will be left intact.
