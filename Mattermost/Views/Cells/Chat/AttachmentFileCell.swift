//
//  AttachmentFileCell.swift
//  Mattermost
//
//  Created by Maxim Gubin on 09/08/16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

import Foundation

protocol AttachmentFileCellConfiguration: class {
    func configureWithFile(_ file: File)
}

final class AttachmentFileCell: UITableViewCell, Reusable, Attachable {
    
//MARK: Properties
    fileprivate var file: File!
    fileprivate var fileView: AttachmentFileView!
    
//MARK: LifeCycle
    override func prepareForReuse() {
        fileView.removeFromSuperview()
        fileView = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
}


//MARK: AttachmentFileCellConfiguration
extension AttachmentFileCell: AttachmentFileCellConfiguration {
    func configureWithFile(_ file: File) {
        self.file = file
        fileView = AttachmentFileView(file: file, frame: self.bounds)
        contentView.addSubview(fileView)
        self.backgroundColor = UIColor.white
        //TEMP TODO: files uploading
        self.selectionStyle = .none
        self.setNeedsDisplay()
    }
}
