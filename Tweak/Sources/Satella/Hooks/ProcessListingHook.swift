import Foundation
import Jinx

/// ProcessListingHook prevents jailbreak detection by hiding suspicious processes
/// Modern iOS 16-18 apps often check for processes like Cydia, Sileo, etc.
@available(iOS 16.0, *)
struct ProcessListingHook: Hook {
    // Hook NSProcessInfo's hostName method to hide suspicious host names
    let cls: AnyClass? = NSProcessInfo.self
    let sel: Selector = #selector(getter: NSProcessInfo.hostName)
    
    typealias T = @convention(c) (NSProcessInfo, Selector) -> String
    let replace: T = { obj, sel in
        // Return a sanitized hostname that doesn't leak jailbreak information
        return "iPhone"
    }
    
    /// Additional hooks for process listing functions
    func hook() {
        // Hook the standard base implementation first
        Jinx.hook(self)
        
        // Also hook process_info to hide jailbreak processes from task_for_pid calls
        hookProcessInfo()
        
        // Hook sysctl process listing
        hookSysctl()
        
        // Hook BSD process listing functions
        hookBSDProcessListing()
    }
    
    /// Hooks process_info to hide jailbreak-related processes
    private func hookProcessInfo() {
        guard let processInfoPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "proc_listallpids") else {
            return
        }
        
        typealias ProcListAllPIDsFunc = @convention(c) (UnsafeMutablePointer<UInt32>?, Int32) -> Int32
        
        let replacementProcListAllPIDs: ProcListAllPIDsFunc = { buffer, bufferSize in
            // Call original function
            let count = unsafeBitCast(processInfoPtr, to: ProcListAllPIDsFunc.self)(buffer, bufferSize)
            
            // If we got a valid buffer with PIDs, filter out jailbreak-related processes
            if let buffer = buffer, count > 0 {
                // Suspicious process names to filter
                let suspiciousProcesses = ["Cydia", "Sileo", "Zebra", "Filza", "MTerminal", "NewTerm", "sshd", "bash", "sh"]
                
                // Get information about each process and filter out suspicious ones
                var validCount = 0
                
                for i in 0..<count {
                    let pid = buffer[Int(i)]
                    
                    // Get the process name
                    var name = [CChar](repeating: 0, count: 256)
                    var info = proc_bsdinfo()
                    
                    if proc_name(pid, &name, 256) == 0,
                       proc_pidinfo(pid, Int32(PROC_PIDTBSDINFO), 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size)) > 0 {
                        let processName = String(cString: name)
                        
                        // If it's not a suspicious process, keep it
                        if !suspiciousProcesses.contains(where: { processName.contains($0) }) {
                            buffer[validCount] = pid
                            validCount += 1
                        }
                    } else {
                        // If we can't get info, keep the PID (safer)
                        buffer[validCount] = pid
                        validCount += 1
                    }
                }
                
                return Int32(validCount)
            }
            
            return count
        }
        
        let replacement = unsafeBitCast(replacementProcListAllPIDs, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(processInfoPtr, with: replacement)
    }
    
    /// Hooks sysctl to hide jailbreak evidence
    private func hookSysctl() {
        guard let sysctlPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "sysctl") else {
            return
        }
        
        typealias SysctlFunc = @convention(c) (UnsafeMutablePointer<Int32>?, u_int, UnsafeMutableRawPointer?, UnsafeMutablePointer<size_t>?, UnsafeMutableRawPointer?, size_t) -> Int32
        
        let replacementSysctl: SysctlFunc = { name, namelen, oldp, oldlenp, newp, newlen in
            // Check if this is a process-related sysctl call (CTL_KERN, KERN_PROC)
            if name != nil && namelen >= 2 && name![0] == CTL_KERN {
                if name![1] == KERN_PROC {
                    // This is a process listing call, which could be used for jailbreak detection
                    // Let's sanitize the results before returning
                    
                    // Call original function
                    let result = unsafeBitCast(sysctlPtr, to: SysctlFunc.self)(name, namelen, oldp, oldlenp, newp, newlen)
                    
                    // If we succeeded in getting process info, sanitize it
                    if result == 0 && oldp != nil && oldlenp != nil {
                        // Process the buffer to remove suspicious processes
                        sanitizeKernProcBuffer(oldp!, oldlenp!)
                    }
                    
                    return result
                }
            }
            
            // For all other sysctl calls, pass through normally
            return unsafeBitCast(sysctlPtr, to: SysctlFunc.self)(name, namelen, oldp, oldlenp, newp, newlen)
        }
        
        let replacement = unsafeBitCast(replacementSysctl, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(sysctlPtr, with: replacement)
    }
    
    /// Helper function to sanitize KERN_PROC buffer
    private func sanitizeKernProcBuffer(_ buffer: UnsafeMutableRawPointer, _ bufferSize: UnsafeMutablePointer<size_t>) {
        // This is a complex operation that would require deeper system knowledge
        // In a production implementation, we would parse the specific kinfo_proc structures
        // and filter out any processes with suspicious names
        
        // For now, we'll leave this as a placeholder
    }
    
    /// Hooks BSD process listing functions
    private func hookBSDProcessListing() {
        // Hook proc_name to sanitize process names
        guard let procNamePtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "proc_name") else {
            return
        }
        
        typealias ProcNameFunc = @convention(c) (Int32, UnsafeMutablePointer<CChar>?, UInt32) -> Int32
        
        let replacementProcName: ProcNameFunc = { pid, buffer, bufferSize in
            // Call original function
            let result = unsafeBitCast(procNamePtr, to: ProcNameFunc.self)(pid, buffer, bufferSize)
            
            // If we successfully got a name and have a buffer to sanitize
            if result == 0 && buffer != nil {
                let processName = String(cString: buffer!)
                
                // Check if this is a suspicious process name
                let suspiciousProcesses = ["Cydia", "Sileo", "Zebra", "Filza", "MTerminal", "NewTerm", "sshd", "bash", "sh"]
                
                if suspiciousProcesses.contains(where: { processName.contains($0) }) {
                    // Replace with a harmless name
                    let safeName = "system"
                    if bufferSize > safeName.count {
                        safeName.withCString { safeBuffer in
                            strncpy(buffer, safeBuffer, Int(bufferSize))
                        }
                    }
                }
            }
            
            return result
        }
        
        let replacement = unsafeBitCast(replacementProcName, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(procNamePtr, with: replacement)
    }
}
