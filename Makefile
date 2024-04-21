BIN = kontos
VM  = kvm

CC     = gcc
LINKER = gcc

VM_DIR     = ./vm
TEST_DIR   = ./tests
TEST_FILES = $(foreach f, $(wildcard $(TEST_DIR)/*.kon), $f)

CFLAGS = -std=c2x -Og -fstrict-aliasing -g2 -ggdb -pipe -Wall -Wextra -Wno-missing-braces \
         -Wno-unused-function -Wno-unused-parameter -ftabstop=4                            \
         -fstack-protector-strong -fstack-clash-protection -fno-omit-frame-pointer          \
         -fsanitize=address -fsanitize=undefined -fsanitize-address-use-after-scope -DDEBUG
CLFLAGS   = -fno-omit-frame-pointer -fsanitize=address -fsanitize=undefined -fsanitize-address-use-after-scope
CDEPFLAGS = -MT $@ -MMD -MF $(VM_DIR)/build/$*.dep

CSRC := $(wildcard $(VM_DIR)/*.c)
COBJ := $(CSRC:$(VM_DIR)/%.c=$(VM_DIR)/build/%.o)
CDEP := $(CSRC:$(VM_DIR)/%.c=$(VM_DIR)/build/%.dep)

all: vm
	@dune build
	@cp -f ./_build/default/src/main.exe ./$(BIN)

$(VM): $(COBJ)
	@$(LINKER) -o $@ $(CLFLAGS) $(COBJ)
	@echo "Linking complete"

$(COBJ): $(VM_DIR)/build/%.o: $(VM_DIR)/%.c
	@$(CC) $(CDEPFLAGS) $(CFLAGS) -c $< -o $@
	@echo "Compiled " $<

-include $(COBJ:.o=.dep)

.PHONY: vm
vm: $(VM)

.PHONT: test
test: all
	@$(foreach f, $(TEST_FILES), \
		./$(BIN) $f     && \
		gcc $f.c        && \
		./a.out || true && \
		rm ./a.out;)

.PHONY: restore
restore: clean
	@git submodule update --init --remote --merge --recursive -j 8
	@bear -- make vm

.PHONY: clean
clean:
	@dune clean
	@rm -f $(VM_DIR)/build/*
