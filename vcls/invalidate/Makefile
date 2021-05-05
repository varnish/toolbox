TESTS_OS=$(addprefix test_, $(wildcard invalidate_os*.vtc))
TESTS_PLUS=$(addprefix test_, $(wildcard invalidate_plus*.vtc))

all: tests_os tests_plus

tests_os: $(TESTS_OS)
tests_plus: $(TESTS_PLUS)

$(TESTS_OS):
	../../bob/bob varnishtest $(@:test_%=%)

$(TESTS_PLUS):
	BOB_DIST=plus ../../bob/bob varnishtest $(@:test_%=%)

.PHONY: tests_os tests_plus $(TESTS_OS) $(TESTS_PLUS) 
