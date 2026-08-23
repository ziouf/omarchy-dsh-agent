import QtQuick
import Quickshell
import Quickshell.Io

// Owns the DeepSeek Harness instance for the whole desktop:
//
// 1. Runs `dsh web` as a long-lived background process, brought back by a
//    watchdog whenever it exits, so the web UI is always reachable without
//    anyone starting it by hand. --no-open keeps the server from spawning a
//    browser of its own; the desktop opens it as an app window on demand.
//    The URL the instance reports is written to a state file that the web-app
//    launcher reads, so a non-default port still opens the right address.
// 2. Regenerates the dsh usage record on a cadence so the Agents panel keeps
//    its DSH tab fresh (omarchy-agent-usage-update only knows packaged
//    collectors, so this service owns the dsh record).
// 3. Re-runs scripts/install-webapp at startup; it exits immediately when the
//    desktop entry is healthy, repairs it otherwise (plugin rename/reinstall).
Item {
  id: root

  property var shell: null

  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/ziouf.dsh"
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/dsh"
  readonly property int refreshIntervalSec: 900
  readonly property int watchdogIntervalSec: 10

  property string webUrl: ""

  // Only loopback addresses are accepted: the web UI is local, and anything
  // else printed on stdout would send the desktop browser somewhere this
  // plugin never intended.
  function isLocalWebUrl(u) {
    var m = String(u).match(/^https?:\/\/(\[[0-9a-fA-F:]+\]|[^\/:?#\s]+)(:\d+)?(?:[\/?#].*)?$/)
    if (!m)
      return false
    var host = m[1]
    if (host === "localhost" || host === "[::1]")
      return true
    return /^127\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.test(host)
  }

  function writeWebUrl(url) {
    if (!url || url === root.webUrl || !isLocalWebUrl(url))
      return
    root.webUrl = url
    urlFile.path = root.stateDir + "/web-url"
    urlFile.setText(url + "\n")
  }

  // The bash wrapper execs the server only when dsh exists; otherwise it
  // exits at once and the watchdog simply retries — no separate probe.
  Process {
    id: webServer

    command: ["bash", "-c", "command -v dsh >/dev/null && exec dsh web --no-open"]

    stdout: SplitParser {
      onRead: data => {
        var match = String(data).match(/https?:\/\/[^\s"]+/)
        if (match)
          root.writeWebUrl(match[0])
      }
    }

    onExited: console.log("ziouf.dsh: dsh web exited, watchdog will restart it")
  }

  Timer {
    interval: root.watchdogIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!webServer.running)
      webServer.running = true
  }

  FileView {
    id: urlFile

    printErrors: false
    atomicWrites: true
  }

  // Ensures the state directory exists before the first URL write.
  Process {
    id: mkdirProcess

    command: ["mkdir", "-p", root.stateDir]
  }

  Process {
    id: initWebapp

    command: [root.pluginDir + "/scripts/install-webapp"]
  }

  Process {
    id: collectProcess

    command: [root.pluginDir + "/scripts/collect-usage"]
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!collectProcess.running)
      collectProcess.running = true
  }

  Component.onCompleted: {
    mkdirProcess.running = true
    initWebapp.running = true
  }
}
