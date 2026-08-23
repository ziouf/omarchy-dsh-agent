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
    if (!url || url === root.webUrl)
      return
    if (!isLocalWebUrl(url)) {
      console.log("ziouf.dsh: ignoring non-local URL reported by dsh: " + url)
      return
    }
    root.webUrl = url
    urlFile.path = root.stateDir + "/web-url"
    urlFile.setText(url + "\n")
  }

  Process {
    id: webServer

    stdout: SplitParser {
      onRead: data => {
        var match = String(data).match(/https?:\/\/[^\s"]+/)
        if (match)
          root.writeWebUrl(match[0])
      }
    }

    onExited: console.log("ziouf.dsh: dsh web exited, watchdog will restart it")
  }

  // Starts the server when it is not running and dsh is installed. Runs every
  // few seconds; cheap because Process.running makes it a no-op otherwise.
  Timer {
    interval: root.watchdogIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (webServer.running)
        return
      checkDsh.command = ["bash", "-lc", "command -v dsh >/dev/null && echo yes || echo no"]
      checkDsh.running = true
    }
  }

  Process {
    id: checkDsh

    stdout: StdioCollector {
      id: dshProbe

      onStreamFinished: {
        if (dshProbe.text.trim() === "yes" && !webServer.running) {
          webServer.command = ["dsh", "web", "--no-open"]
          webServer.running = true
        }
      }
    }
  }

  FileView {
    id: urlFile

    printErrors: false
    atomicWrites: true
  }

  // Ensures ~/.local/state/omarchy/dsh exists before the first URL write.
  Process {
    id: mkdirProcess

    command: ["mkdir", "-p", root.stateDir]
  }

  Process {
    id: collectProcess

    command: [root.pluginDir + "/scripts/collect-usage"]
  }

  // The web-app .desktop carries an absolute Exec path into this plugin
  // folder, so renaming or reinstalling the plugin under a different id would
  // silently strand it. On startup: if the entry is missing or its Exec no
  // longer resolves to an executable file, regenerate it.
  Process {
    id: healWebapp

    command: [root.pluginDir + "/scripts/install-webapp"]
  }

  Process {
    id: checkWebapp

    command: ["bash", "-lc",
      "f=\"$HOME/.local/share/applications/DeepSeek Harness.desktop\"; " +
      "x=$(sed -n 's/^Exec=//p' \"$f\"); " +
      "[[ -n $x && -x $x ]] && echo ok || echo broken"]

    stdout: StdioCollector {
      id: webappProbe

      onStreamFinished: {
        if (webappProbe.text.trim() !== "ok") {
          console.log("ziouf.dsh: repairing DeepSeek Harness desktop entry")
          healWebapp.running = true
        }
      }
    }
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
    checkWebapp.running = true
  }
}
