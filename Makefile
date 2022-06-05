# Globals
.PHONY: help build clean
.DEFAULT: help
.ONESHELL:
.SILENT:
SHELL=/bin/bash
.SHELLFLAGS = -ceo pipefail

# Colours for Help Message and INFO formatting
YELLOW := "\e[1;33m"
NC := "\e[0m"
INFO := @bash -c 'printf $(YELLOW); echo "=> $$0"; printf $(NC)'

# Docker
CICD_IMAGE = cicd-environment

# Targets
BUILD = Docker Build no-cache
CLEAN = Docker clean dangling images and stopped containers

export 

help:
	$(INFO) "Run: make <target>"
	@echo -e "\n\tList of Supported Targets:"
	@echo
	@echo -e "\tbuild:\t $$BUILD"
	@echo -e "\tclean:\t $$CLEAN"

build:
	$(INFO) "$$BUILD"
	docker build --no-cache -t $$CICD_IMAGE .

clean:
	$(INFO) "$$CLEAN"
	./scripts/docker_clean.sh
