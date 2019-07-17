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
