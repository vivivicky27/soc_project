PYTHON ?= python3
.DEFAULT_GOAL := demo
.PHONY: demo test check

demo:
	$(PYTHON) demo.py

test:
	$(PYTHON) -m unittest discover -s tests -v

check: test demo
