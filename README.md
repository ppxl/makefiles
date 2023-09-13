# makefiles
Makefiles for Cloudogu projects

This repository holds makefiles for building Cloudogu tools, especially those written in Go. They were created to standardize the build and release process. You should use them for every new tool you are developing in the Cloudogu environment.

Please note that `make` only accepts `Makefile`s that are **only** indented with tabs.

## Overview over make targets

Starting with makefiles v5.0.0 `make help` will produce an overview of make popular targets:

Example output:
```
make help

Usage:
  make <target>

General
  help             Display this help.
  info             Print build information

Go mod dependency management
  dependencies     Install dependencies using go mod

Compiling go software
  compile          Compile the go program via Docker
  compile-ci       Compile the go program without Docker
...
```

The actual output depends on the makefiles that your main `Makefile` includes.

You can extend the help output to your own `Makefile` in two ways:
- add a new help section description `A new section`:
   - `##@ A new section`
- add a new target description `Do something`:
  - `do-something: ## Do something`

Full example:
```makefile
#...
include build/make/variables.mk

##@ A new section

.PHONE do-something:
do-something: $(mybinary) ## Do something

#...
```

## Create a new project or update it

When creating a new project you have to import the `Makefile` and the `build` directory (with all its contents). While doing so you need to keep the directory structure, i.e. the `Makefile` and `build` folder need to be in the project's root folder.

When there is a new release of the Makefiles in the future, you can easily upgrade your Makefiles via setting the `MAKEFILES_VERSION` variable in the `Makefile` and executing the `update-makefiles` make target:

```
make update-makefiles
```

Please note that there MUST NOT be done any changes within the `${BUILD_DIR}/make/` directory. Content within this directory may be removed and added during the update of the makefiles. Usually the way how the makefiles work can be modified by these to things:

1. overwriting Makefile variables
   - usually pre- or post-target variables like `POST_UNITTESTS`
   - often these can be overwritten with project specific make targets 
1. include only one of filial makefiles that provide the an exclusive build target defined in several files
   - f. i. `dependencies-godep` vs `dependencies-glide`

The `build/make` folder holds all Makefiles referenced by the `Makefile` in the root folder. This main `Makefile` can be adjusted to your needs. For example, if you want to build a Go project and pack it into a .deb package you can adjust your `Makefile` in the following way:

### Example: Go Build with .deb package
```
ARTIFACT_ID=app
VERSION=0.1.2

MAKEFILES_VERSION= 

.DEFAULT_GOAL:=compile

include build/make/variables.mk
include build/make/info.mk
include build/make/dependencies-gomod.mk
include build/make/build.mk
include build/make/unit-test.mk
include build/make/static-analysis.mk
include build/make/clean.mk
include build/make/package-debian.mk
```

If you use the `package` make target, your `Makefile` will automatically use glide for downloading dependencies, compiles and creates a .deb package including the binary afterwards.

### Go Build and tar.gz package
If you use this kind of `Makefile`, `make package` a tar.gz-package will be created instead of a debian package (see above).

```
ARTIFACT_ID=app
VERSION=0.1.2

MAKEFILES_VERSION= 

.DEFAULT_GOAL:=compile

include build/make/variables.mk
include build/make/info.mk
include build/make/dependencies-gomod.mk
include build/make/build.mk
include build/make/unit-test-docker-compose.mk
include build/make/static-analysis.mk
include build/make/clean.mk
include build/make/package-tar.mk
```

## Modules

### variables.mk

This module holds generic definitions needed for all builds and should be always included.

### dependencies-gomod.mk

This module holds the `dependencies` target, which is utilized by the `build` target. It uses `go mod` for fetching dependencies.

### build.mk

This module holds the `build` target, which starts the build inside a Docker container (to ensure reproducible builds). It also creates a checksum of the binary.

The exact golang container that is going to be used to compile Go code can be configured by overwriting the makefile variables `GOIMAGE` and `GOTAG` in the main `Makefile`. A different Go compiler version could be achieved with a line like this:

```
GOTAG=1.15.6-buster
```

This module also supports one optional Docker volume mount to the Golang container. The sureshot default mounts the host's `/tmp` to the container `/tmp`. A custom volume mount can be expressed by overwriting the makefile variable `CUSTOM_GO_MOUNT` in your main `Makefile` with the usual Docker volume syntax:

```makefile
CUSTOM_GO_MOUNT=-v /host/path/:/container/path
``` 

When building on Jenkins CI, make sure to mount a `/etc/passwd` file according to the Jenkins user (this file can be easily generated). This mounting is even easier with the help of the [ces-build-lib](https://github.com/cloudogu/ces-build-lib) `mountJenkinsUser()` step, like so:

```
new Docker(this)
 .image('golang:1.14.13')
 .mountJenkinsUser()
 .inside
``` 

### unit-test.mk

This module ensures that you can start Golang unit tests via the `unit-test` target.

This target can be supplemented with pre- and post-targets by setting make targets to the corresponding variables in your `Makefile` (both are optional):

```makefile
    PRE_UNITTESTS=your-pre-target
    POST_UNITTESTS=your-post-target
```

### mocks.mk

This module adds configuration for mockery and generates all mocks via the `make mocks` target.

The mockery version can be specified in the make file. 
Directories can be ignored with the `MOCKERY_IGNORED` variable.
It can be overridden like this:
```Makefile
override MOCKERY_IGNORED:=${MOCKERY_IGNORED},test
```

### test-integration.mk

This module ensures that you can start Golang tests via the `integration-test` target, including an additional environment which is started and stopped using docker-compose.

Integration tests are excluded from running with the target `unit-test` by means of a build tag. Use these build tag lines to mark your test as integration test in the very first lines of the go file. 

```go
//go:build integration
// +build integration

package yourpackagegoeshere
```

The default build tag name is defined in the global variable `GO_BUILD_TAG_INTEGRATION_TEST?=integration`. While this should fit most projects it is possible to modify the name of the build tag. 

#### Pre- and Post-targets

This target can be supplemented with pre- and post-targets by setting make targets to the corresponding variables in your `Makefile` (both are optional):

```makefile
PRE_INTEGRATIONTESTS=start-local-docker-compose
POST_INTEGRATIONTESTS=stop-local-docker-compose
```

Keep in mind that if your test relies on the target `start-local-docker-compose` you should add several targets in order to properly start docker-compose. For example:

```makefile
PRE_INTEGRATIONTESTS=yourcooltarget start-local-docker-compose anothertarget
```

#### Splitting unit tests from integration tests 

This target allows also to filter test methods by regexp. This helps to avoid running regular unit-test during the integration tests, which may reside in the same package.

```makefile
INTEGRATION_TEST_NAME_PATTERN?=.*_inttest$$
```
Note the double dollar sign `$$` is Makefile escape syntax for the regexp line-end delimiter `$` (other delimiters may be escaped as well).

For example, setting this variable in your `Makefile` will filter tests that end with the suffix `_inttest`, i. e. 
- `func Test_yourStructCreate_inttest(t *testing.T)` **will be** executed
- `func Test_yourStructCreate(t *testing.T)` will **not** be executed
- `func Test_inttest_foobar(t *testing.T)` will also **not** be executed

### static-analysis.mk

This module holds the `static-analysis` target for static code analysis. It automatically determines the working environment (local or CI).

Static analysis is now powered by the official Golang containers in the very same ways as it is done in `build.mk`. Any container customizations can be applied in the same way to local static-analysis.

When running on Jenkins CI and to avoid configuration overhead it is possible to re-use  the same Golang container (that was used to compile the code) and embedd a static analysis stage there.

### clean.mk

This module holds the `clean` target to clean your workspace.

### package-debian.mk

This module enables you to build a debian package from the local contents. The `package` target will compile the binary and create a .deb file which holds the contents in the `deb` folder and the binary.
The module also enables you to build a debian package *without compiling a binary*, using the `debian` target. This makes sense for example if the debian file should consist only of configuration files.
The target `lint-deb-package` will show any errors or warnings for your built debian package.

Include only one of the files: package-debian.mk OR package-tar.mk

### deploy-debian.mk

This module enables you to deploy or undeploy the built deb package to/from the apt repository via the `deploy` respectively `undeploy` targets.

The variable `APT_REPO` determines, which repository should be used as a target. Currently, it supports the following values:
- `ces-premium`: The secured repositories are used
- any other value: The public repositories are used

If you want to use this module, you also have to include the `package-debian.mk` module!

#### Package requirements

You need a `deb` directory in order to successfully create a debian package. This directory is used to incorporate existing files and directories into the debian package. The minimum requirement for a valid debian package is a `control` file which you must place in `deb/DEBIAN/control`.

As an extended example, a proper directory could look like this:

```
deb/
 L DEBIAN/
 |  L control
 |  L postinst
 L etc/ 
    L config.file
```

Files which reside in `DEBIAN` will be subject to be stored in the `control` part of the debian package.
In turn, all other files and directories will be stored in the `data` part of the debian package. 

Please note when you are building a debian package that all files under `/deb/etc` will be named in a automatically generated file `conffiles`. Those files will be subject to debian's conflict management instead of overwriting crucial configuration files when said configuration files already exist (f. i. when a package is upgraded).

### package-tar.mk

This module lets you use the `package` target to pack a .tar archive.

Include only one of the files: package-debian.mk OR package-tar.mk

### digital-signature.mk

This module makes sure that a checksum is calculated for every file in the `target` folder and signs the checksum files.

### yarn.mk

This module enables you to use yarn via the `yarn-install` target.

### bower.mk

This module enables you to use bower via the `bower-install` target.

### release.mk

This module holds the `dogu-release` or other binary release related targets for starting automated production releases.
Additionally, to the regular `dogu-release` the module contains a `dogu-cve-release`. This target checks if a simple
build of a dogu eliminates critical CVEs. If yes a release process will be triggered.

Only include this module in dogu or Golang repositories that support a dedicated release flow!
