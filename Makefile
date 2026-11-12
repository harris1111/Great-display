SWIFT ?= swift
CONFIG ?= release

.PHONY: all build run probe clean ddc universal package release-notes

all: build

build:
	./Scripts/build_app.sh $(CONFIG)

run: build
	open dist/GreatDisplay.app

probe: build
	./dist/GreatDisplay.app/Contents/MacOS/GreatDisplay --probe

ddc: build
	@echo "usage: make ddc ID=<displayID>"
	./dist/GreatDisplay.app/Contents/MacOS/GreatDisplay --ddc-read $(ID)

universal:
	ARCHS="arm64 x86_64" ./Scripts/build_app.sh $(CONFIG)

package: universal
	./Scripts/package_release.sh

release-notes:
	@./Scripts/release_notes.sh $(VERSION)

clean:
	rm -rf .build dist
