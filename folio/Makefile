SCHEME      = Folio
PROJECT     = Folio.xcodeproj
SIM_NAME    = iPhone 16 Pro
SIM_DEVICE  = com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro
SIM_RUNTIME = com.apple.CoreSimulator.SimRuntime.iOS-26-5
BUILD_DIR   = build
BUNDLE_ID   = com.mhxue.folio

.PHONY: all generate build run test test-unit test-package open clean reset-sim sim-info help

all: build

## generate   — Regenerate Xcode project from project.yml
generate:
	xcodegen generate

## build       — Build debug app for simulator
build: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=$(SIM_NAME)' \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		build 2>&1 | grep -E "error:|BUILD (FAILED|SUCCEEDED)"

## run         — Build, install, and launch on simulator
run: _boot_sim build _install_and_launch

## test         — Run all tests: EPUBKit (swift test) + FolioTests (xctestplan)
test: test-package test-unit

## test-package — Run EPUBKit tests via swift test (no simulator needed)
test-package:
	swift test --package-path Packages/EPUBKit

## test-unit    — Run FolioTests on simulator using Folio.xctestplan
test-unit: generate _boot_sim
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=$(SIM_NAME)' \
		-testPlan Folio \
		-derivedDataPath $(BUILD_DIR) \
		test 2>&1 | grep -E "Test Case|error:|Test Suite .* (passed|failed)|BUILD (FAILED|SUCCEEDED)"

## open        — Open project in Xcode
open:
	open $(PROJECT)

## clean       — Remove build artifacts
clean:
	rm -rf $(BUILD_DIR)

## reset-sim   — Erase all simulator content (fresh install)
reset-sim: _sim_id
	xcrun simctl shutdown "$$(cat /tmp/.folio_sim_id)" 2>/dev/null || true
	xcrun simctl erase "$$(cat /tmp/.folio_sim_id)"
	@echo "Simulator erased."

## sim-info    — Print which simulator is being used
sim-info: _sim_id
	@echo "Name:  $(SIM_NAME)"
	@echo "UDID:  $$(cat /tmp/.folio_sim_id)"
	@xcrun simctl list devices | grep "$$(cat /tmp/.folio_sim_id)"

## help        — Show this help
help:
	@grep -E '^## ' Makefile | column -t -s '—'

# ── Internal targets ────────────────────────────────────────────────────────

_sim_id:
	@UDID=$$(xcrun simctl list devices | awk -F'[()]' '/$(SIM_NAME)/{print $$2; exit}'); \
	if [ -z "$$UDID" ]; then \
		echo "Creating simulator '$(SIM_NAME)'..."; \
		UDID=$$(xcrun simctl create "$(SIM_NAME)" $(SIM_DEVICE) $(SIM_RUNTIME)); \
		echo "Created: $$UDID"; \
	fi; \
	echo "$$UDID" > /tmp/.folio_sim_id

_boot_sim: _sim_id
	@UDID=$$(cat /tmp/.folio_sim_id); \
	STATE=$$(xcrun simctl list devices | grep "$$UDID" | grep -o "Booted\|Shutdown" | head -1); \
	if [ "$$STATE" != "Booted" ]; then \
		echo "Booting simulator $$UDID..."; \
		xcrun simctl boot "$$UDID"; \
		open -a Simulator; \
		echo "Waiting for boot..."; \
		xcrun simctl bootstatus "$$UDID" -b; \
	else \
		echo "Simulator already booted."; \
		open -a Simulator; \
	fi

_install_and_launch: _sim_id
	@UDID=$$(cat /tmp/.folio_sim_id); \
	APP=$$(find $(BUILD_DIR) -name "$(SCHEME).app" -type d | head -1); \
	echo "Installing $$APP on $$UDID"; \
	xcrun simctl install "$$UDID" "$$APP"; \
	echo "Launching $(BUNDLE_ID)..."; \
	xcrun simctl launch "$$UDID" $(BUNDLE_ID)
