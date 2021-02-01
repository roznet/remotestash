//
//  AppDelegate.swift
//  remotestash
//
//  Created by Brice Rosenzweig on 01/02/2021.
//  Copyright © 2021 Brice Rosenzweig. All rights reserved.
//

import Foundation
import UIKit

@main
class AppDelegate : UIResponder,UIApplicationDelegate {
    static let kNotificationApplicationEnteredForeground = Notification.Name( "kNotificationApplicationEnteredForeground" )
    static let kNotificationApplicationEnteredBackground = Notification.Name( "kNotificationApplicationEnteredBackground" )
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationCenter.default.post(name: AppDelegate.kNotificationApplicationEnteredForeground, object: nil)
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        NotificationCenter.default.post(name: AppDelegate.kNotificationApplicationEnteredForeground, object: nil)
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        
    }
}
