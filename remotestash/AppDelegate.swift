//
//  AppDelegate.swift
//  remotestash
//
//  Created by Brice Rosenzweig on 01/02/2021.
//  Copyright © 2021 Brice Rosenzweig. All rights reserved.
//

import Foundation
import UIKit

extension Notification.Name {
    static let remoteStashApplicationEnteredForeground = Notification.Name( "kNotificationApplicationEnteredForeground" )
    static let remoteStashApplicationEnteredBackground = Notification.Name( "kNotificationApplicationEnteredBackground" )
}

@main
class AppDelegate : UIResponder,UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationCenter.default.post(name: Notification.Name.remoteStashApplicationEnteredForeground, object: nil)
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        NotificationCenter.default.post(name: Notification.Name.remoteStashApplicationEnteredForeground, object: nil)
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        
    }
}
