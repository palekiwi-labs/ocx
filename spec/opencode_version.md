---
status: todo
---

# Opencode Version

---

## Description

Right now we are hardcoding the version of opencode in: `src/docker_tools/build.nu`

It is essential that the version of opencode can be easily set and updated by the user.
We need to analyze how to approach this.

There are a couple of aspects to is:

### What version does the `build` command build for?

Right now it is hardcoded inline without any user control.
We should move it into the config (with some default).

### When we run `ocx run`, what is the version of the image being run?

Right now it is the `latest`.
How does it related to the version that we will set in the config?
Should we even be using `latest` at all or always be explicit with a number?

### How are users expected to stay up to date?

Some users will actively track the release information and will prefer to manually upgrade/downgrade by updating the value in their config.

However, other users may appreciate the feature of having the version set in their config to `latest`.
In such case, we would need to periodically check the github releases (run an http request?) to check the latest release,
compare it to the latest local release, and prompt the user if they would like to update?

### `update` command

If we implement the above release check mechanism, we can expose it under `ocx update` command that would perform the check
and prompt the user if they want to update.
