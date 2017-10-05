//
//  ViewController.swift
//  PushNotificationWebViewDemo
//
//  Created by brad zasada on 9/29/17.
//  Copyright © 2017 Highland Solutions. All rights reserved.
//

import UIKit
import WebKit
import WKBridge
import UserNotifications
import NotificationCenter

let messageReceivedNotificationKey = "com.bzasada.hybridPushDemo.messageReceived"

class ViewController: UIViewController, WKUIDelegate {
    var webView: WKWebView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //setup view configuration and inject script to allow our bridge
        let wkConfiguration = WKWebViewConfiguration()
        let wkContentController = WKUserContentController()
        let injectJSFile: String = Bundle.main.path(forResource: "wk.bridge.min", ofType: "js")!
        do {
            let js: String =  try String(contentsOfFile: injectJSFile)
            let wkUserScript = WKUserScript(source: js, injectionTime: WKUserScriptInjectionTime.atDocumentEnd, forMainFrameOnly: false)
            
            wkContentController.addUserScript(wkUserScript)
        } catch {
            print(error)
        }
        wkConfiguration.userContentController = wkContentController
        
        //setup web view
        webView = WKWebView(frame: .zero, configuration: wkConfiguration)
        webView?.uiDelegate = self
        let indexFileURLString: String = Bundle.main.path(forResource: "index", ofType: "html")!
        let indexFileURL = URL(fileURLWithPath: indexFileURLString)
        webView?.loadFileURL(indexFileURL, allowingReadAccessTo: indexFileURL)
        
        //setup javascript handlers
        webView?.bridge.register( { (parameters, completion) in
            self.registerForPushNotifications()
        }, for: "enablePush")

        webView?.bridge.register( { (parameters, completion) in
            let APNCertPath: String = Bundle.main.path(forResource: "myNewPushCertificate", ofType: "p12")!
            do {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                let APNCertPathURL = URL(fileURLWithPath: APNCertPath)
                let APNCertContents: Data = try Data(contentsOf: APNCertPathURL)
                let myPusher: NWPusher = try NWPusher.connect(withPKCS12Data: APNCertContents, password: "push", environment: NWEnvironment.sandbox)
                let myMessage: String = parameters?["message"] as! String
                let success = try myPusher.pushPayload("{\"aps\":{\"alert\":\""+myMessage+"\"}}", token: appDelegate.APNKey, identifier: UInt(arc4random()))
            } catch {
                print(error)
            }
        }, for: "sendNotification")
        
        view = webView
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.receivedMessage), name: Notification.Name(rawValue: messageReceivedNotificationKey), object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            (granted, error) in
            print("Notifications enabled: \(granted)")
            
            if !granted { return }
            
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                print("Notification settings: \(settings)")
                if settings.authorizationStatus != .authorized { return }
                
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    @objc func receivedMessage(_ notification: Notification) {
        webView?.bridge.post(action: "message", parameters: ["message": notification.userInfo?["alert"]])
    }

}

