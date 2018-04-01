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

## Quick Start

```
$ dotenv-template work
dotenv: template "work" created at ~/.dotenv/templates/work

$ dotenv-apply work
dotenv: template "work" applied to profile "default"

```

## Dependencies

`bash`, `sed`.

## Commands


- `dotenv PROFILE?`

    With no argument, returns the currently list of available profiles. With an argument,
    applies the given profile. If a profile is already applied, it will be
    reverted first.

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

