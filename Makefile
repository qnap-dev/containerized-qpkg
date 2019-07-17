<<<<<<< HEAD
BUILDER_IMAGE_NAME := registry.qnap.me/qnap/qpkg-builder
DATA_DIR ?= /data
.PHONY: build
build:
	@if [ ! -f /.dockerenv ]; then \
		set -x; \
		docker pull $(BUILDER_IMAGE_NAME); \
		docker run -it --rm --net=host --name=build-pgsql \
			-e QNAP_CODESIGNING_TOKEN=bbc3888404954c228122cf4f580ba53b \
			-v /var/run/docker.sock:/var/run/docker.sock \
			-v $${PWD}:/src:ro \
			-v $${PWD}/data:$(DATA_DIR) \
			$(BUILDER_IMAGE_NAME); \
	else \
		$(MAKE) -$(MAKEFLAGS) _build; \
	fi

_build:
	fakeroot /usr/share/qdk2/QDK/bin/qbuild --build-dir build --xz amd64 && \
	cp -vf build/*.qpkg $(DATA_DIR)
clean:
	rm -rf data
=======
BUILDER_IMAGE_NAME := edhongcy/qdk2

build:
		docker run -it --rm --net=host \
        	-e QNAP_CODESIGNING_TOKEN=bbc3888404954c228122cf4f580ba53b \
        	-v $${PWD}:/example \
        	$(BUILDER_IMAGE_NAME) bash -c "cd /example;qdk2 build --qdk1 --build-arch x86_64 --build-dir build"

clean:
		rm -rf /build
>>>>>>> 8aabcf89b55fa91dfa0c70f9b8a93faabe73ca3c
