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
    var last : RemoteStashItem? {
        return items.last ?? RemoteStashItem(pasteboard: UIPasteboard.general)
    }
    
    var client : RemoteStashClient? = nil
    var server : RemoteStashServer? = nil
    
    func push(item : RemoteStashItem) {
        self.items.append(item)
    }
    
    func pull() -> RemoteStashItem? {
        guard self.items.isEmpty else {
            return RemoteStashItem(pasteboard: UIPasteboard.general)
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.textView.delegate = self
        
        NotificationCenter.default.addObserver(forName: Notification.Name.remoteStashNewServiceDiscovered, object: nil, queue: nil) {
            notification in
            self.client?.service?.status() {
                _,_ in
                self.update()
            }
        }
        
        NotificationCenter.default.addObserver(forName: Notification.Name.remoteStashApplicationEnteredForeground, object: nil, queue: nil){
            _ in
            self.update()
            self.server?.start()
        }
        
        NotificationCenter.default.addObserver(forName: Notification.Name.remoteStashApplicationEnteredBackground, object: nil, queue: nil){
            _ in
            self.update()
            self.server?.stop()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        super.viewWillDisappear(animated)
    }
    
    //MARK: - UI updates
    
    func update() {
        
    }
    //MARK: - button and Actions
    
    @IBAction func share(_ sender: Any) {
        if let activityItems = self.last?.activityItems {
            let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            self.present(vc, animated: true, completion: nil)
        }
    }
    
    @IBAction func push(_ sender: Any) {
        guard let item = self.last else { return }
        self.client?.service?.pushItem(item: item){
            _,_ in
            self.update()
        }
    }
    
    @IBAction func last(_ sender: Any) {
        self.client?.service?.lastItem() {
            _,item in
            guard let item = item else { return }
            self.push(item: item)
            self.update()
        }
    }
    @IBAction func pull(_ sender: Any) {
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
        
    }
    
    func remoteStashClient(_ client: RemoteStashClient, add service: RemoteStashService) {
        self.update()
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
