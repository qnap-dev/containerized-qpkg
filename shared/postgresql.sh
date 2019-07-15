#!/bin/sh
CONF=/etc/config/qpkg.conf
QPKG_NAME="postgresql"
QPKG_INSTALL_PATH=`/sbin/getcfg ${QPKG_NAME} Install_Path -f ${CONF}`
DOCKER_NAME="container-station"
DOCKER_ROOT=`/sbin/getcfg $DOCKER_NAME Install_Path -f ${CONF}`

case "$1" in
  start)
    ENABLED=$(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f $CONF)
    if [ "$ENABLED" != "TRUE" ]; then
        echo "$QPKG_NAME is disabled."
        exit 1
    fi
       cd $QPKG_INSTALL_PATH
       $DOCKER_ROOT/bin/system-docker-compose -f $QPKG_INSTALL_PATH/docker-compose.yml up -d

    ;;

  stop)
       $DOCKER_ROOT/bin/system-docker-compose -f $QPKG_INSTALL_PATH/docker-compose.yml down
   ;;

  restart)
    $0 stop
    $0 start
    ;;

  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
esac

exit 0
