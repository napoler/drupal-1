# from https://www.drupal.org/docs/8/system-requirements/drupal-8-php-requirements
FROM php:7.3-fpm-alpine

# install the PHP extensions we need
# postgresql-dev is needed for https://bugs.alpinelinux.org/issues/3642
RUN set -eux; \
	\
	apk add --no-cache --virtual .build-deps \
		coreutils \
		freetype-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libzip-dev \
		postgresql-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype-dir=/usr/include \
		--with-jpeg-dir=/usr/include \
		--with-png-dir=/usr/include \
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
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --virtual .drupal-phpexts-rundeps $runDeps; \
	apk del .build-deps

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

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

# php -S localhost:80 /var/www/html
#运行服务
ENTRYPOINT [ "php", "-S", "0.0.0.0:80","/var/www/html" ]
# CMD curl -fs http://localhost/ || exit 1
