This repository is used to build a Docker image with various versions of
[Drupal](https://drupal.org) pre-installed using the Composer
[`drupal/recommended-project`](https://github.com/drupal/recommended-project)
package. The resulting Docker image is intended for testing a Drupal module or
theme using [Tugboat](https://tugboat.qa).

# Usage with your module or theme

If you're not familiar with how to add Tugboat configuration to your repository,
please peruse the [Tugboat documentation](https://docs.tugboat.qa).

Here is an example configuration that makes use of the images from this repo,
adapted from the [Olivero theme](https://drupal.org/project/olivero) for Drupal
`8.8.x`.

```yaml
services:
  php:
    image: tugboatqa/drupal:8.8
    default: true
    http: false
    depends: mysql
    commands:
      update: |
        set -eux
        # Check out a branch using the unique Tugboat ID for this repository, to
        # ensure we don't clobber an existing branch.
        git checkout -b $TUGBOAT_REPO_ID
        # Composer is hungry. You need a Tugboat project with a pretty sizeable
        # chunk of memory.
        export COMPOSER_MEMORY_LIMIT=-1
        # This is an environment variable we added in the Dockerfile that
        # provides the path to Drupal composer root (not the web root).
        cd $DRUPAL_COMPOSER_ROOT
        # We configure the Drupal project to use the checkout of the module as a
        # Composer package repository.
        composer config repositories.tugboat vcs $TUGBOAT_ROOT
        # Now we can require this theme, specifing the branch name we created
        # above that uses the $TUGBOAT_REPO_ID environment variable.
        composer require drupal/olivero:dev-$TUGBOAT_REPO_ID -vvv

        # Install Drupal on the site.
        vendor/bin/drush \
          --yes \
          --db-url=mysql://tugboat:tugboat@mysql:3306/tugboat \
          --site-name=Olivero \
          --account-pass=${ADMIN_PASSWORD} \
          site:install standard

        # Enable the theme.
        vendor/bin/drush --yes theme:enable olivero
        # Set the olivero theme as default.
        vendor/bin/drush --yes config-set system.theme default olivero
        # Rebuild cache.
        vendor/bin/drush cache:rebuild

        # Set up the files directory permissions.
        mkdir -p $DRUPAL_DOCROOT/sites/default/files
        chgrp -R www-data $DRUPAL_DOCROOT/sites/default/files
        chmod 2775 $DRUPAL_DOCROOT/sites/default/files
        chmod -R g+w $DRUPAL_DOCROOT/sites/default/files

      build: |
        set -eux
        export COMPOSER_MEMORY_LIMIT=-1
        cd $DRUPAL_COMPOSER_ROOT
        composer install --optimize-autoloader
        # Update this module, including all dependencies.
        composer update drupal/olivero --with-all-dependencies
        vendor/bin/drush --yes updb
        vendor/bin/drush cache:rebuild

  mysql:
    image: tugboatqa/mariadb
```

For each different major version of Drupal, you will likely have a different
branch of your module. In each of those branches, modify the Tugboat config
above to use the appropriate Docker image with the same major version of Drupal.

# Available tags.

The available tags for this image are taken directly from the available tags
of the [`drupal/recommended-project`](https://github.com/drupal/recommended-project/tags)
Composer project. In addition, `[MAJOR].[MINOR]` tags are available. For
example, if you would like the latest `9.0.x` version of Drupal core, you can
use `tugboatqa/drupal:9.0`, which, at the time of this writing, is equivalent to
`tugboatqa/drupal:9.0.0-beta2`.

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
- `PHP_VERSION`: The version of PHP to use.
