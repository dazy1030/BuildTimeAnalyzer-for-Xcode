//
//  LogProcessor.swift
//  BuildTimeAnalyzer
//

import Foundation

typealias CMUpdateClosure = @MainActor (_ result: [CompileMeasure], _ didComplete: Bool, _ didCancel: Bool) -> ()

fileprivate let regex = try! NSRegularExpression(pattern:  "^\\d*\\.?\\d*ms\\t/", options: [])

final fileprivate actor RawMeasures {
    private var map: [String: RawMeasure] = [:]
    
    var values: Dictionary<String, RawMeasure>.Values {
        map.values
    }
    
    func value(forKey key: String) -> RawMeasure? {
        map[key]
    }
    
    func set(_ value: RawMeasure, forKey key: String) {
        map[key] = value
    }
    
    func removeAll() {
        map.removeAll()
    }
}

final class LogProcessor: NSObject {
    private var rawMeasures: RawMeasures = .init()
    private var updateHandler: CMUpdateClosure?
    @MainActor private var timer: Timer?
    
    var shouldCancel = false
    
    @MainActor
    func processDatabase(database: XcodeDatabase, updateHandler: CMUpdateClosure?) {
        guard let text = database.processLog() else {
            updateHandler?([], true, false)
            return
        }
        
        self.updateHandler = updateHandler
        Task.detached(priority: .background) {
            await self.process(text: text)
        }
    }
    
    // MARK: Private methods
    
    @MainActor
    private func processingDidStart() {
        self.timer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(self.timerCallback(_:)), userInfo: nil, repeats: true)
    }
    
    @MainActor
    private func processingDidFinish() {
        self.timer?.invalidate()
        self.timer = nil
        let didCancel = self.shouldCancel
        self.shouldCancel = false
        self.updateResults(didComplete: true, didCancel: didCancel)
    }
    
    @objc private func timerCallback(_ timer: Timer) {
        updateResults(didComplete: false, didCancel: false)
    }
    
    private func process(text: String) async {
        let characterSet = CharacterSet(charactersIn:"\r")
        var remainingRange = text.startIndex..<text.endIndex
        
        await rawMeasures.removeAll()
        
        await processingDidStart()
        
        while !shouldCancel, let characterRange = text.rangeOfCharacter(from: characterSet,
                                                                              options: .literal,
                                                                              range: remainingRange) {
            let nextRange = remainingRange.lowerBound..<characterRange.upperBound
            
            defer {
                remainingRange = nextRange.upperBound..<remainingRange.upperBound
            }
            
            let range = NSRange(nextRange, in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: range) else { continue }
            let matchRange = Range<String.Index>.init(match.range, in: text)!
            let timeString = text[remainingRange.lowerBound..<text.index(matchRange.upperBound, offsetBy: -4)]
            if let time = Double(timeString) {
                let text = String(text[text.index(before: matchRange.upperBound)..<nextRange.upperBound])
                if let rawMeasure = await rawMeasures.value(forKey: text) {
                    rawMeasure.time += time
                    rawMeasure.references += 1
                } else {
                    await rawMeasures.set(RawMeasure(time: time, text: text), forKey: text)
                }
            }
        }
        await processingDidFinish()
    }
    
    private func updateResults(didComplete completed: Bool, didCancel: Bool) {
        Task.detached(priority: .high) {
            let measures = await self.rawMeasures.values
            var filteredResults = measures.filter{ $0.time > 10 }
            if filteredResults.count < 20 {
                filteredResults = measures.filter{ $0.time > 0.1 }
            }
            
            let sortedResults = filteredResults.sorted(by: { $0.time > $1.time })
            let result = self.processResult(sortedResults)
            
            if completed {
                await self.rawMeasures.removeAll()
            }
            
            
            await self.updateHandler?(result, completed, didCancel)
        }
    }

    private func processResult(_ unprocessedResult: [RawMeasure]) -> [CompileMeasure] {
        let characterSet = CharacterSet(charactersIn:"\r\"")
        
        var result: [CompileMeasure] = []
        for entry in unprocessedResult {
            let code = entry.text.split(separator: "\t").map(String.init)
            let method = code.count >= 2 ? trimPrefixes(code[1]) : "-"
            
            if let path = code.first?.trimmingCharacters(in: characterSet), let measure = CompileMeasure(time: entry.time, rawPath: path, code: method, references: entry.references) {
                result.append(measure)
            }
        }
        return result
    }
    
    private func trimPrefixes(_ code: String) -> String {
        var code = code
        ["@objc ", "final ", "@IBAction "].forEach { (prefix) in
            if code.hasPrefix(prefix) {
                code = String(code[code.index(code.startIndex, offsetBy: prefix.count)...])
            }
        }
        return code
    }
}
