BIN = kontos

all:
	@dune build
	@dune exec $(BIN)
