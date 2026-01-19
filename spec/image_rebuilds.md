---
status: done
---

# Image rebuilds

## Description

Investigate whether image (re-)building works as intended and is a smooth user experience.

We have the following images:

- base
- custom
- ocx
- custom ocx

Consider the following scenarios:

1. The base image needs to be rebuilt

Does `--force` work or it will be taken from cache?
The `ocx` project image that was built on top of the base is now outdated, and needs to be rebuilt too.

2. The custom base image needs to be rebuilt

Similar scenario to the default base image but with the custom `ocx` image

## Other considerations

Perhaps our current API needs to be overhauled?

Do we support a single command that can rebuild both the base image and the final image?

The `base` image uses `latest` tag, does it prevent effective rebuilds?
