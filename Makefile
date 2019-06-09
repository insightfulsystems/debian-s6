export IMAGE_NAME?=insightful/ubuntu-s6
export VCS_REF=`git rev-parse --short HEAD`
export VCS_URL=https://github.com/insightfulsystems/ubuntu-s6
export BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"`
export TAG_DATE=`date -u +"%Y%m%d"`
export UBUNTU_VERSION=ubuntu:18.04
export QEMU_VERSION=4.0.0-2
export BUILD_IMAGE_NAME=local/ubuntu-base
export TARGET_ARCHITECTURES=amd64 arm64v8 arm32v7
export SHELL=/bin/bash

# Permanent local overrides
-include .env

.PHONY: build qemu wrap push manifest clean

qemu:
	-docker run --rm --privileged multiarch/qemu-user-static:register --reset
	-mkdir tmp 
	cd tmp && \
	curl -L -o qemu-arm-static.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/v$(QEMU_VERSION)/qemu-arm-static.tar.gz && \
	tar xzf qemu-arm-static.tar.gz && \
	cp qemu-arm-static ../qemu/

wrap:
	$(foreach ARCH, $(TARGET_ARCHITECTURES), make wrap-$(ARCH);)


wrap-amd64:
	docker pull amd64/$(UBUNTU_VERSION)
	docker tag amd64/$(UBUNTU_VERSION) $(BUILD_IMAGE_NAME):amd64

translate-%: # translate our architecture mappings to s6's
	@if [[ "$*" == "aarch64" ]] ; then \
	   echo "arm64v8"; \
	else \
		echo $*; \
	fi 

wrap-%:
	$(eval ARCH := $*)
	docker build --build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg ARCH=$(ARCH) \
		--build-arg BASE=$(ARCH)/$(UBUNTU_VERSION) \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg VCS_URL=$(VCS_URL) \
		-t $(BUILD_IMAGE_NAME):$(ARCH) qemu

build:
	$(foreach ARCH, $(TARGET_ARCHITECTURES), make build-$(ARCH);)


translate-%: # translate our architecture mappings to s6's
	@if [[ "$*" == "arm32v7" ]] ; then \
	   echo "armhf"; \
	elif [[ "$*" == "arm32v6" ]] ; then \
	   echo "arm"; \
	else \
		echo $*; \
	fi 

build-%:
	$(eval ARCH := $*)
	docker build --build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg ARCH=$(shell make translate-$(ARCH);) \
		--build-arg BASE=$(BUILD_IMAGE_NAME):$(ARCH) \
		--build-arg VERSION=$(S6_OVERLAY_VERSION) \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg VCS_URL=$(VCS_URL) \
		-t $(IMAGE_NAME):$(ARCH) src
	@echo "--- Done building $(ARCH) ---"

push:
	docker push $(IMAGE_NAME)

push-%:
	$(eval ARCH := $*)
	docker push $(IMAGE_NAME):$(ARCH)

expand-%: # expand architecture variants for manifest
	@if [ "$*" == "amd64" ] ; then \
	   echo '--arch $*'; \
	elif [[ "$*" == *"arm"* ]] ; then \
	   echo '--arch arm --variant $*' | cut -c 1-21,27-; \
	fi

manifest:
	docker manifest create --amend \
		$(IMAGE_NAME):latest \
		$(foreach ARCH, $(TARGET_ARCHITECTURES), $(IMAGE_NAME):$(ARCH) )
	$(foreach ARCH, $(TARGET_ARCHITECTURES), \
		docker manifest annotate \
			$(IMAGE_NAME):latest \
			$(IMAGE_NAME):$(ARCH) $(shell make expand-$(ARCH));)
	docker manifest push $(IMAGE_NAME):latest

clean:
	-docker rm -fv $$(docker ps -a -q -f status=exited)
	-docker rmi -f $$(docker images -q -f dangling=true)
	-docker rmi -f $(BUILD_IMAGE_NAME)
	-docker rmi -f $$(docker images --format '{{.Repository}}:{{.Tag}}' | grep $(IMAGE_NAME))
