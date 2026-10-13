import Cocoa
import Darwin
import IOKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var timer: Timer?

    // Toggles
    var showRAM = true
    var showNet = true
    var showCPU = false
    var showGPU = false
    var updateInterval: Double = 1.0

    // Net State
    var lastRx: UInt64 = 0
    var lastTx: UInt64 = 0
    var hasInitNet = false
    var lastNetTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    // CPU State
    var prevCpuLoad = host_cpu_load_info()
    var hasInitCPU = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let button = statusItem.button {
            button.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        }

        loadPreferences()
        setupMenu()
        startTimer()
    }

    func loadPreferences() {
        let def = UserDefaults.standard
        if def.object(forKey: "showRAM") != nil { showRAM = def.bool(forKey: "showRAM") }
        if def.object(forKey: "showNet") != nil { showNet = def.bool(forKey: "showNet") }
        if def.object(forKey: "showCPU") != nil { showCPU = def.bool(forKey: "showCPU") }
        if def.object(forKey: "showGPU") != nil { showGPU = def.bool(forKey: "showGPU") }
        let savedInterval = def.double(forKey: "updateInterval")
        if savedInterval >= 1.0 { updateInterval = savedInterval }
    }

    func startTimer() {
        timer?.invalidate()
        updateStats()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }

    func setupMenu() {
        let menu = NSMenu()

        // Modules Submenu
        let modulesItem = NSMenuItem(title: "Modules", action: nil, keyEquivalent: "")
        let modulesMenu = NSMenu()

        let ramItem = NSMenuItem(title: "RAM", action: #selector(toggleRAM(_:)), keyEquivalent: "")
        ramItem.state = showRAM ? .on : .off
        modulesMenu.addItem(ramItem)

        let netItem = NSMenuItem(title: "Network", action: #selector(toggleNet(_:)), keyEquivalent: "")
        netItem.state = showNet ? .on : .off
        modulesMenu.addItem(netItem)

        let cpuItem = NSMenuItem(title: "CPU", action: #selector(toggleCPU(_:)), keyEquivalent: "")
        cpuItem.state = showCPU ? .on : .off
        modulesMenu.addItem(cpuItem)

        let gpuItem = NSMenuItem(title: "GPU", action: #selector(toggleGPU(_:)), keyEquivalent: "")
        gpuItem.state = showGPU ? .on : .off
        modulesMenu.addItem(gpuItem)

        modulesItem.submenu = modulesMenu
        menu.addItem(modulesItem)

        // Interval Submenu
        let intervalItem = NSMenuItem(title: "Update Interval", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()

        for sec in [1.0, 2.0, 3.0] {
            let item = NSMenuItem(title: "\(Int(sec))s", action: #selector(changeInterval(_:)), keyEquivalent: "")
            item.tag = Int(sec)
            item.state = (updateInterval == sec) ? .on : .off
            intervalMenu.addItem(item)
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Activity Monitor", action: #selector(openActivityMonitor), keyEquivalent: "a"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc func toggleRAM(_ sender: NSMenuItem) {
        showRAM.toggle()
        sender.state = showRAM ? .on : .off
        UserDefaults.standard.set(showRAM, forKey: "showRAM")
        updateStats()
    }

    @objc func toggleNet(_ sender: NSMenuItem) {
        showNet.toggle()
        sender.state = showNet ? .on : .off
        UserDefaults.standard.set(showNet, forKey: "showNet")
        updateStats()
    }

    @objc func toggleCPU(_ sender: NSMenuItem) {
        showCPU.toggle()
        sender.state = showCPU ? .on : .off
        UserDefaults.standard.set(showCPU, forKey: "showCPU")
        updateStats()
    }

    @objc func toggleGPU(_ sender: NSMenuItem) {
        showGPU.toggle()
        sender.state = showGPU ? .on : .off
        UserDefaults.standard.set(showGPU, forKey: "showGPU")
        updateStats()
    }

    @objc func changeInterval(_ sender: NSMenuItem) {
        updateInterval = Double(sender.tag)
        UserDefaults.standard.set(updateInterval, forKey: "updateInterval")
        if let parent = sender.menu {
            for item in parent.items { item.state = .off }
        }
        sender.state = .on
        startTimer()
    }

    @objc func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // --- Metric Gatherers ---

    func getRAMUsedGB() -> Double {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStat = vm_statistics64()
        let result = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        var totalRam: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalRam, &size, nil, 0)

        let free = UInt64(vmStat.free_count)
        let spec = UInt64(vmStat.speculative_count)
        let file = UInt64(vmStat.external_page_count)
        let availBytes = (free + spec + file) * UInt64(pageSize)

        let usedBytes = totalRam > availBytes ? totalRam - availBytes : 0
        return Double(usedBytes) / (1024.0 * 1024.0 * 1024.0)
    }

    func getNetRates() -> (down: Double, up: Double) {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else { return (0, 0) }
        defer { freeifaddrs(ifap) }

        var curRx: UInt64 = 0
        var curTx: UInt64 = 0

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            let name = String(cString: ifa.ifa_name)
            if name.hasPrefix("en") &&
               ifa.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) &&
               (ifa.ifa_flags & UInt32(IFF_UP)) != 0 &&
               (ifa.ifa_flags & UInt32(IFF_RUNNING)) != 0 {
                if let data = ifa.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    curRx += UInt64(networkData.ifi_ibytes)
                    curTx += UInt64(networkData.ifi_obytes)
                }
            }
        }

        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - lastNetTime
        lastNetTime = now

        if !hasInitNet || elapsed <= 0 {
            lastRx = curRx
            lastTx = curTx
            hasInitNet = true
            return (0, 0)
        }

        let diffRx = curRx >= lastRx ? curRx - lastRx : 0
        let diffTx = curTx >= lastTx ? curTx - lastTx : 0
        lastRx = curRx
        lastTx = curTx

        let downMB = (Double(diffRx) / elapsed) / (1024.0 * 1024.0)
        let upMB = (Double(diffTx) / elapsed) / (1024.0 * 1024.0)
        return (downMB, upMB)
    }

    func getCPUUsage() -> Int {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var curInfo = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &curInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        if !hasInitCPU {
            prevCpuLoad = curInfo
            hasInitCPU = true
            return 0
        }

        let user = Double(curInfo.cpu_ticks.0 - prevCpuLoad.cpu_ticks.0)
        let sys = Double(curInfo.cpu_ticks.1 - prevCpuLoad.cpu_ticks.1)
        let idle = Double(curInfo.cpu_ticks.2 - prevCpuLoad.cpu_ticks.2)
        let nice = Double(curInfo.cpu_ticks.3 - prevCpuLoad.cpu_ticks.3)
        prevCpuLoad = curInfo

        let total = user + sys + idle + nice
        guard total > 0 else { return 0 }
        return Int(round(((user + sys + nice) / total) * 100.0))
    }

    func getGPUUsage() -> Int {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else { return 0 }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var foundUtil: Int? = nil
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let perf = dict["PerformanceStatistics"] as? [String: Any] {
                if let util = perf["Device Utilization %"] as? Int {
                    foundUtil = util
                } else if let util = perf["GPU Activity(%)"] as? Int {
                    foundUtil = util
                }
            }
            IOObjectRelease(service)
            if let util = foundUtil {
                return util
            }
            service = IOIteratorNext(iterator)
        }
        return 0
    }

    func updateStats() {
        var parts: [String] = []

        if showCPU {
            parts.append(String(format: "C:%d%%", getCPUUsage()))
        }
        if showGPU {
            parts.append(String(format: "G:%d%%", getGPUUsage()))
        }
        if showRAM {
            parts.append(String(format: "%.1fG", getRAMUsedGB()))
        }
        if showNet {
            let net = getNetRates()
            let downStr = net.down < 0.05 ? "0" : String(format: "%.1fM", net.down)
            let upStr = net.up < 0.05 ? "0" : String(format: "%.1fM", net.up)
            parts.append(String(format: "↓%@ ↑%@", downStr, upStr))
        }

        let title = parts.isEmpty ? "•" : parts.joined(separator: " • ")
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.button?.title = title
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
