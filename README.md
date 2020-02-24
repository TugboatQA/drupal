This repository is an example project to build a Docker image with various
versions of [Drupal](https://drupal.org) pre-installed using the Composer
[`drupal/recommended-project`](https://github.com/drupal/recommended-project)
package. The resulting Docker image is intended for testing a Drupal module
using [Tugboat](https://tugboat.qa).

To modify this for your own project, edit the [Makefile](./Makefile) and modify:

- `DESTINATION_DOCKER_IMAGE`: the location where the Docker image will be hosted.
- `DRUPAL_VERSIONS`: A space-separated list of desired versions of Drupal.
- `PHP_VERSION`: The version of PHP to use.

Once configured, run `make help` to see a list of available commands.

To build the different Docker tags and push them, run `make`.

Once the images are available, you should add your Drupal module's repository
to your Tugboat project. [Here](https://github.com/q0rban/graphql/pull/2) is an
example `.tugboat/config.yml` to make use of these Docker images:

```yaml
services:
  php:
    # Here's where you specify your custom Docker image and preferred tag.
    image: quay.io/q0rban/drupal:8.8
    default: true
    depends:
      - mysql
    commands:
      update: |
        set -eux
        # Check out a branch using the unique Tugboat ID for this repository, to ensure
        # we don't clobber an existing branch.
        git checkout -b $TUGBOAT_REPO_ID
        # Composer is hungry. You need a Tugboat project with a pretty sizeable chunk of
        # memory for this to work.
        export COMPOSER_MEMORY_LIMIT=-1
        # This is an environment variable we added in the Dockerfile that provides the
        # path to Drupal composer root (not the web root).
        cd $DRUPAL_COMPOSER_ROOT
        # We configure the Drupal project to use the checkout of the module as a
        # Composer package repository.
        composer config repositories.tugboat vcs $TUGBOAT_ROOT
        # Now we can require this module, specifing the branch name we created above
        # that uses the $TUGBOAT_REPO_ID environment variable.
        composer require drupal/graphql:dev-$TUGBOAT_REPO_ID
        # Seems like this might be a bug in the GraphQL module. I needed to explicitly
        # require this dependency.
        composer require drupal/typed_data
        # Install Drupal!
        vendor/bin/drush --yes --db-url=mysql://tugboat:tugboat@mysql:3306/tugboat site:install standard
        # Enable our module!
        vendor/bin/drush --yes en graphql
      build: |
        set -eux
        export COMPOSER_MEMORY_LIMIT=-1
        cd $DRUPAL_COMPOSER_ROOT
        composer install --optimize-autoloader
        # Update this module, including all dependencies.
        composer update drupal/graphql --with-all-dependencies
        # Run Drupal update scripts.
        vendor/bin/drush --yes updb
        vendor/bin/drush cache:rebuild
  mysql:
    image: tugboatqa/percona:5.6
    commands:
      init:
        - printf '[mysqld]\ninnodb_log_file_size = 50331648\nmax_allowed_packet = 128M\n' > /etc/my.cnf.d/zzz.cnf
        - sv restart percona
```

For each different major version of Drupal, you will likely have a different
branch of your module. In each of those branches, modify the Tugboat config
above to use the appropriate Docker image with the same major version of Drupal.
