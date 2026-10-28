import 'package:fl_clash/common/tray.dart';
import 'package:test/test.dart';

void main() {
  group('AppTray.getTrayIcon', () {
    final windows = AppTray.forPlatform(isMacOS: false, isWindows: true);
    final macOS = AppTray.forPlatform(isMacOS: true, isWindows: false);
    final linux = AppTray.forPlatform(isMacOS: false, isWindows: false);

    test('windows loads ico files from the windows directory', () {
      for (final (isStart, tunEnable, systemProxy, status) in [
        (false, false, false, 1),
        (true, false, false, 1),
        (false, true, true, 1),
        (true, false, true, 2),
        (true, true, false, 3),
      ]) {
        expect(
          windows.getTrayIcon(
            isStart: isStart,
            tunEnable: tunEnable,
            systemProxy: systemProxy,
            safeMode: false,
          ),
          'assets/images/tray/windows/status_$status.ico',
        );
      }
    });

    test('linux loads png files from the unix directory', () {
      for (final (isStart, tunEnable, systemProxy, status) in [
        (false, false, false, 1),
        (true, false, false, 1),
        (true, false, true, 2),
        (true, true, false, 3),
      ]) {
        expect(
          linux.getTrayIcon(
            isStart: isStart,
            tunEnable: tunEnable,
            systemProxy: systemProxy,
            safeMode: false,
          ),
          'assets/images/tray/unix/status_$status.png',
        );
      }
    });

    test('macOS dims the template icon until TUN or system proxy routes', () {
      for (final (isStart, tunEnable, systemProxy, status) in [
        (false, false, false, 0),
        (false, true, true, 0),
        (true, false, false, 0),
        (true, false, true, 1),
        (true, true, false, 1),
      ]) {
        expect(
          macOS.getTrayIcon(
            isStart: isStart,
            tunEnable: tunEnable,
            systemProxy: systemProxy,
            safeMode: false,
          ),
          'assets/images/tray/macos/status_$status.png',
        );
      }
    });

    test('macOS shows the color icons once monochrome is off', () {
      for (final (isStart, tunEnable, systemProxy, safeMode, status) in [
        (false, false, false, false, 1),
        (true, false, false, false, 1),
        (true, false, true, false, 2),
        (true, true, false, false, 3),
        (true, true, false, true, 4),
      ]) {
        expect(
          macOS.getTrayIcon(
            isStart: isStart,
            tunEnable: tunEnable,
            systemProxy: systemProxy,
            safeMode: safeMode,
            monochrome: false,
          ),
          'assets/images/tray/unix/status_$status.png',
        );
      }
    });

    test('safe mode shows its own icon whatever the core is doing', () {
      for (final (isStart, tunEnable) in [
        (false, false),
        (true, false),
        (true, true),
      ]) {
        expect(
          windows.getTrayIcon(
            isStart: isStart,
            tunEnable: tunEnable,
            systemProxy: false,
            safeMode: true,
          ),
          'assets/images/tray/windows/status_4.ico',
        );
        expect(
          linux.getTrayIcon(
            isStart: isStart,
            tunEnable: tunEnable,
            systemProxy: false,
            safeMode: true,
          ),
          'assets/images/tray/unix/status_4.png',
        );
        expect(
          macOS.getTrayIcon(
            isStart: isStart,
            tunEnable: tunEnable,
            systemProxy: false,
            safeMode: true,
          ),
          'assets/images/tray/macos/status_4.png',
        );
      }
    });
  });
}
