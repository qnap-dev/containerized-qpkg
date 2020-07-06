# This project is teaching how to build containerized qpkg

 - [Step 0 Ready build containerized qpkg Environment](#step-0-ready-build-containerized-qpkg-environment)
 - [Step 1 Download Sample Code](#step-1-download-sample-code)
 - [Step 2 Ready Build QPKG Environment Dockerfile](#step-2-ready-build-qpkg-environment-dockerfile)
 - [step 3 create docker-compose.yml](#step-3-create-docker-composeyml)
 - [Step 4 Edit qpkg Configuration Start-Stop Script](#step-4-edit-qpkg-configuration-start-stop-script)
 - [Step 5 Generate QPKG File](#step-5-generate-qpkg-file)
 - [reference](#reference)
---
## Step 0 Ready build containerized qpkg Environment
1. [Install Docker Engine](#https://docs.docker.com/engine/install/)
2. Install Git  
   It is easiest to install Git on Linux using the preferred package manager of your Linux distribution.
   ```
   $ sudo apt-get install git
   ```
   For other Linux distribution, please refer to [Download for Linux and Unix](#https://git-scm.com/download/linux).

---
## Step 1 Download Sample Code

1. generate qpkg project
   ```
    $ git clone https://github.com/qnap-dev/containerized-qpkg.git
   ```
---
## Step 2 Ready Build QPKG Environment Dockerfile

1. build QPKG environment Dockerfile
   
   ref:https://docs.docker.com/engine/reference/builder/
    ```Dockerfile
    FROM ubuntu:18.04

    ARG DOCKER_VER=19.03.11

    # Install build essentail tools
    RUN \
      apt-get update \
      && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git curl wget fakeroot rsync pv bsdmainutils ca-certificates openssl xz-utils make \
      && rm -rf /var/cache/debconf/* /var/lib/apt/lists/* /var/log/*

    # Install QDK
    RUN \
      git clone https://github.com/qnap-dev/QDK.git \
      && cd QDK \
      && ./InstallToUbuntu.sh install

    # Install docker client
    RUN \
      curl -sq https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_VER.tgz \
      | tar zxf - -C /usr/bin docker/docker --strip-components=1 \
      && chown root:root /usr/bin/docker

    WORKDIR /work
    ```
---
## step 3 create docker-compose.yml
1. create docker-compose.yml
    
    ref:https://docs.docker.com/compose/
    ```yaml
    version: '3.3'

    services:
      db:
        image: mysql:5.7
        volumes:
          - db_data:/var/lib/mysql
        restart: always
        environment:
          MYSQL_ROOT_PASSWORD: somewordpress
          MYSQL_DATABASE: wordpress
          MYSQL_USER: wordpress
          MYSQL_PASSWORD: wordpress

      wordpress:
        depends_on:
          - db
        image: wordpress:latest
        ports:
          - "8000:80"
        restart: always
        environment:
          WORDPRESS_DB_HOST: db:3306
          WORDPRESS_DB_USER: wordpress
          WORDPRESS_DB_PASSWORD: wordpress
          WORDPRESS_DB_NAME: wordpress
    volumes:
        db_data: {}
    ```
2. move docker-compose.yml to qpkg arch file
   ```bash
    $ mv docker-compose.yml ./x86_64
   ```
---
## Step 4 Edit qpkg Configuration Start-Stop Script

1. edit package\_routines  
   ref: https://edhongcy.gitbooks.io/qdk-qpkg-development-kit/content/package-specific-installation-functions.html
    ```bash 
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
      result=$(/usr/sbin/lsof -i :8810)
      if [ -n "$result"  ] ;then
        err_log "[App Center] wordpress installation failed. Port 8810 occupied"
        set_progress_fail
        exit 1
      fi
    }
    #
    #pkg_install(){
    #}
    #
    #pkg_post_install(){
    #}
    ```

2. edit ownCloud.sh\(start-stop script\)

    ```bash
    #!/bin/sh

    # change to persistent folder (otherwise in /share/CACHEDEV1_DATA/.qpkg/.tmp)
    cd /tmp

    # QPKG Information
    QPKG_NAME="wordpress"
    QPKG_CONF=/etc/config/qpkg.conf
    QPKG_DIR=$(/sbin/getcfg $QPKG_NAME Install_Path -f $QPKG_CONF)
    QCS_NAME="container-station"
    QCS_QPKG_DIR=$(/sbin/getcfg $QCS_NAME Install_Path -f $QPKG_CONF)
    QPKG_PROXY_FILE=/etc/container-proxy.d/$QPKG_NAME
    DOCKER_IMAGES=$(cat $QPKG_DIR/docker-images/DOCKER_IMAGES)

    DOCKER_CMD=$QCS_QPKG_DIR/bin/system-docker
    COMPOSE_CMD=$QCS_QPKG_DIR/bin/system-docker-compose

    load_image() {
      for docker_image in $DOCKER_IMAGES; do
        # check if image exist
        STATUS=$(curl -siL http://127.0.0.1:2375/images/$docker_image/json | grep HTTP)
        if [[ ! $STATUS == *"200"* ]]; then
          cat $QPKG_DIR/docker-images/$(echo $docker_image | sed -e 's?/?-?' -e 's?:?_?').tar | $DOCKER_CMD load
        fi
      done
    }

    proxy_reload() {
      /etc/init.d/thttpd.sh reload
      /etc/init.d/stunnel.sh reload
    }

    proxy_start() {
      cat > $QPKG_PROXY_FILE << EOF
    ProxyRequests off
    ProxyPass /$QPKG_NAME http://127.0.0.1:8810
    ProxyPassReverse /$QPKG_NAME http://127.0.0.1:8810
    EOF
      proxy_reload
    }

    proxy_stop() {
      rm -f $QPKG_PROXY_FILE
      proxy_reload
    }

    cd $QPKG_DIR

    case "$1" in
      start)
        ENABLED=$(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f $QPKG_CONF)
        if [ "$ENABLED" != "TRUE" ]; then
          echo "$QPKG_NAME is disabled."
          exit 1
        fi

        load_image
        $COMPOSE_CMD up -d
        proxy_start
        ;;
      stop)
        proxy_stop
        $COMPOSE_CMD down --remove-orphans
        ;;
      restart)
        $0 stop
        $0 start
        ;;
      remove)
        $COMPOSE_CMD down --rmi all -v
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
    # Name of the packaged application.
    QPKG_NAME="wordpress"
    # Name of the display application.
    QPKG_DISPLAY_NAME="wordpress"
    # Version of the packaged application. 
    QPKG_VER="5.4.2"
    # Author or maintainer of the package
    QPKG_AUTHOR="wordpress"
    # License for the packaged application
    # QPKG_LICENSE=""
    # One-line description of the packaged application
    #QPKG_SUMMARY=""

    # Preferred number in start/stop sequence.
    QPKG_RC_NUM="199"
    # Init-script used to control the start and stop of the installed application.
    QPKG_SERVICE_PROGRAM="wordpress.sh"

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
    QPKG_WEBUI="/owncloud/"
    # Port number for the web interface.
    QPKG_WEB_PORT="-1"
    # Port number for the SSL web interface.
    #QPKG_WEB_SSL_PORT="7443"

    # Minimum QTS version requirement
    QTS_MINI_VERSION="4.4.1"
    # Maximum QTS version requirement
    QTS_MAX_VERSION="4.5.0"

    # Select volume
    # 1: support installation
    # 2: support migration
    # 3 (1+2): support both installation and migration
    QPKG_VOLUME_SELECT=3

    # Location of the chroot environment (only TS-x09)
    #QPKG_ROOTFS=""
    # Init-script used to controls the start and stop of the
    # installed application (only TS-x09)
    #QPKG_SERVICE_PROGRAM_CHROOT=""
    QPKG_TIMEOUT="180,180"
    # Location of icons for the packaged application.
    QDK_DATA_DIR_ICONS="icons"
    # Location of files specific to arm-x09 packages.
    #QDK_DATA_DIR_X09="arm-x09"
    # Location of files specific to arm-x19 packages.
    #QDK_DATA_DIR_X19="arm-x19"
    # Location of files specific to aarch64 packages.
    #QDK_DATA_DIR_ARM_64="arm_64"
    # Location of files specific to x86 packages.
    #QDK_DATA_DIR_X86="x86"
    # Location of files specific to x86 (64-bit) packages.
    QDK_DATA_DIR_X86_64="x86_64"
    # Location of files common to all architectures.
    QDK_DATA_DIR_SHARED="shared"
    # Location of configuration files.
    #QDK_DATA_DIR_CONFIG="config"
    # Name of local data package.
    #QDK_DATA_FILE=""
    # Name of extra package (multiple definitions are allowed).
    #QDK_EXTRA_FILE=""
    # Official QPKG will be enable automatically when installed
    #SYS_QPKG_SERVICE_ENABLED="TRUE"
    # Script to adapt the data package files (such as file owner)
    #QDK_DATA_PACKAGE_ADAPTOR=data_package_adaptor
    # Location of building script for each architecture
    #QDK_PRE_BUILD="src/build.sh"
    #QNAP_CODE_SIGNING="1"
    #QNAP_CODE_SIGNING_SERVER_IP="172.17.21.68"
    #QNAP_CODE_SIGNING_SERVER_PORT="5000"
    #QNAP_CODE_SIGNING_CSV="build_sign.csv"
    ```
---
## Step 5 Generate QPKG File
1. create Makefile  
(build QPKG environment docker image and pull docker-compose used docker image save to x86_64 folder)

    ```Makefile
    SHELL              := /bin/bash
    BUILDER_IMAGE_NAME := qnap/qpkg-builder
    BUILD_DIR          := build
    SUPPORT_ARCH       := x86_64
    CODESIGNING_TOKEN  ?=

    COLOR_YELLOW       := \033[33m
    COLOR_BLUE         := \033[34m
    COLOR_RESET        := \033[0m

    .PHONY: build
    build: docker-builder
      @if [ ! -f /.dockerenv ]; then \
        docker run --rm -t --name=build-owncloud-qpkg-$$$$ \
          -e QNAP_CODESIGNING_TOKEN=$(CODESIGNING_TOKEN) \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v $(PWD):/work \
          $(BUILDER_IMAGE_NAME) make _build; \
      else \
        $(MAKE) -$(MAKEFLAGS) _build; \
      fi

    .PHONY: _build
    _build: docker-image
      @echo -e "$(COLOR_BLUE)### Build QPKG ...$(COLOR_RESET)"
      fakeroot /usr/share/qdk2/QDK/bin/qbuild --build-dir $(BUILD_DIR) --xz amd64

    .PHONY: docker-builder
    docker-builder:
      @echo -e "$(COLOR_BLUE)### Prepare QPKG builder: $(BUILDER_IMAGE_NAME)$(COLOR_RESET)"
      docker build -t $(BUILDER_IMAGE_NAME) .

    .PHONY: docker-image
    docker-image:
      @for img in $(shell awk -F'image: ' '/image:/ {print $$2}' x86_64/docker-compose.yml); do \
        tarball=$$(echo $${img} | sed -e 's?/?-?' -e 's?:?_?').tar; \
        echo -e "$(COLOR_BLUE)### Download container image: $${img}$(COLOR_RESET)"; \
        docker pull $${img}; \
        echo -e "$(COLOR_YELLOW)### Save container image to a tar archive: $${tarball}$(COLOR_RESET)"; \
        mkdir -p x86_64/docker-images; \
        echo $${img} >> x86_64/docker-images/DOCKER_IMAGES; \
        docker save -o x86_64/docker-images/$${tarball} $${img}; \
      done

    .PHONY: clean
    clean:
      @echo -e "$(COLOR_BLUE)### Remove build files ...$(COLOR_RESET)"
      rm -rf */{data,docker-images}
      rm -rf build{,.*}/ tmp.*/
    ```
2. Use below command to build the QPKG file
    ```bash
    [~/project_name] # make
    ```
3. The QPKG file will be generated in the build folder

    ```bash
    [~/project_name] # ls -la build
    total 243476
    drwxr-xr-x 2 root   root        4096 Jun 30 15:23 .
    drwxrwxr-x 7 edhong edhong      4096 Jun 30 15:23 ..
    -rw-r--r-- 1 root   root   249306533 Jun 30 15:23 owncloud_10.4.1_x86_64.qpkg
    -rw-r--r-- 1 root   root          68 Jun 30 15:23 owncloud_10.4.1_x86_64.qpkg.md5
    ```
4. Clean up
    ```bash
    [~/project_name] # make clean
    ### Remove build files ...
    rm -rf */{data,docker-images}
    rm -rf build{,.*}/ tmp.*/
    ```
---
## reference

Docker install doc:  
https://docs.docker.com/engine/install/

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

qnap-packageing:  
https://github.com/walkerlee/qnap-packaging
