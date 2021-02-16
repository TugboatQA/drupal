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
  composer create-project drupal/recommended-project:$DRUPAL_VERSION $DRUPAL_COMPOSER_ROOT || \
# Try composer 1 if the above fails.
  ( \
    composer self-update --1 && \
    rm -rf $DRUPAL_COMPOSER_ROOT && \
    composer create-project drupal/recommended-project:$DRUPAL_VERSION $DRUPAL_COMPOSER_ROOT \
  ) && \
  cd $DRUPAL_COMPOSER_ROOT && \
# Not sure why but require-dev being empty in the composer.json causes issues so
# to get around this for now I just require a dev project even though it isn't
# actually necessary.
  composer require --dev drupal/core-dev:^$DRUPAL_VERSION && \
  composer require drush/drush && \
  mkdir -p $DRUPAL_DOCROOT/sites/default/files && \
  chgrp www-data $DRUPAL_DOCROOT/sites/default/files && \
  chmod 2775 $DRUPAL_DOCROOT/sites/default/files && \
  docker-php-ext-install opcache && \
  a2enmod headers rewrite && \
  ln -snf $DRUPAL_DOCROOT $DOCROOT
