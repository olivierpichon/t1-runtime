ENABLE_TLS ?= 1
ENABLE_NET ?= 1

CONFIG ?= Release

ifeq ($(ARM),1)
	compile = \
		AR=arm-none-eabi-ar AR_host=arm-none-eabi-ar AR_target=arm-none-eabi-ar CC=arm-none-eabi-gcc CXX=arm-none-eabi-g++ gyp $(1) --depth=. -f ninja-arm -D builtin_section=.rodata -D enable_ssl=$(ENABLE_TLS) -D enable_net=$(ENABLE_NET) &&\
		ninja -C out/$(CONFIG)
else
    compile = \
        gyp $(1) --depth=. -f ninja -D enable_ssl=$(ENABLE_TLS) -D enable_net=$(ENABLE_NET) -D compiler_path="$(shell pwd)/node_modules/colony-compiler/bin/colony-compiler.js" &&\
		ninja -C out/$(CONFIG)
endif

.PHONY: all test

all: colony

clean:
	ninja -v -C out/Debug -t clean
	ninja -v -C out/Release -t clean

nuke:
	rm -rf out build

update:
	git submodule update --init --recursive
	npm install

test:
	@./tools/colony-compiler-correct.sh # check that the path lookup is correct
	@./node_modules/.bin/tap -e './tools/tap-colony.sh' test/suite/*.js test/issues/*.js test/net/*.js

test-node:
	@./node_modules/.bin/tap -e node test/suite/*.js test/issues/*.js test/net/*.js

# Targets

libcolony:
	$(call compile, libcolony.gyp)

colony:
	$(call compile, colony.gyp)

libtm-test:
	$(call compile, libtm-test.gyp)
	./out/Release/libtm-test

libtm:
	$(call compile, libtm.gyp)


# Compiler Targets

compile-axtls:
	gyp libtm.gyp --depth=. -f ninja -D enable_ssl=1 -R tm-ssl
	ninja -C out/$(CONFIG)
