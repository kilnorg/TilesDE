cmake_minimum_required(VERSION 3.21)
project(flowde-shell VERSION 0.1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick Network DBus ShaderTools)
qt_standard_project_setup(REQUIRES 6.5)
find_package(PkgConfig REQUIRED)
pkg_check_modules(VTERM REQUIRED IMPORTED_TARGET vterm)

option(TILES_DEMO_DATA "Seed demo mail/contacts/notes/calendar/music/weather data (dev only; env TILES_DEMO=1 also enables it at runtime)" OFF)
qt_add_executable(flowde-shell src/main.cpp src/Services.cpp src/Services.h src/AppModel.cpp src/AppModel.h src/AppStore.cpp src/AppStore.h)

set(QML_FILES qml/Main.qml qml/Theme.qml qml/GlassPanel.qml qml/Wallpaper.qml qml/StatusBar.qml
  qml/GestureBar.qml qml/LockScreen.qml qml/HomeScreen.qml qml/AppSwitcher.qml qml/Shade.qml
  qml/AppIcon.qml qml/GlassIcon.qml qml/AppPage.qml qml/Toggle.qml qml/SliderRow.qml
  qml/MetroTile.qml qml/TileGlyph.qml qml/TileGallery.qml qml/StartScreen.qml qml/AllApps.qml qml/AlphaJump.qml qml/NavBar.qml qml/PageSlide.qml qml/EdgeBackGesture.qml qml/TilePresets.js
  qml/TileFaces.qml qml/TileGroupHeader.qml qml/LiveTiles.qml
  qml/Pivot.qml qml/PivotPage.qml qml/MetroToggle.qml qml/MetroDropdown.qml qml/TilesKeyboard.qml qml/MetroButton.qml qml/MetroTextField.qml
  qml/MetroListRow.qml qml/MetroSlider.qml qml/MetroColorGrid.qml qml/MetroSectionHeader.qml qml/AppBar.qml qml/ControlsGallery.qml
  qml/SettingsApp.qml qml/SettingsHome.qml
  qml/settings/SettingsStartTheme.qml qml/settings/SettingsLockPage.qml qml/settings/SettingsAppPage.qml
  qml/settings/SettingsTilePreview.qml qml/settings/SettingsGroupManager.qml
  qml/settings2/index.js qml/settings2/SettingsDisplay.qml qml/settings2/SettingsNotifications.qml qml/settings2/SettingsBattery.qml
  qml/settings2/SettingsNetwork.qml qml/settings2/SettingsAbout.qml qml/settings2/SettingsSound.qml qml/settings2/SettingsEmail.qml
  qml/settings2/SettingsDevices.qml
  qml/apps/index.js qml/apps/ClockApp.qml qml/apps/CalculatorApp.qml qml/apps/CalendarApp.qml qml/apps/NotesApp.qml qml/apps/PhoneApp.qml qml/apps/PeopleApp.qml qml/apps/MessagesApp.qml qml/apps/WeatherApp.qml qml/apps/MusicApp.qml qml/apps/MailApp.qml qml/apps/FilesApp.qml qml/apps/BrowserApp.qml qml/apps/CameraApp.qml qml/apps/GamesApp.qml qml/apps/MapsApp.qml qml/apps/NoxalApp.qml qml/apps/PhotosApp.qml qml/apps/PodcastsApp.qml qml/apps/RadioApp.qml qml/apps/RecorderApp.qml qml/apps/RemindersApp.qml qml/apps/StoreApp.qml qml/apps/TerminalApp.qml qml/apps/VideosApp.qml qml/apps/WalletApp.qml)
set_source_files_properties(qml/Theme.qml qml/LiveTiles.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(flowde-shell URI FlowShell VERSION 1.0 SOURCES src/Personalise.cpp src/Personalise.h src/Sys.cpp src/Sys.h src/TermSession.cpp src/TermSession.h src/StoreBackend.cpp src/StoreBackend.h QML_FILES ${QML_FILES} NO_RESOURCE_TARGET_PATH)
qt_add_shaders(flowde-shell "flowde-shaders" PREFIX "/FlowShell" FILES shaders/glass.frag shaders/wallpaper.frag shaders/icon.frag
  OUTPUTS shaders/glass.frag.qsb shaders/wallpaper.frag.qsb shaders/icon.frag.qsb BATCHABLE
  GLSL "100 es,120,150" NOHLSL NOMSL)
file(GLOB ASSET_FILES CONFIGURE_DEPENDS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} assets/icons/*.svg assets/wallpapers/*.png)
qt_add_resources(flowde-shell "assets" PREFIX "/FlowShell" FILES ${ASSET_FILES})
target_include_directories(flowde-shell PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(flowde-shell PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Network Qt6::DBus PkgConfig::VTERM util)
install(TARGETS flowde-shell RUNTIME DESTINATION bin)

if(TILES_DEMO_DATA)
  target_compile_definitions(flowde-shell PRIVATE TILES_DEMO_DATA)
endif()
