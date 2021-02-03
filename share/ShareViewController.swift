//
//  ShareViewController.swift
//  share
//
//  Created by Brice Rosenzweig on 01/02/2021.
//

import UIKit
import Social
import os

fileprivate let logger = Logger(subsystem: "net.ro-z.remotestash.share", category: "extension")
class ShareViewController: SLComposeServiceViewController,RemoteStashClientDelegate {

    var client : RemoteStashClient? = nil
    
    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.client = RemoteStashClient(delegate: self)
        NotificationCenter.default.addObserver(forName: Notification.Name.remoteStashNewServiceDiscovered, object: nil, queue: nil) {
            notification in
            DispatchQueue.main.async {
                self.reloadConfigurationItems()
            }
        }
    }
    
    override func didSelectPost() {
        guard
            let context = self.extensionContext
        else {
            super.didSelectPost()
            return
        }
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        RemoteStashItem.item(from: context){
            item in
            if let service = self.client?.service, let item = item {
                logger.info("pushing \(item)")
                service.pushItem(item: item ){
                    _,_ in
                    DispatchQueue.main.async {
                        self.extensionContext!.completeRequest(returningItems: context.inputItems, completionHandler: nil)
                    }
                }
            }else{
                logger.error("no service selected")
                DispatchQueue.main.async {
                    self.extensionContext!.completeRequest(returningItems: context.inputItems, completionHandler: nil)
                }

            }
        }
    }

    override func configurationItems() -> [Any]! {
        var rv : [Any] = []
        if let service =  self.client?.service{
            if let item = SLComposeSheetConfigurationItem() {
                item.title = "RemoteStash"
                item.value = service.name
                item.tapHandler = {
                    self.pushServiceSelectionController()
                }
                rv.append(item)
            }
        }
        return rv
    }

    func remoteStashClient(_ client: RemoteStashClient, add service: RemoteStashService) {
        DispatchQueue.main.async {
            self.reloadConfigurationItems()
        }
    }
    
    func pushServiceSelectionController() {
        let tvc = UITableViewController(style: .grouped)
        tvc.tableView.dataSource = self.client
        tvc.tableView.delegate = self.client
        self.navigationController?.pushViewController(tvc, animated: true)
    }
}
