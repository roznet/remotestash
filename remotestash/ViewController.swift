//
//  ViewController.swift
//  remotestash
//
//  Created by Brice Rosenzweig on 01/02/2021.
//  Copyright © 2021 Brice Rosenzweig. All rights reserved.
//

import UIKit

class ViewController: UIViewController,UITextViewDelegate,RemoteStashClientDelegate,RemoteStashServerDelegate {
    
    @IBOutlet weak var shareButton: UIButton!
    
    @IBOutlet weak var imagePreview: UIImageView!
    @IBOutlet weak var received: UILabel!
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var serviceTableView: UITableView!
    @IBOutlet weak var connectedTo: UILabel!

    //MARK: - stash management
    private var items : [RemoteStashItem] = []
    var last : RemoteStashItem {
        if let rv = items.last {
            return rv
        }else{
            let rv = RemoteStashItem()
            self.items.append(rv)
            return rv
        }
    }
    var lastStatus : RemoteStashServer.Status? = nil
    
    var client : RemoteStashClient? = nil
    var server : RemoteStashServer? = nil
    
    func push(item : RemoteStashItem) {
        self.items.append(item)
    }
    
    func pull() -> RemoteStashItem? {
        guard self.items.isEmpty else {
            return RemoteStashItem()
        }
        return self.items.removeLast()
    }
    
    //MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let keytoolbar = UIToolbar()
        keytoolbar.sizeToFit()
        keytoolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done(textView:)))
        ]
        self.textView.inputAccessoryView = keytoolbar
        self.shareButton.tintColor = UIColor.systemBlue
        self.server = RemoteStashServer(delegate: self)
        self.client = RemoteStashClient(delegate: self)
        self.serviceTableView.dataSource = self.client
        self.serviceTableView.delegate = self.client
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.textView.delegate = self
        
        NotificationCenter.default.addObserver(forName: Notification.Name.remoteStashNewServiceDiscovered, object: nil, queue: nil) {
            notification in
            self.client?.service?.status() {
                _,status in
                self.lastStatus = status
                self.update()
            }
        }
        
        NotificationCenter.default.addObserver(forName: Notification.Name.remoteStashApplicationEnteredForeground, object: nil, queue: nil){
            _ in
            self.updateFromPasteboard()
            self.server?.start()
        }
        
        NotificationCenter.default.addObserver(forName: Notification.Name.remoteStashApplicationEnteredBackground, object: nil, queue: nil){
            _ in
            self.update()
            self.server?.stop()
        }
        
        self.updateFromPasteboard()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        super.viewWillDisappear(animated)
    }
    
    //MARK: - UI updates
    
    func update() {
        self.updateServiceStatus()
        self.updateLastItem()
        self.updateServiceTable()
    }

    func updateFromPasteboard(){
        // update with clipboard
        RemoteStashItem.item(pasteBoard: UIPasteboard.general){
            item in
            if let item = item {
                self.last.update(with: item)
            }
            self.update()
        }
    }
    
    func updateServiceTable() {
        DispatchQueue.main.async {
            self.serviceTableView.reloadData()
        }
    }
    
    func updateLastItem() {
        DispatchQueue.main.async {
            let item = self.last
            switch item.content{
            case .image(let img):
                self.imagePreview.image = img
                self.textView.isHidden = true
                self.imagePreview.isHidden = false
                self.received.text = NSLocalizedString("Image", comment: "Received")
            case .string(let str):
                self.textView.text = str
                self.textView.isHidden = false
                self.imagePreview.isHidden = true
                self.received.text = NSLocalizedString("String", comment: "Received")
            default:
                self.received.text = NSLocalizedString("Data", comment: "Received")
            }
        }
    }
    
    func updateServiceStatus() {
        if let status = self.lastStatus {
            DispatchQueue.main.async {
                var msg = [ "\(status.itemsCount) items"]
                if let next = status.last?.contentType {
                    msg.append("next: \(next)")
                }
                self.connectedTo.text = msg.joined(separator: ", ")
            }
        }
    }
    
    //MARK: - button and Actions
    
    @IBAction func actionShare(_ sender: Any) {
        let activityItems = self.last.activityItems
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func actionPush(_ sender: Any) {
        let item = self.last
        self.client?.service?.pushItem(item: item){
            _,_ in
            self.update()
        }
    }
    
    @IBAction func actionLast(_ sender: Any) {
        self.client?.service?.lastItem() {
            _,item in
            guard let item = item else { return }
            self.push(item: item)
            self.update()
        }
    }
    @IBAction func actionPull(_ sender: Any) {
        self.client?.service?.pullItem() {
            _,item in
            guard let item = item else { return }
            self.push(item: item)
            self.update()
        }
    }

    //MARK: - textview delegate

    @objc func done(textView: UITextView){
        UIPasteboard.general.string = self.textView.text
        self.textView.resignFirstResponder()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.last.update(text: textView.text)
        print( "update: \(self.last.content)")
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
    }
    
    //MARK: - remote Stash Client Delegate
    func remoteStashClient(_ client: RemoteStashClient, add service: RemoteStashService) {
        self.update()
    }
    
    func remoteStashClient(_ client: RemoteStashClient, shouldAdd service: RemoteStashService) -> Bool {
        return service.serverUUID != self.server?.serverUUID
    }
    
    func serverStarted(_ server: RemoteStashServer) {
        self.update()
    }
    
    func server(_ server: RemoteStashServer, received: RemoteStashItem) {
        self.push(item: received)
        self.update()
    }
    
    func serverLastItem(_ server: RemoteStashServer) -> RemoteStashItem? {
        return self.last
    }
    

}
