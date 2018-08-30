
Major
=====

[ ] dotenv -a ~/.config/fish/config.fish does not work


Edge cases
==========

[X] dotenv -r FILE should restore the original backup if present
[ ] dotenv -r ~/config should revert `~/.config/*`
[ ] dotenv -a ~/.hgignore cp complains files are the same
[ ] dotenv -u: backs up too many files!
[ ] Switching profiles: should restore the files
[ ] User removes/add files from .dotenv/active, we need to sync the managed
[ ] install: restore support for symlinks
[ ] configure: output missing configuration variables

Bugs
====

B000 ― When there is `npmrc` and `npmrc.tmpl` too many fragments are listed
B001 − When adding a new file, it is not properly added to managed
