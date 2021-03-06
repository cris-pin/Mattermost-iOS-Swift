//
//  PostUtils.swift
//  Mattermost
//
//  Created by Igor Vedeneev on 26.07.16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

import RealmSwift

protocol Send: class {
    func sendPost(channel: Channel, message: String, attachments: NSArray?, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func send(post: Post, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func resend(post:Post, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func reply(post: Post, channel: Channel, message: String, attachments: NSArray?, completion: @escaping (_ error: Mattermost.Error?) -> Void)
}

protocol Update: class {
    func update(post: Post, message: String, attachments: NSArray?, completion: @escaping (_ error: Mattermost.Error?) -> Void)
}

protocol Delete: class {
    func delete(post: Post, completion: @escaping (_ error: Mattermost.Error?) -> Void)
}

protocol Search: class {
    func search(terms: String, channel: Channel, completion: @escaping(_ posts: Array<Post>?, _ error: Error?) -> Void)
}

protocol Upload: class {
    func upload(items: Array<AssignedAttachmentViewItem>, channel: Channel,
                completion: @escaping (_ finished: Bool, _ error: Mattermost.Error?, _ item: AssignedAttachmentViewItem) -> Void, progress:@escaping (_ value: Float, _ index: Int) -> Void)
    func cancelUpload(item: AssignedAttachmentViewItem)
}


final class PostUtils: NSObject {

//MARK: Properies
    static let sharedInstance = PostUtils()
    fileprivate let upload_images_group = DispatchGroup()
    fileprivate var files = Array<AssignedAttachmentViewItem>()
    fileprivate var test: File?
    
    fileprivate func configureBackendPendingId(_ post: Post) {
        let id = (DataManager.sharedInstance.currentUser?.identifier)!
        let time = "\((post.createdAt?.timeIntervalSince1970)!)"
        post.pendingId = "\(id):\(time)"
    }
    
    fileprivate var assignedFiles: Array<File> = Array()
}

//MARK: Send
extension PostUtils: Send {
    func sendPost(channel: Channel, message: String, attachments: NSArray?, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let post = postToSend(channel: channel, message: message, attachments: attachments)
        RealmUtils.save(post)
        clearUploadedAttachments()
        send(post: post, completion: completion)
        self.files.forEach { (item) in
            if !item.uploaded {
                self.cancelUpload(item: item)
            }
        }
    }
    
    func send(post: Post, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        Api.sharedInstance.sendPost(post) { (error) in
            //completion(error)
            if error != nil {
                try! RealmUtils.realmForCurrentThread().write({
                    post.status = .error
                })
            }
            completion(error)
        }
    }
    
    func resend(post:Post, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        try! RealmUtils.realmForCurrentThread().write({
            post.status = .sending
        })
        send(post: post, completion: completion)
    }
    
    func reply(post: Post, channel: Channel, message: String, attachments: NSArray?, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let postReply = postToSend(channel: channel, message: message, attachments: attachments)
        postReply.parentId = post.identifier
        postReply.rootId = post.identifier
        RealmUtils.save(postReply)
        
        Api.sharedInstance.sendPost(postReply) { (error) in
            if error != nil {
                try! RealmUtils.realmForCurrentThread().write({
                    postReply.status = .error
                })
            }
            
            completion(error)
            self.clearUploadedAttachments()
        }
    }
}


//MARK: Update
extension PostUtils: Update {
    func update(post: Post, message: String, attachments: NSArray?, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        update(post: post, message: message)
        Api.sharedInstance.updateSinglePost(post) { (error) in
            completion(error)
        }
    }
}


//MARK: Delete
extension PostUtils: Delete {
    func delete(post: Post, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let day = post.day
        guard post.identifier != nil else { completion(nil); return }
        Api.sharedInstance.deletePost(post) { (error) in
            completion(error)
            guard day?.posts.count == 0 else { return }
            RealmUtils.deleteObject(day!)
        }
    }
}


//MARK: Search
extension PostUtils: Search {
    func search(terms: String, channel: Channel, completion: @escaping(_ posts: Array<Post>?, _ error: Error?) -> Void) {
        Api.sharedInstance.searchPostsWithTerms(terms: terms, channel: channel) { (posts, error) in
            guard error == nil else {
                if error?.code == -999 {
                    completion(Array(), error)
                } else {
                    completion(nil, error)
                }
                return
            }
            
            completion(posts!, error)
        }
    }
}


//MARK: Upload
extension PostUtils: Upload {
    func upload(items: Array<AssignedAttachmentViewItem>, channel: Channel, completion: @escaping (_ finished: Bool, _ error: Mattermost.Error?, _ item: AssignedAttachmentViewItem) -> Void, progress:@escaping (_ value: Float, _ index: Int) -> Void) {
        self.files.append(contentsOf: items)
        for item in items {
            print("\(item.identifier) is starting")
            self.upload_images_group.enter()
            item.uploading = true
            Api.sharedInstance.uploadFileItemAtChannel(item, channel: channel, completion: { (file, error) in
                guard self.files.contains(item) else { return }
                
                defer {
                    completion(false, error, item)
                    self.upload_images_group.leave()
                    print("\(item.identifier) is finishing")
                }
                
                guard error == nil else {
                    self.files.removeObject(item)
                    return
                }
                
                if self.assignedFiles.count == 0 {
                    self.test = file
                }
                
                let index = self.files.index(where: {$0.identifier == item.identifier})
                if (index != nil) {
                    self.assignedFiles.append(file!)
                    print("uploaded")
                }
                }, progress: { (identifier, value) in
                    let index = self.files.index(where: {$0.identifier == identifier})
                    guard (index != nil) else { return }
                    print("\(index) in progress: \(value)")
                    progress(value, index!)
            })
        }
        
        self.upload_images_group.notify(queue: DispatchQueue.main, execute: {
            //FIXME: add error
            print("UPLOADING NOTIFY")
            //completion(false,nil,item=nil)
            completion(true, nil, AssignedAttachmentViewItem(image: UIImage()))
        })
    }
    
    func cancelUpload(item: AssignedAttachmentViewItem) {
        Api.sharedInstance.cancelUploadingOperationForImageItem(item)
      //  self.upload_images_group.leave()
        let index = self.assignedFiles.index(where: {$0.identifier == item.identifier})
        
        if (index != nil) {
            self.assignedFiles.remove(at: index!)
        }
        self.files.removeObject(item)
        
        guard item.uploaded else { return }
        guard self.assignedFiles.count > 0 else { return }
      //  self.assignedFiles.remove(at: files.index(of: item)!)
    }
}


fileprivate protocol PostConfiguration: class {
    func postToSend(channel: Channel, message: String, attachments: NSArray?) -> Post
    func update(post: Post, message: String)
    func assignFilesToPostIfNeeded(_ post: Post)
    func clearUploadedAttachments()
}


//MARK: PostConfiguration
extension PostUtils: PostConfiguration {
    func postToSend(channel: Channel, message: String, attachments: NSArray?) -> Post {
        let post = Post()
        post.message = message
        post.createdAt = Date()
        post.channelId = channel.identifier
        post.authorId = Preferences.sharedInstance.currentUserId
        self.configureBackendPendingId(post)
        self.assignFilesToPostIfNeeded(post)
        post.computeMissingFields()
        post.status = .sending
        
        return post
    }
    
    func update(post: Post, message: String) {
        try! RealmUtils.realmForCurrentThread().write({
            post.message = message
            post.updatedAt = NSDate() as Date
            configureBackendPendingId(post)
            assignFilesToPostIfNeeded(post)
            post.computeMissingFields()
        })
    }
    
    func assignFilesToPostIfNeeded(_ post: Post) {
        guard self.assignedFiles.count > 0 else { return }
        
        post.files.append(objectsIn: self.assignedFiles)
    }
    
    func clearUploadedAttachments() {
        self.assignedFiles.removeAll()
        self.files.removeAll()
    }
}
