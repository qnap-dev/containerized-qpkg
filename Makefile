BUILDER_IMAGE_NAME := edhongcy/qdk2

build:
		docker run -it --rm --net=host \
        	-e QNAP_CODESIGNING_TOKEN=bbc3888404954c228122cf4f580ba53b \
        	-v $${PWD}:/example \
        	$(BUILDER_IMAGE_NAME) bash -c "cd /example;qdk2 build --qdk1 --build-arch x86_64 --build-dir build"

clean:
		rm -rf /build
