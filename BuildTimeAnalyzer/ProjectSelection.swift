//
//  ProjectSelection.swift
//  BuildTimeAnalyzer
//

import Cocoa

protocol ProjectSelectionDelegate: AnyObject {
    func didSelectProject(with database: XcodeDatabase)
}

final class ProjectSelection: NSObject {
    @IBOutlet private weak var tableView: NSTableView!
    
    private var dataSource: [XcodeDatabase] = []
    
    weak var delegate: ProjectSelectionDelegate?
    
    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .medium
        return dateFormatter
    }()
    
    func listFolders() {
        dataSource = DerivedDataManager.derivedData().compactMap{
            XcodeDatabase(fromPath: $0.url.appendingPathComponent("Logs/Build/LogStoreManifest.plist").path)
        }.sorted(by: { $0.modificationDate > $1.modificationDate })
        
        tableView.reloadData()
    }
    
    // MARK: Actions
    
    @IBAction private func didSelectCell(_ sender: NSTableView) {
        guard sender.selectedRow != -1 else { return }
        delegate?.didSelectProject(with: dataSource[sender.selectedRow])
    }
}

// MARK: NSTableViewDataSource

extension ProjectSelection: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return dataSource.count
    }
}

// MARK: NSTableViewDelegate

extension ProjectSelection: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn, let columnIndex = tableView.tableColumns.firstIndex(of: tableColumn) else { return nil }
        
        let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Cell\(columnIndex)"), owner: self) as? NSTableCellView
        
        let source = dataSource[row]
        var value = ""
        
        switch columnIndex {
        case 0:
            value = source.schemeName
        default:
            value = ProjectSelection.dateFormatter.string(from: source.modificationDate)
        }
        cellView?.textField?.stringValue = value
        
        return cellView
    }
}
