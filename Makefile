# Run "make help" to see a description of the targets in this Makefile.

# The destination image to push to.
export DESTINATION_DOCKER_IMAGE ?= q0rban/tugboat-drupal

## You probably don't need to modify any of the following.
# Look up the versions of Drupal to create tags for by querying the Composer
# drupal/recommended-project package, which can be found at
# https://github.com/drupal/recommended-project
# The sort command splits columns by hyphen and -u will ensure only uniques for
# the first column, so that if 10.0.0 and 10.0.0-rc4 are in the list, only the
# former will be used.
export DRUPAL_VERSIONS := $(shell \
  curl --silent https://api.github.com/repos/drupal/recommended-project/tags | \
  jq -r '.[].name' | \
  sort -t '-' -uV -k 1.1,1.0)
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
D10_PHP_VERSION := 8.1
D9_PHP_VERSION := 8.1
D8_PHP_VERSION := 7.4
export PHP_VERSION = $(D$(DRUPAL_MAJ)_PHP_VERSION)

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
push-image: tag ## Push the tagged images to the docker registry.
#	# Push the images.
	docker push --all-tags ${DESTINATION_DOCKER_IMAGE}
#	# Clean up after ourselves.
	$(MAKE) clean

.PHONY: tag
tag: $(addprefix ${BUILD_DIR}/build-image-,$(DRUPAL_VERSIONS)) ## Create the tags for each of the Drupal versions.

${BUILD_DIR}/build-image-%: ${BUILD_DIR}
#	# Build the Dockerfile in this directory.
	docker build \
	  --build-arg DRUPAL_VERSION=$(*) \
	  --build-arg PHP_VERSION=$(PHP_VERSION) \
	  -t $(DESTINATION_DOCKER_IMAGE):$(*) .
#	# If this is the most recent major and minor version, tag it as such.
	@if [ "$(*)" = "$(DRUPAL_LATEST_MAJ_MIN)" ]; then \
	  docker tag $(DESTINATION_DOCKER_IMAGE):$(*) $(DESTINATION_DOCKER_IMAGE):$(DRUPAL_MAJ_MIN); \
	  docker tag $(DESTINATION_DOCKER_IMAGE):$(*) $(DESTINATION_DOCKER_IMAGE):$(DRUPAL_MAJ); \
	fi
#	# If this is the latest stable Drupal version, tag it with latest.
	@if [ "$(*)" = "$(DRUPAL_LATEST)" ]; then \
	  docker tag $(DESTINATION_DOCKER_IMAGE):$(*) $(DESTINATION_DOCKER_IMAGE):latest; \
	fi
	@touch $(@)

${BUILD_DIR}:
	mkdir -p ${BUILD_DIR}
	@printf "Prepared build environment.\n"

clean: ## Clean up all locally tagged Docker images and build directories.
#	# Delete all image tags.
	-docker rmi $(addprefix $(DESTINATION_DOCKER_IMAGE):,$(DRUPAL_VERSIONS))
#	# Remove the build dir.
	-rm -r ${BUILD_DIR}
