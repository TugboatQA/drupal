# Contributing

To run the build scripts on your local build environment, you will need the
following commands available in your build environment:

- `make`
- `curl`
- [`jq`](https://stedolan.github.io/jq/)

Once configured, run `make help` to see a list of available commands.

To build the different Docker tags and push them, run `make`.

# Customizing

To create a custom image for your own project, you may fork this repository,
edit the [Makefile](./Makefile) and modify:

- `DESTINATION_DOCKER_IMAGE`: the location where the Docker image will be hosted.
