# Run "make help" to see a description of the targets in this Makefile.

SHELL := /bin/bash

# The destination image to push to.
export DESTINATION_DOCKER_IMAGE ?= tugboatqa/drupal
export DOCKER_IMAGE_MIRROR ?= q0rban/tugboat-drupal

## You probably don't need to modify any of the following.
export DRUPAL_VERSIONS = $(shell cat ${BUILD_DIR}/drupal_versions 2>/dev/null)
# Today's date.
export DATE := $(shell date "+%Y-%m-%d")
# The directory to keep track of build steps.
export BUILD_DIR := build-${DATE}

# Determine the major version from a full Drupal version.
export DRUPAL_MAJ = $(shell echo $(*)  | awk -F . '{print $$1}')
# Determine the major and minor version from a full Drupal version.
export DRUPAL_MAJ_MIN = $(shell echo $(*) | awk -F . '{print $$1"."$$2}')
# Determine the most recent version for this Drupal version. For example, given
# versions 8.8.1, 8.8.2, 8.8.3, if 8.8.1 is passed, 8.8.3 is returned.
export DRUPAL_LATEST_MAJ_MIN = $(lastword $(filter $(DRUPAL_MAJ_MIN).%,$(DRUPAL_VERSIONS)))
# Determine the most recent stable version of Drupal, which is the lastword.
export DRUPAL_LATEST := $(lastword $(DRUPAL_VERSIONS))
# Determine the correct version of PHP for the Drupal version.
# See https://www.drupal.org/docs/system-requirements/php-requirements
D11_PHP_VERSION := 8.3
D11_PHP_ALT_VERSIONS := 8.4
D10_PHP_VERSION := 8.1
D10_PHP_ALT_VERSIONS := 8.2 8.3
D9_PHP_VERSION := 8.1
D8_PHP_VERSION := 7.4
export PHP_VERSION = $(D$(DRUPAL_MAJ)_PHP_VERSION)
export PHP_ALT_VERSIONS = $(D$(DRUPAL_MAJ)_PHP_ALT_VERSIONS)

.PHONY: all
all: push-image ## Run all the targets in this Makefile required to tag a new Docker image.

.PHONY: help
help: ## Print out the help for this Makefile.
	@printf '\n%s\n' '-----------------------'
	@$(MAKE) targets

# To add a target to the help, add a double comment (##) on the target line.
.PHONY: targets
targets: ## Print out the available make targets.
# 	# This was stolen and adapted from:
# 	# https://github.com/nodejs/node/blob/f05eaa4a537ed7ef57814d951d64c25ef2844720/Makefile#L73-L78.
	@printf "Available targets:\n\n"
	@grep -h -E '^[a-zA-Z0-9%._-]+:.*?## .*$$' Makefile 2>/dev/null | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@printf "\nFor more targets and info see the comments in the Makefile.\n"

.PHONY: push-image
push-image: build ## Push the tagged images to the docker registry.
#	# Push the images.
	docker push --all-tags ${DESTINATION_DOCKER_IMAGE}
	docker push --all-tags ${DOCKER_IMAGE_MIRROR}
#	# Clean up after ourselves.
	$(MAKE) clean

.PHONY: tag
build: ${BUILD_DIR}/drupal_versions ## Run docker buildx.
	@$(MAKE) $(addprefix add-target-,$(DRUPAL_VERSIONS))
	@$(MAKE) $(addprefix add-phpalt-targets-,$(DRUPAL_VERSIONS))
	docker buildx bake

.PHONY: add-target-%
add-target-%: ${BUILD_DIR}/tags-% ## Build the target for a drupal version and add it to the bake file.
	@$(MAKE) generate-target-json \
	  key="$(subst .,-,$(*))" \
 	  tags="$$(xargs < ${BUILD_DIR}/tags-$(*))" \
	  drupal_version="$(*)" \
	  php_version="$(PHP_VERSION)";

.PHONY: add-phpalt-targets-%
add-phpalt-targets-%: ${BUILD_DIR}/tags-%
	@if test -n "$(PHP_ALT_VERSIONS)"; then \
	  for PHP_ALT_VERSION in $(PHP_ALT_VERSIONS); do \
		$(MAKE) generate-target-json \
	      key="$(subst .,-,$(*))-php$${PHP_ALT_VERSION//\./-}" \
	      drupal_version="$(*)" \
	      php_version="$$PHP_ALT_VERSION" \
	      tags="$$(cat ${BUILD_DIR}/tags-$(*) | grep -v latest | sed -e "s/$$/-php$$PHP_ALT_VERSION/g" | xargs)"; \
	  done; \
	fi

.PHONY: generate-target-json
generate-target-json: docker-bake.json
	@test -n "$$key" && test -n "$$tags" && test -n "$$drupal_version" && test -n "$$php_version"
	@jq \
	  --arg key "$$key" \
	  --arg tags "$$tags" \
	  --arg drupal_version "$$drupal_version" \
	  --arg php_version "$$php_version" \
	  '.target += {($$key): {context: ".", dockerfile: "Dockerfile", args: {DRUPAL_VERSION: $$drupal_version, PHP_VERSION: $$php_version}, tags: ($$tags | split(" "))}} | .group.default.targets += [$$key]' \
	  docker-bake.json > newbake.json
	@mv -f newbake.json docker-bake.json

${BUILD_DIR}/tags-%: ${BUILD_DIR}
	@echo "$(DESTINATION_DOCKER_IMAGE):$(*)" > $(@)
	@echo "$(DOCKER_IMAGE_MIRROR):$(*)" >> $(@)
	@if [ "$(*)" = "$(DRUPAL_LATEST_MAJ_MIN)" ]; then \
	  echo "$(DESTINATION_DOCKER_IMAGE):$(DRUPAL_MAJ_MIN)" >> $(@); \
	  echo "$(DOCKER_IMAGE_MIRROR):$(DRUPAL_MAJ_MIN)" >> $(@); \
	  echo "$(DESTINATION_DOCKER_IMAGE):$(DRUPAL_MAJ)" >> $(@); \
	  echo "$(DOCKER_IMAGE_MIRROR):$(DRUPAL_MAJ)" >> $(@); \
	fi
	@if [ "$(*)" = "$(DRUPAL_LATEST)" ]; then \
	  echo "$(DESTINATION_DOCKER_IMAGE):latest" >> $(@); \
	  echo "$(DOCKER_IMAGE_MIRROR):latest" >> $(@); \
	fi

${BUILD_DIR}/drupal_versions: ${BUILD_DIR}
#	# Look up the versions of Drupal to create tags for by querying the Composer
#	# drupal/recommended-project package, which can be found at
#	# https://github.com/drupal/recommended-project
#	# The sort command splits columns by hyphen and -u will ensure only uniques
#	# for the first column, so that if 10.0.0 and 10.0.0-rc4 are in the list,
#	# only the former will be used.
	@curl --fail --silent https://api.github.com/repos/drupal/recommended-project/tags | \
	  jq -r '.[].name' | \
	  sort -t '-' -uV -k 1.1,1.0 > $(@)

docker-bake.json:
	@jq -n '{group: {default: {targets: []}}, target: {}}' > docker-bake.json

${BUILD_DIR}:
	mkdir -p ${BUILD_DIR}
	@printf "Prepared build environment.\n"

clean: ## Clean up all locally tagged Docker images and build directories.
#	# Delete all image tags.
	-docker rmi $(addprefix $(DESTINATION_DOCKER_IMAGE):,$(DRUPAL_VERSIONS))
	-docker rmi $(addprefix $(DOCKER_IMAGE_MIRROR):,$(DRUPAL_VERSIONS))
#	# Remove the build dir.
	-rm -r ${BUILD_DIR}
	-rm docker-bake.json
