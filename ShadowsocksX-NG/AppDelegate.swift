//
//  AppDelegate.swift
//  ShadowsocksX-NG
//
//  Created by 邱宇舟 on 16/6/5.
//  Copyright © 2016年 qiuyuzhou. All rights reserved.
//

import Cocoa


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {

    var qrcodeWinCtrl: SWBQRCodeWindowController!
    var preferencesWinCtrl: PreferencesWindowController!
    var advPreferencesWinCtrl: AdvPreferencesWindowController!
    var proxyPreferencesWinCtrl: ProxyPreferencesController!
    var editUserRulesWinCtrl: UserRulesController!

    var launchAtLoginController: LaunchAtLoginController = LaunchAtLoginController()
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    
    @IBOutlet weak var runningStatusMenuItem: NSMenuItem!
    @IBOutlet weak var toggleRunningMenuItem: NSMenuItem!
    @IBOutlet weak var proxyMenuItem: NSMenuItem!
    @IBOutlet weak var autoModeMenuItem: NSMenuItem!
    @IBOutlet weak var globalModeMenuItem: NSMenuItem!
    @IBOutlet weak var manualModeMenuItem: NSMenuItem!
    @IBOutlet weak var whiteListModeMenuItem: NSMenuItem!
    @IBOutlet weak var whiteListDomainMenuItem: NSMenuItem!
    @IBOutlet weak var whiteListIPMenuItem: NSMenuItem!
    
    @IBOutlet weak var serversMenuItem: NSMenuItem!
    @IBOutlet var pingserverMenuItem: NSMenuItem!
    @IBOutlet var showQRCodeMenuItem: NSMenuItem!
    @IBOutlet var scanQRCodeMenuItem: NSMenuItem!
    @IBOutlet var showBunchJsonExampleFileItem: NSMenuItem!
    @IBOutlet var importBunchJsonFileItem: NSMenuItem!
    @IBOutlet var exportAllServerProfileItem: NSMenuItem!
    @IBOutlet var serversPreferencesMenuItem: NSMenuItem!
    
    @IBOutlet weak var lanchAtLoginMenuItem: NSMenuItem!
    @IBOutlet weak var ShowNetworkSpeedItem: NSMenuItem!
    
    var statusItemView:StatusItemView!
    
    var statusItem: NSStatusItem?
    var speedMonitor:NetWorkMonitor?


    func setUpMenu(showSpeed:Bool){
        if statusItem == nil{
            statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(85)
            let image = NSImage(named: "menu_icon")
            image?.template = true
            statusItem!.image = image
            statusItemView = StatusItemView(statusItem: statusItem!, menu: statusMenu)
            statusItem!.view = statusItemView
        }
        if showSpeed{
            if speedMonitor == nil{
                speedMonitor = NetWorkMonitor(statusItemView: statusItemView)
            }
            statusItem?.length = 85
            speedMonitor?.start()
        }else{
            speedMonitor?.stop()
            speedMonitor = nil
            statusItem?.length = 20
        }
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
//        PingServers.instance.ping()
        NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self
        
        // Prepare ss-local
        InstallSSLocal()
        
        // Prepare defaults
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.registerDefaults([
            "ShadowsocksOn": true,
            "ShadowsocksRunningMode": "auto",
            "LocalSocks5.ListenPort": NSNumber(unsignedShort: 1086),
            "LocalSocks5.ListenAddress": "127.0.0.1",
            "PacServer.ListenAddress": "127.0.0.1",
            "PacServer.ListenPort":NSNumber(unsignedShort: 8090),
            "LocalSocks5.Timeout": NSNumber(unsignedInteger: 60),
            "LocalSocks5.EnableUDPRelay": NSNumber(bool: false),
            "LocalSocks5.EnableVerboseMode": NSNumber(bool: false),
            "GFWListURL": "https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt",
            "WhiteListURL": "https://raw.githubusercontent.com/breakwa11/gfw_whitelist/master/whitelist.pac",
            "WhiteListIPURL": "https://raw.githubusercontent.com/breakwa11/gfw_whitelist/master/whiteiplist.pac",
            "AutoConfigureNetworkServices": NSNumber(bool: true)
        ])


        setUpMenu(defaults.boolForKey("enable_showSpeed"))


        let notifyCenter = NSNotificationCenter.defaultCenter()
        notifyCenter.addObserverForName(NOTIFY_ADV_PROXY_CONF_CHANGED, object: nil, queue: nil
            , usingBlock: {
            (note) in
                self.applyConfig()
            }
        )
        notifyCenter.addObserverForName(NOTIFY_SERVER_PROFILES_CHANGED, object: nil, queue: nil
            , usingBlock: {
            (note) in
                let profileMgr = ServerProfileManager.instance
                if profileMgr.activeProfileId == nil &&
                    profileMgr.profiles.count > 0{
                    if profileMgr.profiles[0].isValid(){
                        profileMgr.setActiveProfiledId(profileMgr.profiles[0].uuid)
                    }
                }
                self.updateServersMenu()
                SyncSSLocal()
            }
        )
        notifyCenter.addObserverForName(NOTIFY_ADV_CONF_CHANGED, object: nil, queue: nil
            , usingBlock: {
            (note) in
                SyncSSLocal()
                self.applyConfig()
            }
        )
        notifyCenter.addObserverForName("NOTIFY_FOUND_SS_URL", object: nil, queue: nil) {
            (note: NSNotification) in
            if let userInfo = note.userInfo {
                let urls: [NSURL] = userInfo["urls"] as! [NSURL]
                
                let mgr = ServerProfileManager.instance
                var isChanged = false
                
                for url in urls {
                    let profielDict = ParseSSURL(url)
                    if let profielDict = profielDict {
                        let profile = ServerProfile.fromDictionary(profielDict)
                        mgr.profiles.append(profile)
                        isChanged = true
                        
                        let userNote = NSUserNotification()
                        userNote.title = "Add Shadowsocks Server Profile".localized
                        if userInfo["source"] as! String == "qrcode" {
                            userNote.subtitle = "By scan QR Code".localized
                        } else if userInfo["source"] as! String == "url" {
                            userNote.subtitle = "By Handle SS URL".localized
                        }
                        userNote.informativeText = "Host: \(profile.serverHost)"
                        " Port: \(profile.serverPort)"
                        " Encription Method: \(profile.method)".localized
                        userNote.soundName = NSUserNotificationDefaultSoundName
                        
                        NSUserNotificationCenter.defaultUserNotificationCenter()
                            .deliverNotification(userNote);
                    }else{
                        let userNote = NSUserNotification()
                        userNote.title = "Failed to Add Server Profile".localized
                        userNote.subtitle = "Address can't not be recognized".localized
                        NSUserNotificationCenter.defaultUserNotificationCenter()
                            .deliverNotification(userNote);
                    }
                }
                
                if isChanged {
                    mgr.save()
                    self.updateServersMenu()
                }
            }
        }
        
        // Handle ss url scheme
        NSAppleEventManager.sharedAppleEventManager().setEventHandler(self
            , andSelector: #selector(self.handleURLEvent)
            , forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        
        updateMainMenu()
        updateServersMenu()
        updateRunningModeMenu()
        updateLaunchAtLoginMenu()
        
        ProxyConfHelper.install()
        applyConfig()
        SyncSSLocal()
    }

    
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        StopSSLocal()
        ProxyConfHelper.disableProxy("hi")
        ProxyConfHelper.stopPACServer()


    }
    
    func applyConfig() {
        let profileMgr = ServerProfileManager.instance
        if profileMgr.profiles.count == 0{
            let notice = NSUserNotification()
            notice.title = "还没有服务器设定！"
            notice.subtitle = "去设置里面填一下吧，填完记得选择呦~"
            NSUserNotificationCenter.defaultUserNotificationCenter().deliverNotification(notice)
        }
        let defaults = NSUserDefaults.standardUserDefaults()
        let isOn = defaults.boolForKey("ShadowsocksOn")
        let mode = defaults.stringForKey("ShadowsocksRunningMode")
        
        if isOn {
            StartSSLocal()
            if mode == "auto" {
                ProxyConfHelper.disableProxy("hi")
                ProxyConfHelper.enablePACProxy("hi")
            } else if mode == "global" {
                ProxyConfHelper.disableProxy("hi")
                ProxyConfHelper.enableGlobalProxy()
            } else if mode == "manual" {
                ProxyConfHelper.disableProxy("hi")
                ProxyConfHelper.disableProxy("hi")
            } else if mode == "whiteListDomain" {
                ProxyConfHelper.disableProxy("hi")
                ProxyConfHelper.enableWhiteDomainListProxy()
            } else if mode == "whiteListIP" {
                ProxyConfHelper.disableProxy("hi")
                ProxyConfHelper.enableWhiteIPListProxy()
            }
        } else {
            StopSSLocal()
            ProxyConfHelper.disableProxy("hi")
        }

    }
    
    @IBAction func toggleRunning(sender: NSMenuItem) {
        let defaults = NSUserDefaults.standardUserDefaults()
        var isOn = defaults.boolForKey("ShadowsocksOn")
        isOn = !isOn
        defaults.setBool(isOn, forKey: "ShadowsocksOn")
        
        updateMainMenu()
        
        applyConfig()
    }

    @IBAction func updateGFWList(sender: NSMenuItem) {
        UpdatePACFromGFWList()
    }
    
    @IBAction func updateWhiteList(sender: NSMenuItem) {
        UpdatePACFromWhiteList()
    }
    
    @IBAction func editUserRulesForPAC(sender: NSMenuItem) {
        if editUserRulesWinCtrl != nil {
            editUserRulesWinCtrl.close()
        }
        let ctrl = UserRulesController(windowNibName: "UserRulesController")
        editUserRulesWinCtrl = ctrl

        ctrl.showWindow(self)
        NSApp.activateIgnoringOtherApps(true)
        ctrl.window?.makeKeyAndOrderFront(self)
    }
    
    @IBAction func showQRCodeForCurrentServer(sender: NSMenuItem) {
        var errMsg: String?
        if let profile = ServerProfileManager.instance.getActiveProfile() {
            if profile.isValid() {
                // Show window
                if qrcodeWinCtrl != nil{
                    qrcodeWinCtrl.close()
                }
                qrcodeWinCtrl = SWBQRCodeWindowController(windowNibName: "SWBQRCodeWindowController")
                qrcodeWinCtrl.qrCode = profile.URL()!.absoluteString
                qrcodeWinCtrl.showWindow(self)
                NSApp.activateIgnoringOtherApps(true)
                qrcodeWinCtrl.window?.makeKeyAndOrderFront(nil)
                
                return
            } else {
                errMsg = "Current server profile is not valid.".localized
            }
        } else {
            errMsg = "No current server profile.".localized
        }
        let userNote = NSUserNotification()
        userNote.title = errMsg
        userNote.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.defaultUserNotificationCenter()
            .deliverNotification(userNote);
    }
    
    @IBAction func scanQRCodeFromScreen(sender: NSMenuItem) {
        ScanQRCodeOnScreen()
    }
    
    @IBAction func showBunchJsonExampleFile(sender: NSMenuItem) {
        showExampleConfigFile()
    }
    
    @IBAction func importBunchJsonFile(sender: NSMenuItem) {
        importConfigFile()
        //updateServersMenu()//not working
    }
    
    @IBAction func exportAllServerProfile(sender: NSMenuItem) {
        exportConfigFile()
    }

    @IBAction func toggleLaunghAtLogin(sender: NSMenuItem) {
        launchAtLoginController.launchAtLogin = !launchAtLoginController.launchAtLogin;
        updateLaunchAtLoginMenu()
    }
    
    @IBAction func selectPACMode(sender: NSMenuItem) {
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue("auto", forKey: "ShadowsocksRunningMode")
        updateRunningModeMenu()
        applyConfig()
    }
    
    @IBAction func selectGlobalMode(sender: NSMenuItem) {
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue("global", forKey: "ShadowsocksRunningMode")
        updateRunningModeMenu()
        applyConfig()
    }
    
    @IBAction func selectManualMode(sender: NSMenuItem) {
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue("manual", forKey: "ShadowsocksRunningMode")
        updateRunningModeMenu()
        applyConfig()
    }
    
    @IBAction func selectWhiteDomainListMode(sender: NSMenuItem) {
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue("whiteListDomain", forKey: "ShadowsocksRunningMode")
        updateRunningModeMenu()
        applyConfig()
    }
    
    @IBAction func selectWhiteIPListMode(sender: NSMenuItem) {
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue("whiteListIP", forKey: "ShadowsocksRunningMode")
        updateRunningModeMenu()
        applyConfig()
    }

    @IBAction func editServerPreferences(sender: NSMenuItem) {
        if preferencesWinCtrl != nil {
            preferencesWinCtrl.close()
        }
        let ctrl = PreferencesWindowController(windowNibName: "PreferencesWindowController")
        preferencesWinCtrl = ctrl
        
        ctrl.showWindow(self)
        NSApp.activateIgnoringOtherApps(true)
        ctrl.window?.makeKeyAndOrderFront(self)
    }
    
    @IBAction func editAdvPreferences(sender: NSMenuItem) {
        if advPreferencesWinCtrl != nil {
            advPreferencesWinCtrl.close()
        }
        let ctrl = AdvPreferencesWindowController(windowNibName: "AdvPreferencesWindowController")
        advPreferencesWinCtrl = ctrl
        
        ctrl.showWindow(self)
        NSApp.activateIgnoringOtherApps(true)
        ctrl.window?.makeKeyAndOrderFront(self)
    }
    
    @IBAction func editProxyPreferences(sender: NSObject) {
        if proxyPreferencesWinCtrl != nil {
            proxyPreferencesWinCtrl.close()
        }
        proxyPreferencesWinCtrl = ProxyPreferencesController(windowNibName: "ProxyPreferencesController")
        proxyPreferencesWinCtrl.showWindow(self)
        NSApp.activateIgnoringOtherApps(true)
        proxyPreferencesWinCtrl.window?.makeKeyAndOrderFront(self)
    }
    
    @IBAction func selectServer(sender: NSMenuItem) {
        let index = sender.tag
        let spMgr = ServerProfileManager.instance
        let newProfile = spMgr.profiles[index]
        if newProfile.uuid != spMgr.activeProfileId {
            spMgr.setActiveProfiledId(newProfile.uuid)
            updateServersMenu()
            SyncSSLocal()
        }
        updateRunningModeMenu()
    }

    @IBAction func doPingTest(sender: AnyObject) {
        PingServers.instance.ping()
    }
    
    @IBAction func showSpeedTap(sender: NSMenuItem) {
        let defaults = NSUserDefaults.standardUserDefaults()
        var enable = defaults.boolForKey("enable_showSpeed")
        enable = !enable
        setUpMenu(enable)
        defaults.setBool(enable, forKey: "enable_showSpeed")
        updateMainMenu()
    }

    @IBAction func showLogs(sender: NSMenuItem) {
        let ws = NSWorkspace.sharedWorkspace()
        if let appUrl = ws.URLForApplicationWithBundleIdentifier("com.apple.Console") {
            try! ws.launchApplicationAtURL(appUrl
                ,options: .Default
                ,configuration: [NSWorkspaceLaunchConfigurationArguments: "~/Library/Logs/ss-local.log"])
        }
    }
    
    @IBAction func feedback(sender: NSMenuItem) {
        NSWorkspace.sharedWorkspace().openURL(NSURL(string: "https://github.com/qinyuhang/ShadowsocksX-NG/issues")!)
    }
    
    @IBAction func showAbout(sender: NSMenuItem) {
        NSApp.orderFrontStandardAboutPanel(sender);
        NSApp.activateIgnoringOtherApps(true)
    }
    
    func updateLaunchAtLoginMenu() {
        if launchAtLoginController.launchAtLogin {
            lanchAtLoginMenuItem.state = 1
        } else {
            lanchAtLoginMenuItem.state = 0
        }
    }
    
    func updateRunningModeMenu() {
        let defaults = NSUserDefaults.standardUserDefaults()
        let mode = defaults.stringForKey("ShadowsocksRunningMode")
        var serverMenuText = "Servers".localized
        for i in defaults.arrayForKey("ServerProfiles")! {
            if i["Id"] as! String == defaults.stringForKey("ActiveServerProfileId")! {
                if i["Remark"] as! String != "" {
                    serverMenuText = i["Remark"] as! String
                } else {
                    serverMenuText = i["ServerHost"] as! String
                }
            }
        }
        serversMenuItem.title = serverMenuText
        if mode == "auto" {
            proxyMenuItem.title = "Proxy - Auto By PAC".localized
            autoModeMenuItem.state = 1
            globalModeMenuItem.state = 0
            manualModeMenuItem.state = 0
            whiteListModeMenuItem.state = 0
            whiteListDomainMenuItem.state = 0
            whiteListIPMenuItem.state = 0
        } else if mode == "global" {
            proxyMenuItem.title = "Proxy - Global".localized
            autoModeMenuItem.state = 0
            globalModeMenuItem.state = 1
            manualModeMenuItem.state = 0
            whiteListModeMenuItem.state = 0
            whiteListDomainMenuItem.state = 0
            whiteListIPMenuItem.state = 0
        } else if mode == "manual" {
            proxyMenuItem.title = "Proxy - Manual".localized
            autoModeMenuItem.state = 0
            globalModeMenuItem.state = 0
            manualModeMenuItem.state = 1
            whiteListModeMenuItem.state = 0
            whiteListDomainMenuItem.state = 0
            whiteListIPMenuItem.state = 0
        } else if mode == "whiteListDomain" {
            proxyMenuItem.title = "Proxy - White List Domain".localized
            autoModeMenuItem.state = 0
            globalModeMenuItem.state = 0
            manualModeMenuItem.state = 0
            whiteListModeMenuItem.state = 1
            whiteListDomainMenuItem.state = 1
            whiteListIPMenuItem.state = 0
        } else if mode == "whiteListIP" {
            proxyMenuItem.title = "Proxy - White List IP".localized
            autoModeMenuItem.state = 0
            globalModeMenuItem.state = 0
            manualModeMenuItem.state = 0
            whiteListModeMenuItem.state = 1
            whiteListDomainMenuItem.state = 0
            whiteListIPMenuItem.state = 1
        }
    }
    
    func updateMainMenu() {
        let defaults = NSUserDefaults.standardUserDefaults()
        let isOn = defaults.boolForKey("ShadowsocksOn")
        if isOn {
            runningStatusMenuItem.title = "ShadowsocksR: On".localized
            toggleRunningMenuItem.title = "Turn Shadowsocks Off".localized
            let image = NSImage(named: "menu_icon")
            statusItemView.setIcon(image!)
//            statusItem.image = image
        } else {
            runningStatusMenuItem.title = "ShadowsocksR: Off".localized
            toggleRunningMenuItem.title = "Turn Shadowsocks On".localized
            let image = NSImage(named: "menu_icon_disabled")
//            statusItem.image = image
            statusItemView.setIcon(image!)
        }
        let showSpeed = defaults.boolForKey("enable_showSpeed")
        if showSpeed{
            ShowNetworkSpeedItem.state = 1
        }else{
            ShowNetworkSpeedItem.state = 0
        }
    }
    
    func updateServersMenu() {
        let mgr = ServerProfileManager.instance
        serversMenuItem.submenu?.removeAllItems()
        let showQRItem = showQRCodeMenuItem
        let scanQRItem = scanQRCodeMenuItem
        let preferencesItem = serversPreferencesMenuItem
        let showBunch = showBunchJsonExampleFileItem
        let importBuntch = importBunchJsonFileItem
        let exportAllServer = exportAllServerProfileItem
        let pingItem = pingserverMenuItem

        var i = 0
        for p in mgr.profiles {
            let item = NSMenuItem()
            item.tag = i
            if p.remark.isEmpty {
                item.title = "\(p.serverHost):\(p.serverPort)"
            } else {
                item.title = "\(p.remark) (\(p.serverHost):\(p.serverPort))"
            }

            if let latency = p.latency{
                item.title += "  -\(latency)ms"
            }

            if mgr.activeProfileId == p.uuid {
                item.state = 1
            }
            if !p.isValid() {
                item.enabled = false
            }
            item.action = #selector(AppDelegate.selectServer)
            
            serversMenuItem.submenu?.addItem(item)
            i += 1
        }
        if !mgr.profiles.isEmpty {
            serversMenuItem.submenu?.addItem(NSMenuItem.separatorItem())
        }
        serversMenuItem.submenu?.addItem(showQRItem)
        serversMenuItem.submenu?.addItem(scanQRItem)
        serversMenuItem.submenu?.addItem(showBunch)
        serversMenuItem.submenu?.addItem(importBuntch)
        serversMenuItem.submenu?.addItem(exportAllServer)
        serversMenuItem.submenu?.addItem(NSMenuItem.separatorItem())
        serversMenuItem.submenu?.addItem(preferencesItem)
        serversMenuItem.submenu?.addItem(pingItem)

    }
    
    func handleURLEvent(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptorForKeyword(AEKeyword(keyDirectObject))?.stringValue {
            if let url = NSURL(string: urlString) {
                NSNotificationCenter.defaultCenter().postNotificationName(
                    "NOTIFY_FOUND_SS_URL", object: nil
                    , userInfo: [
                        "ruls": [url],
                        "source": "url",
                    ])
            }
        }
    }
    
    //------------------------------------------------------------
    // NSUserNotificationCenterDelegate
    
    func userNotificationCenter(center: NSUserNotificationCenter
        , shouldPresentNotification notification: NSUserNotification) -> Bool {
        return true
    }
}

