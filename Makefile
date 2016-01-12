#! /usr/bin/env make


all:	build

build:
	@echo "  - Building nodejs-header-echo ... "
	(cd nodejs-header-echo &&  \
	   git submodule update --init --recursive && make)


demo:	build
	@echo ""
	@echo "  - Running demo script ... "
	# ( ./bin/run-demo.sh )
	( ./demo )


clean:
	@echo "  - Cleaning up test environment ... "
	( ./demo --cleanup)


debug:	build
	@echo ""
	@echo "  - Running demo script in debug ... "
	( ./bin/run-demo.sh -x )


test:	build
	@echo "  - Running demo script ... "
	( ./bin/run-demo.sh --generate > /tmp/test-script.sh )
	@echo "  - Test script /tmp/test-script.sh generated. "


verify:	build
	@echo "  - Running demo script ... "
	( ./bin/run-demo.sh --dry-run )
