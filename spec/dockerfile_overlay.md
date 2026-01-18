---
status: in progress
branch: overlay-images
---

# Dockerfile overlay

---

## Description

Support allowing the user extend the `ocx` image by provide their own `Dockerfile` that uses `ocx` as base.
The `Dockerfile` overaly must be specified in the config. The name of the resulting overlay image also needs to be specified.

The purpose of this feature is to build images with an environment that is specific to the users project.

Let's focus on an example of a Ruby on Rails project.
This project will typically contain the following files:
- `ruby-version`
- `Gemfile` and `Gemfile.lock`

The user might expect to build an image with all the gems and other dependencies present.

In such a situation, they may provide a `./Dockerfile.ocx` (the path to the file, however they name it). That image must build from our `ocx` image. Also that means we should support building that image in our existing command when an overaly image is specified. If the `image_name` is also specified in the config, we must `run` with this image.
