# Native TilesDE apps (apps/*.qml)

Registered in apps/index.js, hosted by AppPage.qml (Loader). One file per app: `<Name>App.qml`.

Contract
- Root `Item` (anchors.fill'd by the host). Declare `property real topInset: 36` and `signal closeRequested`.
  Host sets topInset (status bar height); keep content below it. Bottom 56px (nav bar) and the on-screen keyboard are already excluded by the host.
- Style: Windows Phone 8.1 / Metro on AMOLED. Use ONLY existing components + Theme: Pivot/PivotPage (big lowercase header,
  `caption: "clock"`), MetroListRow, MetroTextField, MetroButton, MetroToggle, MetroSlider, MetroDropdown, MetroSectionHeader, AppBar
  (bottom 72px bar of round glyph buttons + "..." menu), TileGlyph (glyph names in TileGlyph.qml), Theme.accent/text/textDim/pageBg/dark/font/fontLight/
  pageMargin/tileGap/onColor(c)/reduceMotion. Flat, no shadows, no gradients, no rounded rectangles except round AppBar buttons, light font weights,
  lowercase titles, respect Theme.reduceMotion for animations. Colours always via Theme so presets and light/dark/amoled work.
- Text input: use MetroTextField / TextInput / TextEdit; the shell's TilesKeyboard appears automatically for any focused text item. Never use Qt.inputMethod.
- Persistence: `AppStore.load("<key>", fallback)` / `AppStore.save("<key>", obj_or_array)` (JSON under ~/.config/tilesde/apps). Save on every change. Load on Component.onCompleted.
  Seed demo data only when the store is empty and label seeds honestly (e.g. contacts "Ada Lovelace"); no network access.
- Import style: `import QtQuick` + `import FlowShell` (files in qml/ are in the FlowShell module; apps/ files are loaded by path, so reference shared
  components by bare name as other files do e.g. `MetroListRow {}`). Use `import "../TilePresets.js" as ...` only if needed.
- Pure QML (no C++ changes). Qt 6.8. QtQuick only; Qt.labs.folderlistmodel allowed. No QtMultimedia unless noted.
- Scrolling lists: ListView/Flickable with clip, boundsBehavior: Flickable.StopAtBounds. Touch targets >= 48px.
- Quality: must load with zero QML warnings. Handle empty states, long text elide, delete/undo-free confirmations kept simple. Polish > breadth.
- DO NOT edit any file outside your assigned apps/*.qml files. Do not build or run the VM. Validate with `qmllint` only if installed
  (`which qmllint qmllint6`), otherwise re-read your code carefully for binding/typo errors. Do not commit.
Reference files to read first: Pivot.qml, PivotPage.qml, MetroListRow.qml, AppBar.qml, MetroTextField.qml, MetroButton.qml, SettingsApp.qml,
settings2/SettingsSound.qml (a typical app page), TileGlyph.qml (glyph list).

Back: define `function back()`; the shell back gesture calls it. It closes any inner view/sheet first, else emits `closeRequested`.

System bridge (context properties, see src/Sys.h)
- `Sys.launch(prog, [args])` detached launch -> bool; `Sys.openUrl(url)` xdg-open; `Sys.home()`; `Sys.exists(path)`;
  `Sys.readText(path, maxBytes)`; `Sys.listDir(path, [exts], recursive, limit)` -> [{path,name,size,modified}];
  `Sys.run(prog, [args], timeoutMs)` -> {code,out,err} (blocking, short commands only e.g. `which x`).
- `TermSession {}` (module FlowShell, src/TermSession.*): real terminal (forkpty + libvterm, TERM=xterm-256color). Props `shell` ("" = $SHELL or bash -l),
  `cols`, `rows`, `running`, `title`, `cursorRow/Col/Visible`, `altScreen`, `scrollbackCount`, `appCursorKeys` (unused), `darkPalette`, `defaultFg/Bg`.
  Methods `start()`, `resize(c, r)`, `write(text)` (paste/raw), `sendKey(qtKey, qtModifiers)`, `stop()`, `lineHtml(row)`, `scrollbackLineHtml(i)` (0 = oldest),
  `screenText()`. Signals `rowsDamaged(first, last)` (16 ms batched), `screenReset()`, `titleChanged`, `bell()`, `finished(code)`.
  Test hook: env FLOWDE_TERM_TEST="cmd; cmd" is typed into the first session.
- No QtMultimedia / QtWebEngine / QtPositioning on the target. For media, camera or web content use external programs through
  Sys.launch after checking availability with `Sys.run("which", [prog])`; show an honest "not installed" state when missing.
  Installed on the VM: foot, firefox-esr, xdg-open. Never fake working hardware: demo content must be labelled.
