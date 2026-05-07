APP_NAME = KeyboardMonitor
APP_BUNDLE = $(APP_NAME).app
INSTALL_DIR = /Applications
PLIST_NAME = com.serge.keyboardmonitor.plist
LAUNCH_AGENTS_DIR = $(HOME)/Library/LaunchAgents
BUILD_DIR = .build/release

build:
	swift build -c release --product $(APP_NAME)

test:
	swift test

app: build
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Info.plist $(APP_BUNDLE)/Contents/

install: app
	rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	cp -R $(APP_BUNDLE) $(INSTALL_DIR)/
	mkdir -p $(LAUNCH_AGENTS_DIR)
	cp $(PLIST_NAME) $(LAUNCH_AGENTS_DIR)/
	launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME) 2>/dev/null || true
	launchctl load $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	@echo "Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo "LaunchAgent installed — app will start automatically on login"

uninstall:
	launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME) 2>/dev/null || true
	rm -f $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	pkill $(APP_NAME) 2>/dev/null || true
	rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)

clean:
	rm -rf .build $(APP_NAME) $(APP_BUNDLE)

.PHONY: build test app install uninstall clean
