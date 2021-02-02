//
//  SceneDelegate.swift
//  remotestash
//
//  Created by Brice Rosenzweig on 01/02/2021.
//  Copyright © 2021 Brice Rosenzweig. All rights reserved.
//

import Foundation
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        NotificationCenter.default.post(name: Notification.Name.remoteStashApplicationEnteredForeground, object: nil)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        NotificationCenter.default.post(name: Notification.Name.remoteStashApplicationEnteredBackground, object: nil)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        NotificationCenter.default.post(name: Notification.Name.remoteStashApplicationEnteredForeground, object: nil)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        NotificationCenter.default.post(name: Notification.Name.remoteStashApplicationEnteredBackground, object: nil)
    }


}

