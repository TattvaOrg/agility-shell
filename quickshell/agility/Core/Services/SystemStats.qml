import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
pragma Singleton

Item {
    id: root

    property string osName: "Linux"
    property string hostModel: ""
    property string kernel: "Loading..."
    property string hostname: "Loading..."
    property string username: "Loading..."
    property string shell: "Loading..."
    property string wm: "Hyprland (Wayland)"
    property string packages: "Loading..."
    property string display: "Loading..."
    property string cpuModel: "Loading..."
    property string cpuCores: "Loading..."
    property string memTotal: "0 GB"
    property string diskTotal: "0 GB"
    property string gpuName: "None"
    property bool hasGpu: false

    Component.onCompleted: {
        if (!staticInfoProc.running)
            staticInfoProc.running = true;

    }

    Process {
        id: staticInfoProc

        command: ["python3", Quickshell.shellDir + "/Scripts/system/get_system_info.py"]
        running: true
        onExited: (exitCode) => {
            if (exitCode === 0) {
                try {
                    let info = JSON.parse(staticStdout.text.trim());
                    root.osName = info.os || "Linux";
                    root.hostModel = info.host || "";
                    root.kernel = info.kernel || "";
                    root.hostname = info.hostname || "";
                    root.username = info.username || "";
                    root.shell = info.shell || "";
                    root.wm = info.wm || "Hyprland (Wayland)";
                    root.packages = info.packages || "";
                    root.display = info.display || "";
                    root.cpuModel = info.cpu_model || "";
                    root.cpuCores = info.cpu_cores || "";
                    root.memTotal = info.ram_total || "0 GB";
                    root.diskTotal = info.disk_total || "0 GB";
                    root.gpuName = info.gpus || "None";
                    root.hasGpu = root.gpuName !== "" && root.gpuName !== "None" && root.gpuName !== "Integrated Graphics";
                } catch (e) {
                    console.error("Error parsing get_system_info.py JSON: " + e);
                }
            }
        }

        stdout: StdioCollector {
            id: staticStdout
        }

    }

}
