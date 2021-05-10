###############################################################################
#
# Makefile for LXR AVR firmware
# Author: Patrick Dowling, Julian Schmidt
#
# Requires either
# * AVR compiler (avr-gcc et al) in path, or
# * AVR_TOOLKIT_ROOT set to installation directory
#
###############################################################################

###############################################################################
# OPTIONS

BINARY ?= quantizer.hex
MAP ?= $(addprefix $(dir $(BINARY)), quantizer.map)

ifeq ($(DEBUG),1)
DEFINES += -DDEBUG
else
DEFINES += -DNDEBUG
endif

ifndef AVR_OPTIMIZE
AVR_OPTIMIZE=s
endif

# if VERBOSE is defined, spam output
ifdef VERBOSE
AT :=
ECHO := @true
LDFLAGS += -v
else
AT := @
ECHO := @echo
endif

ifdef AVR_TOOLKIT_ROOT
BINPATH=$(AVR_TOOLKIT_ROOT)/bin/
else
BINPATH=""
endif
CC  =$(addprefix $(BINPATH),avr-gcc)
CXX =$(addprefix $(BINPATH),avr-c++)
LD  =$(addprefix $(BINPATH),avr-ld)
CP  =$(addprefix $(BINPATH),avr-objcopy)
OD  =$(addprefix $(BINPATH),avr-objdump)
AS  =$(addprefix $(BINPATH),avr-as)

###############################################################################
# SOURCE FILES
SRCDIR=.
CCSRCFILES  = $(shell find $(SRCDIR) -type f -name "*.c" | grep -v '/\.')

vpath %.c ./

###############################################################################
# SETUP

OBJDIR=./build/

ELF=$(OBJDIR)quantizer.elf

# Build object files from source...
OBJFILES = $(addprefix $(OBJDIR),$(notdir $(CCSRCFILES:.c=.o)))

# Project defines
DEFINES += -DF_CPU=20000000UL -D__PROG_TYPES_COMPAT__

CFLAGS += $(DEFINES) $(INCLUDES)
CFLAGS += -O$(AVR_OPTIMIZE)
CFLAGS += -Wall -Wextra -c -funsigned-char -funsigned-bitfields -ffast-math -freciprocal-math -ffunction-sections -fdata-sections -fpack-struct -fshort-enums
ifeq ($(PEDANTIC),1)
CFLAGS += -Werror
endif
CFLAGS += -mmcu=atmega168 -std=gnu99 -MD -MP
LDFLAGS += -Wl,-Map=$(MAP) -Wl,--start-group -Wl,-lm  -Wl,--end-group -Wl,-gc-sections -mmcu=atmega168

###############################################################################
# TARGETS

# Require explicit target
.PHONY: all
all:
	@echo "Valid targets are"
	@echo " avr : build AVR firmware"
	@echo " wav : build AVR firmware and generate bootloader wave file"
	@echo " clean : clean build directory"
	@echo " printenv : print some debug variables"
	@echo " printfiles : print list of files that would be compiled"
	

.PHONY: clean
clean:
	@$(RM) $(BINARY)
	@$(RM) $(ELF)
	@$(RM) $(OBJDIR)/*.o

.PHONY: printenv
printenv:
	@echo "AVR_TOOLKIT_ROOT='$(AVR_TOOLKIT_ROOT)'"
	@echo "CC  = $(CC)"
	@echo "CXX = $(CXX)"
	@echo "AS  = $(AS)"

.PHONY: printfiles
printfiles:
	@echo "** C FILES **"
	@echo "$(CCSRCFILES)"
	@echo ""

	@echo "** CXX FILES **"
	@echo "$(CXXSRCFILES)"
	@echo ""

	@echo "** S FILES **"
	@echo "$(ASSRCFILES)"
	@echo ""

.PHONY: avr
avr: $(BINARY)

$(ELF): $(OBJFILES)
	$(ECHO) "Linking $@..."
	$(AT)$(CC) $(LDFLAGS) $^ -o $@

$(BINARY): $(ELF)
	$(ECHO) "Creating binary $@..."
	$(AT)$(CP) -O ihex -R .eeprom -R .fuse -R .lock -R .signature $^ $@

$(OBJFILES) : | $(OBJDIR)

.PHONY: wav
wav: penrose.wav

penrose.wav: $(BINARY)
	../Bootloader/c_source/hex2wav quantizer.hex penrose.wav



###############################################################################
# BUILD RULES
$(OBJDIR):
	@mkdir -p $(OBJDIR)

$(OBJDIR)%.o: %.c
	$(ECHO) "Compiling $<..."
	$(AT)$(CC) $(CFLAGS) $< -o $@

$(OBJDIR)%.o: %.S
	$(ECHO) "Assembling $<..."
	$(AT)$(AS) $(ASFLAGS) $< -o $@ > $@.lst

# Automatic dependency generation
CFLAGS += -MMD
-include $(OBJFILES:.o=.d)
