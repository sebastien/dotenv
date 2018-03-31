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

## Commands


- `dotenv PROFILE?`

    With no argument, returns the currently list of available profiles. With an argument,
    applies the given profile. If a profile is already available, it will be 
    replaced by the new one.

- `dotenv-revert`

    Reverts any change that dotenv has made. The environment is restored exactly
    as it was before any profile was applied by dotenv.

- `dotenv-edit PATH?`

    Edits the original file that created the given dotenv-managed file.

- `dotenv-managed PATH?`

    Tells if the file at the given path is managed by dotenv. If no path is
    given, lists the files that are currently managed by dotenv.

