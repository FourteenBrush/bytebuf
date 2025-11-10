ifeq ($(OS), Windows_NT)
	PROG = bytebuf.exe
else
	PROG = bytebuf
endif

SRC = .
TESTS = tests
COLLECTIONS = -collection:src=$(SRC)

CC = odin
BUILD_DIR = build
CFLAGS = -out:$(BUILD_DIR)/$(PROG) -strict-style -vet-semicolon -vet-cast -vet-using-param $(COLLECTIONS)

test: CFLAGS += -define:ODIN_TEST_LOG_LEVEL=warning -define:ODIN_TEST_FANCY=false -define:ODIN_TEST_SHORT_LOGS=true -debug -keep-executable
test:
	@mkdir -p $(BUILD_DIR)
	$(CC) test $(TESTS) $(CFLAGS)

check: CFLAGS := $(filter-out -out:$(BUILD_DIR)/$(PROG),$(CFLAGS))
check:
	$(CC) check $(SRC) $(CFLAGS) -debug

clean:
	-@rm -r $(BUILD_DIR)

.PHONY: clean test check
