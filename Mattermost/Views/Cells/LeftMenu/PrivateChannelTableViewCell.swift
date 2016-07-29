//
//  PrivateChannelTableViewCell.swift
//  Mattermost
//
//  Created by Igor Vedeneev on 28.07.16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

class PrivateChannelTableViewCell: UITableViewCell {
    @IBOutlet weak var statusView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var badgeLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        
    }
    
    private func configureTitleLabel() -> Void {
        self.titleLabel.font = FontBucket.postAuthorNameFont
    }
}
