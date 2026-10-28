import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:tray/tray.dart';

import 'app_localizations.dart';
import 'l10n_labels.dart';
import 'app_ports.dart';
import 'constant.dart';
import 'keyboard.dart';
import 'provider_reader.dart';
import 'system.dart';
import 'window.dart';

class AppTray implements TrayPort {
  static AppTray? _instance;

  final bool isMacOS;
  final bool isWindows;

  bool _isShutDown = false;

  AppTray._internal({required this.isMacOS, required this.isWindows});

  factory AppTray() {
    _instance ??= AppTray._internal(
      isMacOS: system.isMacOS,
      isWindows: system.isWindows,
    );
    return _instance!;
  }

  @visibleForTesting
  factory AppTray.forPlatform({
    required bool isMacOS,
    required bool isWindows,
  }) {
    return AppTray._internal(isMacOS: isMacOS, isWindows: isWindows);
  }

  String get _trayIconSuffix {
    return isWindows ? 'ico' : 'png';
  }

  bool _isTemplate(bool monochrome) => isMacOS && monochrome;

  String _trayIconDir(bool monochrome) {
    if (isWindows) {
      return 'assets/images/tray/windows';
    }
    return _isTemplate(monochrome)
        ? 'assets/images/tray/macos'
        : 'assets/images/tray/unix';
  }

  /// Only a running core that routes traffic through TUN or the system proxy
  /// gets the solid icon; the macOS template dims to its translucent variant.
  String getTrayIcon({
    required bool isStart,
    required bool tunEnable,
    required bool systemProxy,
    required bool safeMode,
    bool monochrome = true,
  }) {
    final isProxying = isStart && (tunEnable || systemProxy);
    final status = switch ((
      safeMode,
      _isTemplate(monochrome),
      isProxying,
      tunEnable,
    )) {
      (true, _, _, _) => 4,
      (false, true, false, _) => 0,
      (false, true, true, _) => 1,
      (false, false, false, _) => 1,
      (false, false, true, false) => 2,
      (false, false, true, true) => 3,
    };
    return '${_trayIconDir(monochrome)}/status_$status.$_trayIconSuffix';
  }

  @override
  Future<void> shutdown() async {
    _isShutDown = true;
    // Removing a status item makes macOS forget where the user dragged it in
    // the menu bar; one that goes away with the process keeps its place.
    if (isMacOS) {
      return;
    }
    await Tray.instance.hide();
  }

  @override
  Future<void> update({
    required TrayState trayState,
    required Traffic traffic,
    required ProviderReader read,
  }) async {
    if (_isShutDown) {
      return;
    }
    await Tray.instance.show(
      TraySpec(
        icon: TrayIcon.asset(
          getTrayIcon(
            isStart: trayState.isStart && !trayState.suspended,
            tunEnable: trayState.tunEnable,
            systemProxy: trayState.systemProxy,
            safeMode: trayState.safeMode,
            monochrome: trayState.monochromeTrayIcon,
          ),
          isTemplate: _isTemplate(trayState.monochromeTrayIcon),
          size: isMacOS ? 18 : 16,
        ),
        toolTip: trayState.safeMode
            ? currentAppLocalizations.safeModeAppTitle(appName)
            : appName,
        menu: _buildMenu(trayState: trayState, read: read),
      ),
    );
    await updateTitle(showTrayTitle: trayState.showTrayTitle, traffic: traffic);
  }

  Future<void> updateTitle({
    required bool showTrayTitle,
    required Traffic traffic,
  }) async {
    if (_isShutDown || !isMacOS) {
      return;
    }
    await Tray.instance.setTitle(showTrayTitle ? traffic.trayTitle : '');
  }

  List<TrayMenuItem> _buildMenu({
    required TrayState trayState,
    required ProviderReader read,
  }) {
    final commonAction = read(commonActionProvider.notifier);
    final systemAction = read(systemActionProvider.notifier);
    final setupAction = read(setupActionProvider.notifier);
    final appLocalizations = currentAppLocalizations;
    String? shortcut(HotAction action) => _shortcut(trayState, action);

    return [
      TrayMenuSubmenu(
        label: '${appLocalizations.proxyMode} (${trayState.mode.label})',
        items: [
          for (final mode in Mode.values)
            TrayMenuCheckbox(
              label: mode.label,
              checked: mode == trayState.mode,
              detail: shortcut(switch (mode) {
                Mode.rule => HotAction.ruleMode,
                Mode.global => HotAction.globalMode,
                Mode.direct => HotAction.directMode,
              }),
              onSelected: () {
                setupAction.changeMode(mode);
              },
            ),
        ],
      ),
      const TrayMenuSeparator(),
      if (isMacOS) ..._buildGroupMenu(trayState: trayState, read: read),
      TrayMenuCheckbox(
        label: appLocalizations.setAsSystemProxy,
        checked: trayState.systemProxy,
        detail: shortcut(HotAction.proxy),
        onSelected: systemAction.updateSystemProxy,
      ),
      TrayMenuCheckbox(
        label: appLocalizations.tun,
        checked: trayState.tunEnable,
        detail: shortcut(HotAction.tun),
        onSelected: systemAction.updateTun,
      ),
      TrayMenuAction(
        label: appLocalizations.copyEnvVar,
        detail: shortcut(HotAction.copyEnv),
        onSelected: systemAction.copyProxyEnv,
      ),
      const TrayMenuSeparator(),
      TrayMenuAction(
        label: appLocalizations.dashboard,
        detail: shortcut(HotAction.view),
        onSelected: () {
          window?.show();
        },
      ),
      if (isMacOS)
        TrayMenuCheckbox(
          label: appLocalizations.showSpeedStatistics,
          checked: trayState.showTrayTitle,
          onSelected: commonAction.updateSpeedStatistics,
        ),
      const TrayMenuSeparator(),
      TrayMenuAction(
        label: appLocalizations.exit,
        detail: shortcut(HotAction.exit),
        onSelected: () {
          systemAction.handleExit();
        },
      ),
    ];
  }

  String? _shortcut(TrayState trayState, HotAction action) {
    final hotKey = trayState.hotKeys[action];
    final key = hotKey?.key;
    if (hotKey == null || key == null) {
      return null;
    }
    return ShortcutLabels(
      isMacOS: isMacOS,
      isWindows: isWindows,
    ).text(hotKey.modifiers, key);
  }

  List<TrayMenuItem> _buildGroupMenu({
    required TrayState trayState,
    required ProviderReader read,
  }) {
    if (trayState.groups.isEmpty) {
      return const [];
    }
    final proxiesAction = read(proxiesActionProvider.notifier);
    return [
      for (final group in trayState.groups)
        _buildGroupSubmenu(
          group,
          selectedName: read(selectedProxyNameProvider(group.name)),
          onSelected: (proxyName) {
            proxiesAction.changeProxy(
              groupName: group.name,
              proxyName: proxyName,
            );
          },
        ),
      const TrayMenuSeparator(),
    ];
  }

  TrayMenuSubmenu _buildGroupSubmenu(
    Group group, {
    required String? selectedName,
    required void Function(String proxyName) onSelected,
  }) {
    return TrayMenuSubmenu(
      label: selectedName == null
          ? group.name
          : '${group.name} ($selectedName)',
      items: [
        for (final proxy in group.all)
          TrayMenuCheckbox(
            label: proxy.name,
            checked: selectedName == proxy.name,
            onSelected: () {
              onSelected(proxy.name);
            },
          ),
      ],
    );
  }
}

final appTray = system.isDesktop ? AppTray() : null;
