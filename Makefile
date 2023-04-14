TARGET = devicetree-parse

DEBUG   ?= 0
ARCH    ?= x86_64
SDK     ?= macosx

SYSROOT  := $(shell xcrun --sdk $(SDK) --show-sdk-path)
ifeq ($(SYSROOT),)
$(error Could not find SDK "$(SDK)")
endif
CLANG    := $(shell xcrun --sdk $(SDK) --find clang)
CC       := $(CLANG) -isysroot $(SYSROOT) -arch $(ARCH)

CFLAGS  = -O2 -Wall -fobjc-arc
LDFLAGS =

ifneq ($(DEBUG),0)
DEFINES += -DDEBUG=$(DEBUG)
endif

FRAMEWORKS =

all: devicetree-parse devicetree-repack

devicetree-parse: devicetree-parse.o parse.o repack.o
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(DEFINES) $(LDFLAGS) -o $@ devicetree-parse.o parse.c

devicetree-repack: repack.o
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(DEFINES) $(LDFLAGS) -o $@ repack.m

devicetree-parse.o: devicetree-parse.c $(HEADERS)
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(DEFINES) $(LDFLAGS) -c -o $@ devicetree-parse.c

parse.o: parse.c $(HEADERS)
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(DEFINES) $(LDFLAGS) -c -o $@ parse.c

repack.o: repack.m $(HEADERS)
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(DEFINES) $(LDFLAGS) -c -o $@ repack.m

main.o: main.c $(HEADERS)
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(DEFINES) $(LDFLAGS) -c -o $@ main.c

clean:
	rm -f -- *.o devicetree-parse devicetree-repack
