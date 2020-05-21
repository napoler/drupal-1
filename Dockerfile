# from https://www.drupal.org/docs/8/system-requirements/drupal-8-php-requirements
FROM php:7.3-apache-stretch
# TODO switch to buster once https://github.com/docker-library/php/issues/865 is resolved in a clean way (either in the PHP image or in PHP itself)

# install the PHP extensions we need
RUN set -eux; \
	\
	if command -v a2enmod; then \
		a2enmod rewrite; \
	fi; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libfreetype6-dev \
		libjpeg-dev \
		libpng-dev \
		libpq-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype-dir=/usr \
		--with-jpeg-dir=/usr \
		--with-png-dir=/usr \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		gd \
		opcache \
		pdo_mysql \
		pdo_pgsql \
		zip \
	; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# 修改为国内源
COPY sources.list /etc/apt/


WORKDIR /var/www/html

# https://www.drupal.org/node/3060/release
# ENV DRUPAL_VERSION 8.8.6
# ENV DRUPAL_MD5 b88151bb2edc48f5f6950dda6c758260

# RUN set -eux; \
# 	curl -fSL "https://ftp.drupal.org/files/projects/drupal-${DRUPAL_VERSION}.tar.gz" -o drupal.tar.gz; \
# 	echo "${DRUPAL_MD5} *drupal.tar.gz" | md5sum -c -; \
# 	tar -xz --strip-components=1 -f drupal.tar.gz; \
# 	rm drupal.tar.gz; \
# 	chown -R www-data:www-data sites modules themes
RUN set -eux; \
	curl -fSL "https://ftp.drupal.org/files/projects/lightning-8.x-4.103-core.tar.gz" -o drupal.tar.gz; \
	tar -xz --strip-components=1 -f drupal.tar.gz; \
	rm drupal.tar.gz; \
	chown -R www-data:www-data sites modules themes

# vim:set ft=dockerfile:
RUN curl -sS https://getcomposer.org/installer | php \
  && mv composer.phar /usr/local/bin/composer \
  && curl -L -o drush.phar https://github.com/drush-ops/drush-launcher/releases/download/0.4.2/drush.phar \
  && chmod +x drush.phar \
  && mv drush.phar /usr/local/bin/drush \
  && curl -L -o drupal.phar https://drupalconsole.com/installer \
  && chmod +x drupal.phar \
  && mv drupal.phar /usr/local/bin/drupal \
  && echo "export PATH=~/.composer/vendor/bin:\$PATH" >> ~/.bash_profile \
  && composer config -g repo.packagist composer https://packagist.phpcomposer.com \
  && composer require drupal/console:~1.0 --prefer-dist --optimize-autoloader

# php -S localhost:80 /var/www/html
#运行服务
# ENTRYPOINT [ "php", "-S", "0.0.0.0:80","/var/www/html" ]
# CMD curl -fs http://localhost/ || exit 1
