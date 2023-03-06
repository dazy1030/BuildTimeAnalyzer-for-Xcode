//
//  AppDelegate.swift
//  BuildTimeAnalyzer
//

import Cocoa

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet private weak var projectSelectionMenuItem: NSMenuItem!
    @IBOutlet private weak var buildTimesMenuItem: NSMenuItem!
    @IBOutlet private weak var alwaysInFrontMenuItem: NSMenuItem!
    
    private var viewController: ViewController? {
        return NSApplication.shared.mainWindow?.contentViewController as? ViewController
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        alwaysInFrontMenuItem.state = UserSettings.windowShouldBeTopMost ? .on : .off
    }
    
    func configureMenuItems(showBuildTimesMenuItem: Bool) {
        projectSelectionMenuItem.isEnabled = !showBuildTimesMenuItem
        buildTimesMenuItem.isEnabled = showBuildTimesMenuItem
    }
    
    // MARK: Actions
    
    @IBAction private func navigateToProjectSelection(_ sender: NSMenuItem) {
        configureMenuItems(showBuildTimesMenuItem: true)
        
        viewController?.cancelProcessing()
        viewController?.showInstructions(true)
    }
    
    @IBAction private func navigateToBuildTimes(_ sender: NSMenuItem) {
        configureMenuItems(showBuildTimesMenuItem: false)
        viewController?.showInstructions(false)
    }
    
    @IBAction private func visitGitHubPage(_ sender: AnyObject) {
        let path = "https://github.com/RobertGummesson/BuildTimeAnalyzer-for-Xcode"
        if let url = URL(string: path) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @IBAction private func toggleAlwaysInFront(_ sender: NSMenuItem) {
        let alwaysInFront = sender.state == .off
        
        sender.state = alwaysInFront ? .on : .off
        UserSettings.windowShouldBeTopMost = alwaysInFront
        
        viewController?.makeWindowTopMost(topMost: alwaysInFront)
    }
}

