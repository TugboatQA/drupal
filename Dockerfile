ARG PHP_VERSION
FROM tugboatqa/php:${PHP_VERSION}-apache
ARG DRUPAL_VERSION

ENV DRUPAL_COMPOSER_ROOT="/var/www/drupal" \
    DRUPAL_DOCROOT="/var/www/drupal/web" \
    COMPOSER_MEMORY_LIMIT=-1

RUN set -x && apt-get update && \
  apt-get -y install libzip-dev && \
  apt-get clean && \
  docker-php-ext-install zip && \
  docker-php-ext-install opcache && \
  a2enmod headers rewrite && \
  composer create-project drupal/recommended-project:$DRUPAL_VERSION $DRUPAL_COMPOSER_ROOT || \
# Try composer 1 if the above fails.
  ( \
    composer self-update --1 && \
    rm -rf $DRUPAL_COMPOSER_ROOT && \
    composer create-project drupal/recommended-project:$DRUPAL_VERSION $DRUPAL_COMPOSER_ROOT \
  ) && \
  cd $DRUPAL_COMPOSER_ROOT && \
  composer require drush/drush --with-all-dependencies || \
# Try drush 13.x-dev if the above fails.
  composer require drush/drush:13.x@beta chi-teck/drupal-code-generator:4.x-dev --with-all-dependencies || \
# Try drush 11.x-dev if the above fails.
  composer require drush/drush:11.x-dev --with-all-dependencies && \
  mkdir -p $DRUPAL_DOCROOT/sites/default/files && \
  chgrp www-data $DRUPAL_DOCROOT/sites/default/files && \
  chmod 2775 $DRUPAL_DOCROOT/sites/default/files && \
  ln -snf $DRUPAL_DOCROOT $DOCROOT
