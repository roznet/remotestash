//
//  ViewController.swift
//  remotestash
//
//  Created by Brice Rosenzweig on 01/02/2021.
//  Copyright © 2021 Brice Rosenzweig. All rights reserved.
//

import UIKit

class ViewController: UIViewController,UITextViewDelegate {
    
    @IBOutlet weak var shareButton: UIButton!
    
    @IBOutlet weak var imagePreview: UIImageView!
    @IBOutlet weak var received: UILabel!
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var serviceTableView: UITableView!
    @IBOutlet weak var connectedTo: UILabel!
        
    
    var client : RemoteStashClient? = nil
    var server : RemoteStashServer? = nil
    
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.textView.delegate = self
        
        
        
    }
    
    //MARK: - button and Actions
    
    @IBAction func share(_ sender: Any) {
    }
    
    @IBAction func push(_ sender: Any) {
    }
    
    @IBAction func last(_ sender: Any) {
    }
    @IBAction func pull(_ sender: Any) {
    }

    //MARK: - textview delegate

    @objc func done(textView: UITextView){
        UIPasteboard.general.string = self.textView.text
        self.textView.resignFirstResponder()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        
    }
}
