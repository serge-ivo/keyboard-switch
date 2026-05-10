APP_NAME = KeyboardMonitor
APP_BUNDLE = $(APP_NAME).app
APP_INFO_PLIST = Info.plist
INSTALL_DIR = /Applications
PLIST_NAME = com.serge.keyboardmonitor.plist
SYSTEM_LAUNCH_AGENTS_DIR = /Library/LaunchAgents
PROMPT_APP_NAME = PromptWhisper
PROMPT_APP_BUNDLE = $(PROMPT_APP_NAME).app
PROMPT_INFO_PLIST = PromptWhisper-Info.plist
PROMPT_PLIST_NAME = com.serge.promptwhisper.plist
LAUNCH_AGENTS_DIR = $(HOME)/Library/LaunchAgents
BUILD_DIR = .build/release
DIST_DIR = dist
PKG_ROOT = $(DIST_DIR)/pkgroot
PKG_IDENTIFIER = com.serge.keyboardmonitor.pkg
PKG_SCRIPTS_DIR = scripts/installer
APP_VERSION ?= $(shell node -p "require('./package.json').version")
PKG_UNSIGNED = $(DIST_DIR)/$(APP_NAME)-$(APP_VERSION)-unsigned.pkg
PKG_FILE = $(DIST_DIR)/$(APP_NAME)-$(APP_VERSION).pkg
APP_SIGN_IDENTITY ?=
PKG_SIGN_IDENTITY ?=
NOTARY_PROFILE ?=

build:
	swift build -c release --product $(APP_NAME)

prompt-build:
	swift build -c release --product $(PROMPT_APP_NAME)

test:
	swift test

app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp $(APP_INFO_PLIST) $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(APP_VERSION)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(APP_VERSION)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundlePackageType APPL" $(APP_BUNDLE)/Contents/Info.plist
	xattr -cr $(APP_BUNDLE)
	@if [ -n "$(APP_SIGN_IDENTITY)" ]; then \
		echo "Signing $(APP_BUNDLE) with $(APP_SIGN_IDENTITY)"; \
		codesign --force --deep --options runtime --timestamp --sign "$(APP_SIGN_IDENTITY)" $(APP_BUNDLE); \
	fi

pkg: app
	rm -rf $(PKG_ROOT)
	rm -f $(PKG_UNSIGNED) $(PKG_FILE)
	mkdir -p $(DIST_DIR) $(PKG_ROOT)/Applications $(PKG_ROOT)$(SYSTEM_LAUNCH_AGENTS_DIR)
	ditto --norsrc --noextattr --noqtn --noacl $(APP_BUNDLE) $(PKG_ROOT)/Applications/$(APP_BUNDLE)
	ditto --norsrc --noextattr --noqtn --noacl $(PLIST_NAME) $(PKG_ROOT)$(SYSTEM_LAUNCH_AGENTS_DIR)/$(PLIST_NAME)
	xattr -cr $(PKG_ROOT)
	find $(PKG_ROOT) -name '._*' -delete
	COPYFILE_DISABLE=1 pkgbuild \
		--root $(PKG_ROOT) \
		--identifier $(PKG_IDENTIFIER) \
		--version $(APP_VERSION) \
		--install-location / \
		--filter '(^|/)\._' \
		--scripts $(PKG_SCRIPTS_DIR) \
		$(PKG_UNSIGNED)
	@if [ -n "$(PKG_SIGN_IDENTITY)" ]; then \
		echo "Signing installer with $(PKG_SIGN_IDENTITY)"; \
		productsign --sign "$(PKG_SIGN_IDENTITY)" $(PKG_UNSIGNED) $(PKG_FILE); \
		rm -f $(PKG_UNSIGNED); \
	else \
		mv $(PKG_UNSIGNED) $(PKG_FILE); \
	fi
	@echo "Built installer at $(PKG_FILE)"

notarize-pkg: pkg
	@if [ -z "$(APP_SIGN_IDENTITY)" ] || [ -z "$(PKG_SIGN_IDENTITY)" ]; then \
		echo "APP_SIGN_IDENTITY and PKG_SIGN_IDENTITY are required for notarization"; \
		exit 1; \
	fi
	@if [ -z "$(NOTARY_PROFILE)" ]; then \
		echo "NOTARY_PROFILE is required for notarization"; \
		exit 1; \
	fi
	xcrun notarytool submit $(PKG_FILE) --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple $(PKG_FILE)
	xcrun stapler validate $(PKG_FILE)

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

signing-status:
	security find-identity -v -p codesigning || true

clean:
	rm -rf .build $(APP_NAME) $(APP_BUNDLE) $(PROMPT_APP_BUNDLE) $(DIST_DIR)

.PHONY: build prompt-build test app prompt-app pkg notarize-pkg install prompt-install uninstall prompt-uninstall signing-status clean
