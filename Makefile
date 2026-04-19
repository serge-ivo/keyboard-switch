APP_NAME = KeyboardMonitor
APP_BUNDLE = $(APP_NAME).app
INSTALL_DIR = /Applications

build:
	swiftc -o $(APP_NAME) $(APP_NAME).swift -framework Cocoa

app: build
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp $(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Info.plist $(APP_BUNDLE)/Contents/

install: app
	cp -r $(APP_BUNDLE) $(INSTALL_DIR)/
	open $(INSTALL_DIR)/$(APP_BUNDLE)
	@echo "Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo "To start at login: System Settings → General → Login Items → add KeyboardMonitor"

uninstall:
	pkill $(APP_NAME) 2>/dev/null || true
	rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)

clean:
	rm -rf $(APP_NAME) $(APP_BUNDLE)

.PHONY: build app install uninstall clean
