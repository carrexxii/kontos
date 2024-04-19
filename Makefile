BIN = kontos

TEST_DIR   = ./tests
TEST_FILES = $(foreach f, $(wildcard $(TEST_DIR)/*.kon), $f)

all:
	@dune build
	@cp -f ./_build/default/src/main.exe ./$(BIN)

.PHONT: test
test: all
	@$(foreach f, $(TEST_FILES), \
		./$(BIN) $f     && \
		gcc $f.c        && \
		./a.out || true && \
		rm ./a.out;)
