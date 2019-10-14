# This project is teaching how to build containerized qpkg

- [step 1: ready development environment](#step-1:-ready-development-environment)
- [step 2: build docker image](#step-2:-build-docker-image)
- [step 3: create qpkg project](#step-3:-create-qpkg-project)
- [step 4: edit qpkg configuration and start-stop script](#step-4-edit-qpkg-configuration-start-stop-script)
- [step 5: generate QPKG file](#step-5:-generate-qpkg-file)
- [reference](#reference)

---
## step 1: ready development environment

1. How to install QDK
    > a. Install QDK on QNAP NAS:  
    https://github.com/qnap-dev/QDK#qdk-download-link
    
    > b. Install QDK on ubuntu:  
    https://github.com/qnap-dev/QDK#how-to-install-qdk-in-ubuntu

2. github postgresql project:  

---
## step 2: build docker image
1. Create Dockerfile    
    ref:https://docs.docker.com/engine/reference/builder/
2. Build and pull docker image
    ```
    $ docker build -t phppgadmin:latest .
    $ docker pull postgres:11.4
    ```

3. save docker image to tar file
    ```
    $ docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
    phppgadmin          latest              f68d6e55e065        9 hours ago         109MB
    $ docker save -o  phppgadmin.tar phppgadmin:latest
    $ docker save -o  postgres_11_4.tar postgres:11.4
    ```
---
## step 3: create qpkg project

1. generate qpkg project
   ```
    $ qbuild --create-env postgresql
    $ # or
    $ git clone

   ```
2. move docker image tar file to qpkg arch file
   ```
    $ mv phppgadmin.tar postgresql/x86_64
    $ mv postgres_11_4.tar postgresql/x86_64
   ```
3. create docker-compose.yml 
    ref:https://docs.docker.com/compose/
   ```bash
    version: '3'

    services:
      db:
        image: postgres:11.4
        restart: on-failure
        ports:
          - 5432:5432
        volumes:
          - ./data:/var/lib/postgresql/data
        environment:
          - POSTGRES_PASSWORD=postgres

      web:
        image: edhongcy/phppgadmin:latest
        restart: on-failure
        ports:
          - 7070:80
          - 7443:443
        depends_on:
          - db
        environment:
          - PHP_PG_ADMIN_SERVER_DESC=PostgreSQL
          - PHP_PG_ADMIN_SERVER_HOST=db
          - PHP_PG_ADMIN_SERVER_PORT=5432
          - PHP_PG_ADMIN_SERVER_SSL_MODE=allow
          - PHP_PG_ADMIN_SERVER_DEFAULT_DB=template1
          - PHP_PG_ADMIN_SERVER_PG_DUMP_PATH=/usr/bin/pg_dump
          - PHP_PG_ADMIN_SERVER_PG_DUMPALL_PATH=/usr/bin/pg_dumpall

          - PHP_PG_ADMIN_DEFAULT_LANG=auto
          - PHP_PG_ADMIN_AUTO_COMPLETE=default on
          - PHP_PG_ADMIN_EXTRA_LOGIN_SECURITY=false
          - PHP_PG_ADMIN_OWNED_ONLY=false
          - PHP_PG_ADMIN_SHOW_COMMENTS=true
          - PHP_PG_ADMIN_SHOW_ADVANCED=false
          - PHP_PG_ADMIN_SHOW_SYSTEM=false
          - PHP_PG_ADMIN_MIN_PASSWORD_LENGTH=1
          - PHP_PG_ADMIN_LEFT_WIDTH=200
          - PHP_PG_ADMIN_THEME=default
          - PHP_PG_ADMIN_SHOW_OIDS=false
          - PHP_PG_ADMIN_MAX_ROWS=30
          - PHP_PG_ADMIN_MAX_CHARS=50
          - PHP_PG_ADMIN_USE_XHTML_STRICT=false
          - PHP_PG_ADMIN_HELP_BASE=http://www.postgresql.org/docs/%s/interactive/
          - PHP_PG_ADMIN_AJAX_REFRESH=3

   ```
4. move docker-compose.yml to qpkg arch file
   ```
    $ mv docker-compose.yml postgresql/x86_64
   ```
---
## step 4: edit qpkg configuration start-stop script

1. edit package\_routines  
   ref: https://edhongcy.gitbooks.io/qdk-qpkg-development-kit/content/package-specific-installation-functions.html
   ```bash   
   ######################################################################
   # Define any package specific operations that shall be performed when
   # the package is removed.
   ######################################################################
   PKG_POST_REMOVE="{
       CONF=/etc/config/qpkg.conf
       DOCKER_NAME="container-station"
       DOCKER_ROOT=`/sbin/getcfg $DOCKER_NAME Install_Path -f ${CONF}`
       $DOCKER_ROOT/bin/system-docker rmi postgres:11.4
       $DOCKER_ROOT/bin/system-docker rmi edhongcy/phppgadmin:latest
   }"
   #
   ######################################################################
   # Define any package specific operations that shall be performed when
   # the package is installed.
   ######################################################################
   pkg_pre_install(){
     err_log() {
       local write_msg="$CMD_LOG_TOOL -t2 -uSystem -p127.0.0.1 -mlocalhost -a"
       [ -n "$1" ] && $CMD_ECHO "$1" && $write_msg "$1"
     }

   # Official QPKG will enable it when installed
     SYS_QPKG_SERVICE_ENABLED="TRUE"
     result=$(/usr/sbin/lsof -i :5432)
     if [ -n "$result"  ] ;then
       err_log "[App Center] PostgreSQL installation failed. Port 5432 occupied"
       set_progress_fail
       exit 1
     fi
   }
   #
   #pkg_install(){
   #}
   #
   pkg_post_install(){
     CONF=/etc/config/qpkg.conf
     QPKG_NAME="postgresql"
     QPKG_INSTALL_PATH=`/sbin/getcfg ${QPKG_NAME} Install_Path -f ${CONF}`
     DOCKER_NAME="container-station"
     DOCKER_ROOT=`/sbin/getcfg $DOCKER_NAME Install_Path -f ${CONF}`

     if [ -f "$QPKG_INSTALL_PATH/phppgadmin.tar" ]; then
         $DOCKER_ROOT/bin/system-docker load -i $QPKG_INSTALL_PATH/phppgadmin.tar 
         $DOCKER_ROOT/bin/system-docker load -i $QPKG_INSTALL_PATH/postgres_11_4.tar
     fi
   }

   ```

2. edit postgresql.sh\(start-stop script\)

   ```bash
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
   ```

3. edit qpkg.cfg  
   ref: https://edhongcy.gitbooks.io/qdk-qpkg-development-kit/content/qpkg-configuration-file.html

   ```
    # Name of the packaged application.                                                                                                                           QPKG_NAME="postgresql"                                                          
    # Name of the display application.                                              
    QPKG_DISPLAY_NAME="PostgreSQL"                                                  
    # Version of the packaged application.                                          
    QPKG_VER="11.4.1"                                                               
    # Author or maintainer of the package                                           
    QPKG_AUTHOR="QNAP Systems, Inc."                                                
    # License for the packaged application                                          
    #QPKG_LICENSE=""                                                                
    # One-line description of the packaged application                              
    #QPKG_SUMMARY=""                                                                
                                                                                
    # Preferred number in start/stop sequence.                                      
    QPKG_RC_NUM="101"                                                               
    # Init-script used to control the start and stop of the installed application.  
    QPKG_SERVICE_PROGRAM="postgresql.sh"                                            
                                                                                
    # Specifies any packages required for the current package to operate.           
    QPKG_REQUIRE="container-station >= 2.0"                                         
    # Specifies what packages cannot be installed if the current package            
    # is to operate properly.                                                       
    # QPKG_CONFLICT=""                                                              
    # Name of configuration file (multiple definitions are allowed).                
    # QPKG_CONFIG="myApp.conf"                                                      
    # QPKG_CONFIG="/etc/config/myApp.conf"                                          
    # Port number used by service program.                                          
    # QPKG_SERVICE_PORT="7070"                                                      
    # Location of file with running service's PID                                   
    # QPKG_SERVICE_PIDFILE=""                                                       
    # Relative path to web interface                                                
    QPKG_WEBUI="/"                                                                  
    # Port number for the web interface.                                            
    QPKG_WEB_PORT="7070"                                                            
    # Port number for the SSL web interface.                                        
    #QPKG_WEB_SSL_PORT="7443"                                                       
    # Minimum QTS version requirement                                               
    QTS_MINI_VERSION="4.4.1"                                                        
    # Maximum QTS version requirement                                               
    QTS_MAX_VERSION="4.5.0"    
   ```
---
## step 5: generate QPKG file
1. Use below command to build the QPKG file
    ```
    [~/postgresql] # qbuild
    Creating archive with data files...
    Creating archive with control files...
    Creating QPKG package...
    ```
2. The QPKG file will be generated in the build folder

    ```
    [~/postgresql] # cd build/
    [~/postgresql/build] # ls
    postgresql_11.4.1_x86_64.qpkg
    ```
---
## reference

Dockerfile doc:  
https://docs.docker.com/engine/reference/builder/

docker-compose.yml doc:
https://docs.docker.com/compose/

package\_routines doc:  
https://edhongcy.gitbooks.io/qdk-qpkg-development-kit/content/package-specific-installation-functions.html

qpkg.cfg doc:  
https://edhongcy.gitbooks.io/qdk-qpkg-development-kit/content/qpkg-configuration-file.html

QDK GitHub:  
https://github.com/qnap-dev/QDK
