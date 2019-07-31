TARGET_DIR=target
DEBIAN_TARGET = target_deb

COMMIT_ID:=$(shell git rev-parse HEAD)
LAST_COMMIT_DATE=$(shell git rev-list --format=format:'%ci' --max-count=1 `git rev-parse HEAD` | tail -1)
BRANCH=$(shell git branch | grep \* | sed 's/ /\n/g' | head -2 | tail -1)

# collect packages and dependencies for later usage
PACKAGES=$(shell go list ./... | grep -v /vendor/)

WORKDIR=$(shell pwd)

# choose the environment, if BUILD_URL environment variable is available then we are on ci (jenkins)
ifdef BUILD_URL
ENVIRONMENT=ci
else
ENVIRONMENT=local
endif

UID_NR:=$(shell id -u)
GID_NR:=$(shell id -g)
BUILDDIR=$(WORKDIR)/build
TMPDIR=$(BUILDDIR)/tmp
HOMEDIR=$(TMPDIR)/home
PASSWD=$(TMPDIR)/passwd

$(TMPDIR): $(BUILDDIR)
	@mkdir $(TMPDIR)

$(TARGET_DIR):
	@mkdir $(TARGET_DIR)

$(HOMEDIR): $(TMPDIR)
	@mkdir $(HOMEDIR)

$(PASSWD): $(TMPDIR)
	@echo "$(USER):x:$(UID_NR):$(GID_NR):$(USER):/home/$(USER):/bin/bash" > $(PASSWD)

PRE_COMPILE?=
