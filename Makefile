SWIFT ?= swift
CONFIG ?= release

.PHONY: all build run probe clean ddc universal package release-notes site site-preview promo-video

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

site:
	./Scripts/build_site.sh

site-preview: site
	@echo "Serving http://localhost:8000"
	cd dist/site && python3 -m http.server 8000

promo-video:
	mkdir -p .build
	swiftc -O Scripts/make_promo_video.swift -o .build/make_promo_video
	.build/make_promo_video website/assets/great-display.mp4 --poster website/assets/great-display-poster.jpg 9.0

clean:
	rm -rf .build dist
