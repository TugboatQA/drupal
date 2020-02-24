ARG PHP_VERSION
FROM tugboatqa/php:${PHP_VERSION}-apache

ARG DRUPAL_VERSION
ARG COMPOSER_MEMORY_LIMIT

ENV DRUPAL_COMPOSER_ROOT /var/www/drupal
ENV DRUPAL_DOCROOT $DRUPAL_COMPOSER_ROOT/web

RUN composer create-project drupal/recommended-project:^$DRUPAL_VERSION $DRUPAL_COMPOSER_ROOT && \
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
