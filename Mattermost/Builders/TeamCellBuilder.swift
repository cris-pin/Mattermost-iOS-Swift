//
//  TeamCellBuilder.swift
//  Mattermost
//
//  Created by TaHyKu on 20.10.16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

import Foundation

private protocol TeamCellBuilderInteface: class {
    func cellHeight() -> CGFloat
    func cellFor(team: Team, indexPath: IndexPath) -> UITableViewCell
}

final class TeamCellBuilder {

//MARK: Properties
    fileprivate let tableView: UITableView
    
//MARK: LifeCycle
    init(tableView: UITableView) {
        self.tableView = tableView
    }
    
    private init?() {
        return nil
    }
}


//MARK: TeamCellBuilderInteface
extension TeamCellBuilder: TeamCellBuilderInteface {
    func cellHeight() -> CGFloat {
        return 60
    }
    
    func cellFor(team: Team, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TeamTableViewCell.reuseIdentifier, for: indexPath) as! TeamTableViewCell
        cell.configureWithTeam(team)
        return cell
    }
}
