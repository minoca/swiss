################################################################################
#
#   Copyright (c) 2016 Minoca Corp. All Rights Reserved
#
#   Module Name:
#
#       Swiss
#
#   Abstract:
#
#       This Makefile builds the swiss Unix-in-a-box utility.
#
#   Author:
#
#       Evan Green 2-Mar-2016
#
#   Environment:
#
#       Windows, Linux, Minoca
#
################################################################################

BINARY := swiss

##
## Define the default target.
##

all:

##
## Don't let make use any builtin rules.
##

.SUFFIXES:

##
## Define the architecture of the build machine.
##

OS ?= $(shell uname -s)
BUILD_ARCH = $(shell uname -m)
ifeq ($(BUILD_ARCH), $(filter i686 i586,$(BUILD_ARCH)))
BUILD_ARCH := x86
else ifeq ($(BUILD_ARCH), $(filter armv7 armv6,$(BUILD_ARCH)))
else ifeq ($(BUILD_ARCH), x86_64)
BUILD_ARCH := x64
else
$(error Unknown architecture $(BUILD_ARCH))
endif

ARCH ?= $(BUILD_ARCH)
DEBUG ?= chk

##
## Define build locations.
##

CURDIR := $(subst \,/,$(CURDIR))
SRCROOT ?= $(CURDIR)
SRCROOT := $(subst \,/,$(SRCROOT))
OUTROOT := $(SRCROOT)/out

VPATH := $(SRCROOT)

RCC ?= windres

SYSTEM_VERSION_MAJOR := 0
SYSTEM_VERSION_MINOR := 0
SYSTEM_VERSION_REVISION := 0
REVISION := 0

BUILD_TIME ?= $(shell echo $$((`date "+%s"` - 978307200)))
BUILD_TIME_STRING ?= "$(shell date "+%a %b %d %Y %H:%M:%S")"
BUILD_STRING ?= "($(USERNAME))"

##
## Includes directory.
##

INCLUDES += $(SRCROOT)/include;$(SRCROOT)/rtl;
ifeq ($(OS),Windows_NT)
INCLUDES += $(SRCROOT)/libc/wincsup/include
endif

##
## Define default CFLAGS if none were specified elsewhere.
##

CFLAGS ?= -Wall -Werror
ifeq ($(DEBUG), chk)
CFLAGS += -O1
else
CFLAGS += -O2 -Wno-unused-but-set-variable
endif

EXTRA_CPPFLAGS += -I $(subst ;, -I ,$(INCLUDES))                             \
                  -DSYSTEM_VERSION_MAJOR=$(SYSTEM_VERSION_MAJOR)             \
                  -DSYSTEM_VERSION_MINOR=$(SYSTEM_VERSION_MINOR)             \
                  -DSYSTEM_VERSION_REVISION=$(SYSTEM_VERSION_REVISION)       \
                  -DREVISION=$(REVISION)                                     \
                  -DBUILD_TIME_STRING=\"$(BUILD_TIME_STRING)\"               \
                  -DBUILD_TIME=$(BUILD_TIME)                                 \
                  -DBUILD_STRING=\"$(BUILD_STRING)\"                         \
                  -DBUILD_USER=\"$(USERNAME)\"                               \

ifeq ($(DEBUG), chk)
EXTRA_CPPFLAGS += -DDEBUG=1
endif

EXTRA_CFLAGS += -fno-builtin -fno-omit-frame-pointer -g \
                -ffunction-sections -fdata-sections -fvisibility=hidden

ifneq ($(OS),Windows_NT)
EXTRA_CFLAGS += -fpic
EXTRA_LDFLAGS += -pie
endif

##
## Restrict ARMv6 to armv6zk instructions to support the arm1176jzf-s.
##

ifeq (armv6, $(ARCH))
EXTRA_CPPFLAGS += -march=armv6zk -marm
endif

ifeq (x86, $(ARCH))
EXTRA_CFLAGS += -mno-ms-bitfields

##
## Quark has an errata that requires no LOCK prefixes on instructions.
##

ifneq ($(QUARK),)
EXTRA_CPPFLAGS += -Wa,-momit-lock-prefix=yes -march=i586
endif

EXTRA_CFLAGS += -mno-stack-arg-probe
endif

##
## Build binaries on windows need a .exe suffix.
##

ifeq ($(OS),Windows_NT)
BINARY := $(BINARY).exe
endif

##
## Linker flags:
##
## -T linker_script          Specifies a custom linker script.
##
## -Ttext X                  Use X as the starting address for the text section
##                           of the output file. One of the defined addresses
##                           above will get placed after the linker options, so
##                           this option MUST be last.
##
## -e <symbol>               Sets the entry point of the binary to the given
##                           symbol.
##
## -u <symbol>               Start with an undefined reference to the entry
##                           point, in case it is in a static library.
##
## -Map                      Create a linker map for reference as well.
##

ifneq (,$(TEXT_ADDRESS))
EXTRA_LDFLAGS += -Wl,-Ttext-segment=$(TEXT_ADDRESS) -Wl,-Ttext=$(TEXT_ADDRESS)
endif

ifneq (,$(LINKER_SCRIPT))
EXTRA_LDFLAGS += -T$(LINKER_SCRIPT)
endif

EXTRA_LDFLAGS += -Wl,-Map=$(OUTROOT)/$(BINARY).map          \
                 -Wl,--gc-sections                          \

##
## Assembler flags:
##
## -g                        Build with debugging symbol information.
##
## -I ...                    Specify include directories to search.
##

EXTRA_ASFLAGS += -Wa,-g

##
## Define build objects.
##

TERMLIB := $(OUTROOT)/termlib
TERMLIB_OBJS := \
    $(TERMLIB)/term.o

RTL_BASE := $(OUTROOT)/rtl/base
RTL_BASE_OBJS := \
    $(RTL_BASE)/crc32.o \
    $(RTL_BASE)/heap.o \
    $(RTL_BASE)/math.o \
    $(RTL_BASE)/print.o \
    $(RTL_BASE)/rbtree.o \
    $(RTL_BASE)/scan.o \
    $(RTL_BASE)/string.o \
    $(RTL_BASE)/time.o \
    $(RTL_BASE)/timezone.o \
    $(RTL_BASE)/wchar.o \
    $(RTL_BASE)/wprint.o \
    $(RTL_BASE)/wscan.o \
    $(RTL_BASE)/wstring.o \
    $(RTL_BASE)/wtime.o \

ifeq ($(ARCH), $(filter armv7 armv6,$(ARCH)))
RTL_BASE_OBJS += \
    $(RTL_BASE)/armv7/intrinsa.o \
    $(RTL_BASE)/armv7/intrinsc.o \
    $(RTL_BASE)/armv7/rtlarch.o \
    $(RTL_BASE)/armv7/rtlmem.o \
    $(RTL_BASE)/softfp.o \
    $(RTL_BASE)/fp2int.o

endif

ifeq ($(ARCH),x86)
RTL_BASE_OBJS += \
    $(RTL_BASE)/x86/intrinsc.o \
    $(RTL_BASE)/x86/rtlarch.o \
    $(RTL_BASE)/x86/rtlmem.o

endif

ifeq ($(ARCH),x64)
RTL_BASE_OBJS +=
    $(RTL_BASE)/x64/rtlarch.o \
    $(RTL_BASE)/x64/rtlmem.o

endif

RTLC := $(OUTROOT)/rtl/rtlc
RTLC_OBJS := \
    $(RTLC)/stubs.o

WINCSUP := $(OUTROOT)/libc/wincsup
WINCSUP_OBJS := \
    $(WINCSUP)/../regexcmp.o \
    $(WINCSUP)/../regexexe.o \
    $(WINCSUP)/strftime.o

SWISS := $(OUTROOT)/src
SWISS_COMMON_OBJS := \
    $(SWISS)/basename.o \
    $(SWISS)/cat.o \
    $(SWISS)/cecho.o \
    $(SWISS)/chmod.o \
    $(SWISS)/chroot.o \
    $(SWISS)/cmp.o \
    $(SWISS)/comm.o \
    $(SWISS)/cp.o \
    $(SWISS)/cut.o \
    $(SWISS)/date.o \
    $(SWISS)/dd.o \
    $(SWISS)/diff.o \
    $(SWISS)/dirname.o \
    $(SWISS)/easy.o \
    $(SWISS)/echo.o \
    $(SWISS)/env.o \
    $(SWISS)/expr.o \
    $(SWISS)/find.o \
    $(SWISS)/grep.o \
    $(SWISS)/head.o \
    $(SWISS)/id.o \
    $(SWISS)/install.o \
    $(SWISS)/kill.o \
    $(SWISS)/ln.o \
    $(SWISS)/ls/compare.o \
    $(SWISS)/ls/ls.o \
    $(SWISS)/mkdir.o \
    $(SWISS)/mktemp.o \
    $(SWISS)/mv.o \
    $(SWISS)/nl.o \
    $(SWISS)/od.o \
    $(SWISS)/printf.o \
    $(SWISS)/ps.o \
    $(SWISS)/pwd.o \
    $(SWISS)/reboot.o \
    $(SWISS)/rm.o \
    $(SWISS)/rmdir.o \
    $(SWISS)/sed/sed.o \
    $(SWISS)/sed/sedfunc.o \
    $(SWISS)/sed/sedparse.o \
    $(SWISS)/sed/sedutil.o \
    $(SWISS)/sh/alias.o \
    $(SWISS)/sh/arith.o \
    $(SWISS)/sh/builtin.o \
    $(SWISS)/sh/exec.o \
    $(SWISS)/sh/expand.o \
    $(SWISS)/sh/lex.o \
    $(SWISS)/sh/linein.o \
    $(SWISS)/sh/parser.o \
    $(SWISS)/sh/path.o \
    $(SWISS)/sh/sh.o \
    $(SWISS)/sh/signals.o \
    $(SWISS)/sh/util.o \
    $(SWISS)/sh/var.o \
    $(SWISS)/sort.o \
    $(SWISS)/split.o \
    $(SWISS)/sum.o \
    $(SWISS)/swiss.o \
    $(SWISS)/swlib/copy.o \
    $(SWISS)/swlib/delete.o \
    $(SWISS)/swlib/pattern.o \
    $(SWISS)/swlib/pwdcmd.o \
    $(SWISS)/swlib/string.o \
    $(SWISS)/swlib/userio.o \
    $(SWISS)/tail.o \
    $(SWISS)/tee.o \
    $(SWISS)/test.o \
    $(SWISS)/time.o \
    $(SWISS)/touch.o \
    $(SWISS)/tr.o \
    $(SWISS)/uname.o \
    $(SWISS)/uniq.o \
    $(SWISS)/wc.o \
    $(SWISS)/xargs.o

SWISS_UOS_OBJS := \
    $(SWISS)/chown.o \
    $(SWISS)/init.o \
    $(SWISS)/login/chpasswd.o \
    $(SWISS)/login/getty.o \
    $(SWISS)/login/groupadd.o \
    $(SWISS)/login/groupdel.o \
    $(SWISS)/login/login.o \
    $(SWISS)/login/lutil.o \
    $(SWISS)/login/passwd.o \
    $(SWISS)/login/su.o \
    $(SWISS)/login/sulogin.o \
    $(SWISS)/login/useradd.o \
    $(SWISS)/login/userdel.o \
    $(SWISS)/login/vlock.o \
    $(SWISS)/mkfifo.o \
    $(SWISS)/readlink.o \
    $(SWISS)/sh/shuos.o \
    $(SWISS)/ssdaemon.o \
    $(SWISS)/swlib/chownutl.o \
    $(SWISS)/swlib/uos.o \
    $(SWISS)/telnet.o \
    $(SWISS)/telnetd.o \

ifeq ($(OS),Windows_NT)
OBJS := $(TERMLIB_OBJS) \
        $(RTL_BASE_OBJS) \
        $(RTLC_OBJS) \
        $(WINCSUP_OBJS) \
        $(SWISS_COMMON_OBJS) \
        $(SWISS)/win32/swiss.rsc \
        $(SWISS)/win32/w32cmds.o \
        $(SWISS)/sh/shntos.o \
        $(SWISS)/swlib/ntos.o

LIBS += -lpsapi -lws2_32

else ifeq ($(OS),Minoca)
OBJS := $(TERMLIB_OBJS) \
        $(SWISS_COMMON_OBJS) \
        $(SWISS_UOS_OBJS) \
        $(SWISS)/cmds.o \
        $(SWISS)/swlib/minocaos.o

LIBS += -lminocaos
EXTRA_CFLAGS += -ftls-model=initial-exec
#EXTRA_CPPFLAGS += -Ic:/src/os/apps/include -Ic:/src/os/include

else ifeq ($(OS),Linux)
OBJS := $(TERMLIB_OBJS) \
        $(RTL_BASE_OBJS) \
        $(RTLC_OBJS) \
        $(SWISS_COMMON_OBJS) \
        $(SWISS_UOS_OBJS) \
        $(SWISS)/uoscmds.o \
        $(SWISS)/swlib/linux.o

LIBS += -ldl -lutil
EXTRA_CFLAGS += -ftls-model=initial-exec

else
$(error Unsupported OS $(OS))
endif

OBJDIRS := \
    $(TERMLIB) \
    $(RTL_BASE) \
    $(RTL_BASE)/$(ARCH) \
    $(RTLC) \
    $(WINCSUP) \
    $(SWISS) \
    $(SWISS)/login \
    $(SWISS)/ls \
    $(SWISS)/sed \
    $(SWISS)/sh \
    $(SWISS)/swlib \
    $(SWISS)/win32

##
## Define the linker target.
##

.PHONY: all clean

clean:
	rm -rf "$(OUTROOT)"

all: $(OUTROOT)/$(BINARY)

$(OUTROOT)/$(BINARY): $(OBJS)
	@echo Linking - $@
	@$(CC) $(CFLAGS) $(EXTRA_CFLAGS) $(LDFLAGS) $(EXTRA_LDFLAGS) -o $@ $^ $(LIBS)

$(OBJS): | $(OBJDIRS)

$(OBJDIRS):
	mkdir -p $@

##
## Generic target specifying how to compile a file.
##

$(OUTROOT)/%.o:%.c
	@echo Compiling - $<
	@$(CC) $(CPPFLAGS) $(EXTRA_CPPFLAGS) $(CFLAGS) $(EXTRA_CFLAGS) -c -o $@ $<

##
## Generic target specifying how to assemble a file.
##

$(OUTROOT)/%.o:%.S
	@echo Assembling - $<
	@$(CC) $(CPPFLAGS) $(EXTRA_CPPFLAGS) $(ASFLAGS) $(EXTRA_ASFLAGS) -c -o $@ $<

##
## Generic target specifying how to compile a resource.
##

$(OUTROOT)/%.rsc:%.rc
	@echo Compiling Resource - $<
	@$(RCC) -o $@ $<
