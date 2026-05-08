APP_NAME = KeyboardMonitor
APP_BUNDLE = $(APP_NAME).app
APP_INFO_PLIST = Info.plist
INSTALL_DIR = /Applications
PLIST_NAME = com.serge.keyboardmonitor.plist
PROMPT_APP_NAME = PromptWhisper
PROMPT_APP_BUNDLE = $(PROMPT_APP_NAME).app
PROMPT_INFO_PLIST = PromptWhisper-Info.plist
PROMPT_PLIST_NAME = com.serge.promptwhisper.plist
LAUNCH_AGENTS_DIR = $(HOME)/Library/LaunchAgents
BUILD_DIR = .build/release

build:
	swift build -c release --product $(APP_NAME)

prompt-build:
	swift build -c release --product $(PROMPT_APP_NAME)

test:
	swift test

app: build
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp $(APP_INFO_PLIST) $(APP_BUNDLE)/Contents/

prompt-app: prompt-build
	mkdir -p $(PROMPT_APP_BUNDLE)/Contents/MacOS
	cp $(BUILD_DIR)/$(PROMPT_APP_NAME) $(PROMPT_APP_BUNDLE)/Contents/MacOS/
	cp $(PROMPT_INFO_PLIST) $(PROMPT_APP_BUNDLE)/Contents/Info.plist

install: app
	pkill $(APP_NAME) 2>/dev/null || true
	rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	cp -R $(APP_BUNDLE) $(INSTALL_DIR)/
	mkdir -p $(LAUNCH_AGENTS_DIR)
	cp $(PLIST_NAME) $(LAUNCH_AGENTS_DIR)/
	launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME) 2>/dev/null || true
	launchctl load $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	@echo "Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo "LaunchAgent installed — app will start automatically on login"

prompt-install: prompt-app
	pkill $(PROMPT_APP_NAME) 2>/dev/null || true
	rm -rf $(INSTALL_DIR)/$(PROMPT_APP_BUNDLE)
	cp -R $(PROMPT_APP_BUNDLE) $(INSTALL_DIR)/
	mkdir -p $(LAUNCH_AGENTS_DIR)
	cp $(PROMPT_PLIST_NAME) $(LAUNCH_AGENTS_DIR)/
	launchctl unload $(LAUNCH_AGENTS_DIR)/$(PROMPT_PLIST_NAME) 2>/dev/null || true
	launchctl load $(LAUNCH_AGENTS_DIR)/$(PROMPT_PLIST_NAME)
	@echo "Installed to $(INSTALL_DIR)/$(PROMPT_APP_BUNDLE)"
	@echo "LaunchAgent installed — app will start automatically on login"

uninstall:
	launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME) 2>/dev/null || true
	rm -f $(LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	pkill $(APP_NAME) 2>/dev/null || true
	rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)

prompt-uninstall:
	launchctl unload $(LAUNCH_AGENTS_DIR)/$(PROMPT_PLIST_NAME) 2>/dev/null || true
	rm -f $(LAUNCH_AGENTS_DIR)/$(PROMPT_PLIST_NAME)
	pkill $(PROMPT_APP_NAME) 2>/dev/null || true
	rm -rf $(INSTALL_DIR)/$(PROMPT_APP_BUNDLE)

clean:
	rm -rf .build $(APP_NAME) $(APP_BUNDLE) $(PROMPT_APP_BUNDLE)

.PHONY: build prompt-build test app prompt-app install prompt-install uninstall prompt-uninstall clean
