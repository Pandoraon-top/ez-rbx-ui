# Variables
INPUT_FILE := ./main.lua
OUTPUT_FILE := ./output/bundle.lua
EXAMPLE_INPUT_FILE := ./example/main.lua
EXAMPLE_OUTPUT_FILE := ./output/example.lua
RELEASE_DIR := ./release
EXAMPLE_RELEASE := $(RELEASE_DIR)/example.lua
STRESS_RELEASE := $(RELEASE_DIR)/stress.lua
# dist/ is the ONE build output that is committed: a public raw URL is how a viewer loadstrings the
# showcase without waiting for a release. Everything else stays in the ignored output/ and release/.
DIST_DIR := ./dist
SHOWCASE_INPUT := ./example/showcase.lua
SHOWCASE_DIST := $(DIST_DIR)/showcase.lua
SHOWCASE_RELEASE := $(RELEASE_DIR)/showcase.lua


.PHONY: build
build:
	@echo "Building Lua bundle..."
	@mkdir -p $(dir $(OUTPUT_FILE))
	@lua-bundler -e $(INPUT_FILE) -o $(OUTPUT_FILE);

.PHONY: run
run: build
	@echo "Running example..."
	@lua-bundler -e $(EXAMPLE_INPUT_FILE) -o $(EXAMPLE_OUTPUT_FILE) -s -p 8081;

.PHONY: test
test:
	@echo "Running headless tests..."
	@for f in tests/*_test.lua; do echo "-- $$f"; lua $$f || exit 1; done

.PHONY: icons
icons:
	@echo "Generating curated icon table..."
	@node scripts/build-icons.mjs

.PHONY: verify-bundle
verify-bundle: build
	@echo "Verifying bundle under Roblox-faithful require..."
	@lua scripts/verify_bundle.lua

.PHONY: check
check: build test verify-bundle skill-test check-skill examples
	@echo "Check OK."

.PHONY: skill-test
skill-test:
	@echo "Running skill drift-check unit tests..."
	@node --test scripts/check-skill.test.mjs

.PHONY: check-skill
check-skill:
	@echo "Checking the EzUI skill is in sync with the library API..."
	@node scripts/check-skill.mjs

.PHONY: stress
stress: build
	@echo "Serving stress scene on :8081..."
	@lua-bundler -e ./example/stress.lua -o ./output/stress.lua -s -p 8081;

.PHONY: examples
examples: build
	@echo "Building readable example + stress bundles..."
	@mkdir -p $(RELEASE_DIR)
	@lua-bundler -e $(EXAMPLE_INPUT_FILE) -o $(EXAMPLE_RELEASE)
	@lua-bundler -e ./example/stress.lua -o $(STRESS_RELEASE)
	@lua-bundler -e $(SHOWCASE_INPUT) -o $(SHOWCASE_RELEASE)
	@lua -e "assert(loadfile('$(EXAMPLE_RELEASE)')); assert(loadfile('$(STRESS_RELEASE)')); assert(loadfile('$(SHOWCASE_RELEASE)')); print('example bundles ok')"

.PHONY: showcase
showcase: build
	@echo "Bundling the visual showcase to dist/ (committed so raw.githubusercontent can serve it)..."
	@mkdir -p $(DIST_DIR)
	@lua-bundler -e $(SHOWCASE_INPUT) -o $(SHOWCASE_DIST)
	@lua -e "assert(loadfile('$(SHOWCASE_DIST)')); print('showcase bundle ok')"
	@echo "Raw URL: https://raw.githubusercontent.com/Pandoraon-top/ez-rbx-ui/feat/visual-polish/$(SHOWCASE_DIST)"

.PHONY: docs
docs:
	@echo "Serving docs (VitePress dev)..."
	@npm run docs:dev

.PHONY: docs-build
docs-build:
	@echo "Building docs site..."
	@npm run docs:build
