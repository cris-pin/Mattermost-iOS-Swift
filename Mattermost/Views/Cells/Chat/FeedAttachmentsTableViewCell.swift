//
//  FeedAttachmentsTableViewCell.swift
//  Mattermost
//
//  Created by Igor Vedeneev on 27.07.16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

import WebImage
import RealmSwift

final class FeedAttachmentsTableViewCell: FeedCommonTableViewCell {
    
//MARK: Properties
    fileprivate let tableView = UITableView()
    fileprivate var attachments : List<File>!
    
//MARK: LifeCycle
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        initialSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let x = Constants.UI.MessagePaddingSize
        var y = (self.post.hasParentPost() ? (36 + 64 + Constants.UI.ShortPaddingSize) : 36)
        if (self.post.message?.characters.count)! > 0 { y += CGFloat(post.attributedMessageHeight) }
        let widht = UIScreen.screenWidth() - Constants.UI.FeedCellMessageLabelPaddings - Constants.UI.PostStatusViewSize
        let height = self.tableView.contentSize.height
        
        self.tableView.frame = CGRect(x: x, y: y, width: widht, height: height)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}


//MARK: Configuration
extension FeedAttachmentsTableViewCell {
    override func configureWithPost(_ post: Post) {
        super.configureWithPost(post)
        self.attachments = self.post.files
        self.tableView.reloadData()
    }
    
    override class func heightWithPost(_ post: Post) -> CGFloat {
        let messageHeight = CGFloat(post.attributedMessageHeight) + 24 + 8
        
        var tableViewHeight: CGFloat = 0
        for file in post.files {
            var fileHeight: CGFloat = 56
            if file.isImage {
                let thumbUrl = file.thumbURL()
                let image = SDImageCache.shared().imageFromMemoryCache(forKey: thumbUrl?.absoluteString)
                if image != nil {
                    fileHeight = (image?.size.height)!
                    let scale = (UIScreen.screenWidth() - 20) / (image?.size.width)!
                    fileHeight = fileHeight * scale - 20
                } else {
                    fileHeight = (UIScreen.screenWidth() - Constants.UI.FeedCellMessageLabelPaddings) * 0.56 - 5
                }
            }
            tableViewHeight += fileHeight
        }
        
        return messageHeight + tableViewHeight
    }
}


fileprivate protocol Setup: class {
    func initialSetup()
    func setupTableView()
}


//MARK: Setup
extension FeedAttachmentsTableViewCell: Setup {
    func initialSetup() {
        setupTableView()
    }
    
    func setupTableView() {
        self.tableView.scrollsToTop = false
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.separatorStyle = .none
        self.tableView.bounces = false
        self.tableView.isScrollEnabled = false
        
        self.tableView.register(AttachmentImageCell.self, forCellReuseIdentifier: AttachmentImageCell.reuseIdentifier, cacheSize: 7)
        self.tableView.register(AttachmentFileCell.self, forCellReuseIdentifier: AttachmentFileCell.reuseIdentifier, cacheSize: 7)
        self.addSubview(self.tableView)
    }
}


//MARK: UITableViewDataSource
extension FeedAttachmentsTableViewCell : UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.attachments != nil ? 1 : 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.attachments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let file = self.attachments[indexPath.row]
        if file.isImage {
            return self.tableView.dequeueReusableCell(withIdentifier: AttachmentImageCell.reuseIdentifier) as! AttachmentImageCell
        } else {
            return self.tableView.dequeueReusableCell(withIdentifier: AttachmentFileCell.reuseIdentifier) as! AttachmentFileCell
        }
    }
}


//MARK: UITableViewDelegate
extension FeedAttachmentsTableViewCell : UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let file = self.attachments[indexPath.row]
        
        if file.isImage {
            let thumbUrl = file.thumbURL()
            if let image = SDImageCache.shared().imageFromMemoryCache(forKey: thumbUrl?.absoluteString) {
                var fileHeight = (image.size.height)
                let scale = (UIScreen.screenWidth() - 20) / (image.size.width)
                fileHeight = fileHeight * scale - 20
                return fileHeight
            }
            
            let imageWidth = UIScreen.screenWidth() - Constants.UI.FeedCellMessageLabelPaddings
            let imageHeight = imageWidth * 0.56 - 5
            return imageHeight
        } else {
            return 56
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let file = self.attachments[indexPath.row]
        (cell as! Attachable).configureWithFile(file)
    }
}
