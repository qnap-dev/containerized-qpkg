From dockage/phppgadmin:latest

LABEL maintainer="ED Hong <edhong@qnap.com>"

# fix bug 225556 postgresql tools is to old
RUN echo "http://dl-cdn.alpinelinux.org/alpine/v3.9/main" >> /etc/apk/repositories \
    && echo "http://dl-cdn.alpinelinux.org/alpine/v3.9/community" >> /etc/apk/repositories

RUN apk --no-cache --update add --upgrade apk-tools postgresql

# fix error: column p.proisagg does not exist
RUN sed -i "s/NOT pp.proisagg/pp.prokind='f'/g" /var/www/classes/database/Postgres.php \
    && sed -i "s/NOT p.proisagg/p.prokind='f'/g" /var/www/classes/database/Postgres.php

# fix bug 225557 Selenium tests page 404 Not Found
RUN sed -i "/Selenium/d" /var/www/intro.php
