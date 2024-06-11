This repository is used to build a Docker image with various versions of
[Drupal](https://drupal.org) pre-installed using the Composer
[`drupal/recommended-project`](https://github.com/drupal/recommended-project)
package. The resulting Docker image is intended for testing a Drupal module or
theme using [Tugboat](https://tugboat.qa).

# Usage with your module or theme

The latest documentation for how to use this docker image with your module or
theme can be found on [drupal.org](https://www.drupal.org/docs/develop/git/using-git-to-contribute-to-drupal/using-live-previews-on-drupal-core-and-contrib-merge-requests#s-adding-live-previews-to-a-contributed-module).

If you're not familiar with how to add Tugboat configuration to your repository,
please peruse the [Tugboat documentation](https://docs.tugboat.qa).

For each different major version of Drupal, you will likely have a different
branch of your module. In each of those branches, modify the Tugboat config
above to use the appropriate Docker image with the same major version of Drupal.

# Available tags.

The available tags for this image are taken directly from the available tags
of the
[`drupal/recommended-project`](https://github.com/drupal/recommended-project/tags)
Composer project. In addition, `[MAJOR]` and `[MAJOR].[MINOR]` tags are
available. For example, if you would like the latest `10.0.x` version of Drupal
core, you can use `q0rban/tugboat-drupal:10.0`. If you only want to specify the
major version and keep up with minor releases automatically, you can use
`q0rban/tugboat-drupal:10`.
