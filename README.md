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

**Example `.tugboat/config.yml` file:**
```yaml
services:
  php:
    image: q0rban/tugboat-drupal:9.0
    default: true
    http: false
    depends: mysql
    commands:
      update: |
        set -eux
        # Check out a branch using the unique Tugboat ID for this repository, to
        # ensure we don't clobber an existing branch.
        git checkout -b $TUGBOAT_REPO_ID
        # This is an environment variable we added in the Dockerfile that
        # provides the path to Drupal composer root (not the web root).
        cd $DRUPAL_COMPOSER_ROOT
        # If you need to change the minimum stability due to downstream
        # dependencies, you can modify 'stable' below to your needs:
        # see https://getcomposer.org/doc/04-schema.md#minimum-stability
        composer config minimum-stability stable
        # We configure the Drupal project to use the checkout of the module as a
        # Composer package repository.
        composer config repositories.tugboat vcs $TUGBOAT_ROOT
        # Now we can require this theme, specifing the branch name we created
        # above that uses the $TUGBOAT_REPO_ID environment variable.
        composer require drupal/olivero:dev-$TUGBOAT_REPO_ID

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
        # Delete and re-check out this branch in case this is built from a Base Preview.
        git branch -D $TUGBOAT_REPO_ID || true
        git checkout -b $TUGBOAT_REPO_ID || true
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
of the
[`drupal/recommended-project`](https://github.com/drupal/recommended-project/tags)
Composer project. In addition, `[MAJOR]` and `[MAJOR].[MINOR]` tags are
available. For example, if you would like the latest `10.0.x` version of Drupal
core, you can use `q0rban/tugboat-drupal:10.0`. If you only want to specify the
major version and keep up with minor releases automatically, you can use
`q0rban/tugboat-drupal:10`.
