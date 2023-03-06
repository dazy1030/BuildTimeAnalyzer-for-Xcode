//
//  DirectoryMonitor.swift
//  BuildTimeAnalyzer
//

import Foundation

protocol DirectoryMonitorDelegate: AnyObject {
    func directoryMonitorDidObserveChange(_ directoryMonitor: DirectoryMonitor, isDerivedData: Bool)
}

final class DirectoryMonitor {
    private var dispatchQueue: DispatchQueue
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var isDerivedData: Bool
    private var lastDerivedDataDate = Date()
    private var isMonitoringDates = false
    
    var path: String?
    weak var delegate: DirectoryMonitorDelegate?
    
    init(isDerivedData: Bool) {
        self.isDerivedData = isDerivedData
        
        let suffix = isDerivedData ? "deriveddata" : "logfolder"
        dispatchQueue = DispatchQueue(label: "uk.co.canemedia.directorymonitor.\(suffix)", attributes: .concurrent)
    }
    
    func startMonitoring(path: String) {
        self.path = path
        
        guard dispatchSource == nil && fileDescriptor == -1 else { return }
        
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }
        
        dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .all, queue: dispatchQueue)
        dispatchSource?.setEventHandler {
            DispatchQueue.main.async {
                self.delegate?.directoryMonitorDidObserveChange(self, isDerivedData: self.isDerivedData)
            }
        }
        dispatchSource?.setCancelHandler {
            close(self.fileDescriptor)
            
            self.fileDescriptor = -1
            self.dispatchSource = nil
            self.path = nil
        }
        dispatchSource?.resume()
        
        if isDerivedData && !isMonitoringDates {
            isMonitoringDates = true
            monitorModificationDates()
        }
    }
    
    func stopMonitoring() {
        dispatchSource?.cancel()
        path = nil
    }
    
    private func monitorModificationDates() {
        if let date = DerivedDataManager.derivedData().first?.date, date > lastDerivedDataDate {
            lastDerivedDataDate = date
            self.delegate?.directoryMonitorDidObserveChange(self, isDerivedData: self.isDerivedData)
        }
        
        if path != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.monitorModificationDates()
            }
        } else {
            isMonitoringDates = false
        }
    }
}
