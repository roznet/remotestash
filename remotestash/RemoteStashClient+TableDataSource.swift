//
//  RemoteStashClient+TableDataSource.swift
//  remotestash
//
//  Created by Brice Rosenzweig on 03/02/2021.
//

import Foundation
import UIKit

extension RemoteStashClient : UITableViewDataSource,UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.services.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell : UITableViewCell = UITableViewCell(style: .subtitle, reuseIdentifier: "servicecell")
        if self.services.indices.contains(indexPath.row) {
            let one = self.services[indexPath.row]
            cell.textLabel?.text = one.name
            cell.detailTextLabel?.text = one.hostName
            if let selected = self.service, selected == one {
                cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            }else{
                cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            }
        }else{
            cell.textLabel?.text = "none"
            cell.detailTextLabel?.text = "error"
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.services.indices.contains(indexPath.row) {
            self.service = self.services[indexPath.row]
            tableView.reloadData()
        }
    }
    
    
}
