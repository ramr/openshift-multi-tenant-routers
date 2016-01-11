#! /usr/bin/env make


all:	build

build:
	@echo "  - Building nodejs-header-echo ... "
	(cd nodejs-header-echo &&  \
	   git submodule update --init --recursive && make)

run:	
	@echo "  - Running demo script ... "
	( ./run-demo.sh )

clean:
	@echo "  - Cleaning up test environment ... "
	( ./run-demo.sh --cleanup)

test:	
	@echo "  - Running demo script ... "
	( ./run-demo.sh --generate > /tmp/test-script.sh )
	@echo "  - Test script /tmp/test-script.sh generated. "

verify:	
	@echo "  - Running demo script ... "
	( ./run-demo.sh --dry-run )
