---
status: done
branch: custom-base-image
---

# Custom base image

---

## Description

### Feature

Support allowing the user extend the `ocx` image by providing their own base image that `ocx` uses as "from" image.
Example use cases:

- user wants to add extra packages
- user wants the image to have an environment specific to their project, e.g. a Ruby-on-Rails app or a Rust app

### Config

We need to add to more fields in the config:
- for a dockerfile for a custom base
- for a image name of the custom base

### Commands

#### `build`

If the user specifies the name of the base image in the config, then the `build` command should use this image as a base.

If the image does not exist, but the user has specified a custom `Dockerfile` in the config,
then `build` command should use the custom dockerfile to build the base.

The custom dockerfile path can point to either of these locations:
- **global config**: ~/.config/ocx/<dirname>/<dockerfile-name>
- **project**: ./<path-to-dockerfile>

We should resolve the absolute path by checking whether either of these files exist with priority given to local project.
The build context for the base image should be the directory where the dockerfile has been discovered in.

### Image naming

The name of the resulting custom image should be in the format:
`ocx-<custom-base-image>:<opencode-version>`

#### `opencode`

When the name of the custom base image is specified in the config, `opencode` command should attempt to use a custom image.

It is not required that the custom dockerfile is specified, the "custom base image" may already exist on the system because
the user may have built it manually or simply providing their existing project image that we will extend with opencode.

### Errors

If the custom image does not exist and a custom dockerfile has not been provided, it is an error.

### Considerations

- we should be able to extend most images because we download `opencode` as a standalone binary
- we should make sure that the location that we place `opencode` binary in is in the PATH
- we have a more complex user name, UID, GID mapping logic. Check if it can work with custom bases, if it can't, prioritize the custom base image functionality
