//
//  ChatViewController.swift
//  Mattermost
//
//  Created by Igor Vedeneev on 25.07.16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

import SlackTextViewController
import RealmSwift
import ImagePickerSheetController
import UITableView_Cache
import MFSideMenu


protocol ChatViewControllerInterface: class {
    func configureWithPost(post: Post)
    func changeChannelForPostFromSearch()
}

final class ChatViewController: SLKTextViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
//MARK: Properties
    //UserInterface
    override var tableView: UITableView { return super.tableView! }
    fileprivate let completePost: CompactPostView = CompactPostView.compactPostView(ActionType.Edit)
    internal let attachmentsView = PostAttachmentsView()
    fileprivate let emptyDialogueLabel = EmptyDialogueLabel()
    var refreshControl: UIRefreshControl?
    var topActivityIndicatorView: UIActivityIndicatorView?
    var scrollButton: UIButton?
    //Modules
    fileprivate var documentInteractionController: UIDocumentInteractionController?
    fileprivate var filesAttachmentsModule: AttachmentsModule!
    fileprivate var filesPickingController: FilesPickingController!
    fileprivate lazy var builder: FeedCellBuilder = FeedCellBuilder(tableView: self.tableView)
    fileprivate var resultsObserver: FeedNotificationsObserver! = nil
    //Common
    var channel : Channel!
    var indexPathScroll: NSIndexPath?
    
    fileprivate var selectedPost: Post! = nil
    fileprivate var selectedAction: String = Constants.PostActionType.SendNew
    fileprivate var emojiResult: [String]?
    fileprivate var membersResult: Array<User> = []
    fileprivate var commandsResult: [String] = []
    fileprivate var usersInTeam: Array<User> = []
    
    var hasNextPage: Bool = true
    var postFromSearch: Post! = nil
    var isLoadingInProgress: Bool = false
    
    
//MARK: LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ChannelObserver.sharedObserver.delegate = self
        initialSetup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.isNavigationBarHidden = false
        setupInputViewButtons()
        addSLKKeyboardObservers()
        replaceStatusBar()
        
        if self.postFromSearch != nil {
            changeChannelForPostFromSearch()
        }
        
        self.textView.resignFirstResponder()
        addBaseObservers()
        self.tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        UIStatusBar.shared().reset()
        removeSLKKeyboardObservers()
        removeDocumentInteractionObservers()
        
        self.resignFirstResponder()
    }
    
    override class func tableViewStyle(for decoder: NSCoder) -> UITableViewStyle {
        return .grouped
    }
}


//MARK: ChatViewControllerInterface
extension ChatViewController: ChatViewControllerInterface {
    func configureWithPost(post: Post) {
        self.postFromSearch = post
        (self.menuContainerViewController.leftMenuViewController as! LeftMenuViewController).updateSelectionFor(post.channel)
    }
    
    func changeChannelForPostFromSearch() {
        ChannelObserver.sharedObserver.selectedChannel = self.postFromSearch.channel
    }
}


fileprivate protocol Setup {
    func initialSetup()
    func setupTableView()
    func setupInputBar()
    func setupTextView()
    func setupInputViewButtons()
    func setupToolbar()
    func setupRefreshControl()
    func setupPostAttachmentsView()
    func setupTopActivityIndicator()
    func setupCompactPost()
    func setupEmptyDialogueLabel()
    func setupModules()
    func loadUsersFromTeam()
}

fileprivate protocol Private {
    func showTopActivityIndicator()
    func hideTopActivityIndicator()
    func clearTextView()
}

private protocol Action {
    func leftMenuButtonAction(_ sender: AnyObject)
    func rigthMenuButtonAction(_ sender: AnyObject)
    func searchButtonAction(_ sender: AnyObject)
    func titleTapAction()
    func sendPostAction()
    func refreshControlValueChanged()
}

private protocol Navigation {
    func proceedToSearchChat()
    func proceedToProfileFor(user: User)
    func proceedToChannelSettings(channel: Channel)
}

private protocol Request {
    func loadFirstPageOfData(isInitial: Bool)
    func loadNextPageOfData()
    func sendPost()
}

fileprivate protocol NotificationObserver: class {
    func addBaseObservers()
    func addChannelObservers()
    func addSLKKeyboardObservers()
    func removeSLKKeyboardObservers()
    func removeActionsObservers()
    func removeDocumentInteractionObservers()
}


//MARK: Setup
extension ChatViewController: Setup {
    fileprivate func initialSetup() {
        setupInputBar()
        setupScrollButton()
        setupTableView()
        setupRefreshControl()
        setupPostAttachmentsView()
        setupTopActivityIndicator()
        setupLongCellSelection()
        setupCompactPost()
        setupEmptyDialogueLabel()
        loadUsersFromTeam()
        setupModules()
    }
    
    fileprivate func setupModules() {
        self.filesAttachmentsModule = AttachmentsModule(delegate: self, dataSource: self)
        self.filesPickingController = FilesPickingController(dataSource: self)
    }
    
    func loadUsersFromTeam() {
        Api.sharedInstance.loadUsersFromCurrentTeam(completion: { (error, usersArray) in
            guard error == nil else { return }
            self.usersInTeam = usersArray!
        })
    }
    
    fileprivate func setupTableView() {
        self.tableView.separatorStyle = .none
        self.tableView.keyboardDismissMode = .onDrag
        self.tableView.backgroundColor = ColorBucket.whiteColor
        self.tableView.register(FeedCommonTableViewCell.self, forCellReuseIdentifier: FeedCommonTableViewCell.reuseIdentifier, cacheSize: 10)
        self.tableView.register(FeedAttachmentsTableViewCell.self, forCellReuseIdentifier: FeedAttachmentsTableViewCell.reuseIdentifier, cacheSize: 10)
        self.tableView.register(FeedFollowUpTableViewCell.self, forCellReuseIdentifier: FeedFollowUpTableViewCell.reuseIdentifier, cacheSize: 18)
        self.tableView.register(FeedTableViewSectionHeader.self, forHeaderFooterViewReuseIdentifier: FeedTableViewSectionHeader.reuseIdentifier())
        self.autoCompletionView.register(EmojiTableViewCell.classForCoder(), forCellReuseIdentifier: EmojiTableViewCell.reuseIdentifier)
        let nib = UINib(nibName: "MemberLinkTableViewCell", bundle: nil)
        self.autoCompletionView.register(nib, forCellReuseIdentifier: "memberLinkTableViewCell")
        self.registerPrefixes(forAutoCompletion: ["@", ":"])
        
    }
    
    fileprivate func setupInputBar() {
        setupTextView()
        setupInputViewButtons()
        setupToolbar()
    }
    
    fileprivate func setupTextView() {
        self.shouldClearTextAtRightButtonPress = false;
        self.textView.delegate = self;
        self.textView.placeholder = "Type something..."
        self.textView.layer.borderWidth = 0;
        self.textInputbar.textView.font = FontBucket.inputTextViewFont;
    }
    
    fileprivate func setupInputViewButtons() {
        let width = UIScreen.screenWidth() / 3
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: 44))
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.textColor = ColorBucket.blackColor
        titleLabel.isUserInteractionEnabled = true
        titleLabel.font = FontBucket.titleChannelFont
        titleLabel.textAlignment = .center
        titleLabel.text = self.channel?.displayName
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(titleTapAction))
        self.navigationItem.titleView = titleLabel
        self.navigationItem.titleView?.addGestureRecognizer(tapGestureRecognizer)
        
        self.rightButton.titleLabel!.font = FontBucket.feedSendButtonTitleFont;
        self.rightButton.setTitle("Send", for: UIControlState())
        self.rightButton.addTarget(self, action: #selector(sendPostAction), for: .touchUpInside)
        
        self.leftButton.setImage(UIImage(named: "common_attache_icon"), for: UIControlState())
        self.leftButton.tintColor = UIColor.gray
        self.leftButton.addTarget(self, action: #selector(attachmentSelection), for: .touchUpInside)
    }
    
    fileprivate func setupToolbar() {
        self.textInputbar.autoHideRightButton = false;
        self.textInputbar.isTranslucent = false;
        self.textInputbar.barTintColor = ColorBucket.whiteColor
    }
    
    fileprivate func setupRefreshControl() {
        let tableVc = UITableViewController() as UITableViewController
        tableVc.tableView = self.tableView
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: #selector(refreshControlValueChanged), for: .valueChanged)
        tableVc.refreshControl = self.refreshControl
    }
    
    fileprivate func setupPostAttachmentsView() {
        self.attachmentsView.backgroundColor = UIColor.blue
        self.view.insertSubview(self.attachmentsView, belowSubview: self.textInputbar)
        self.attachmentsView.anchorView = self.textInputbar
    }
    
    fileprivate func setupTopActivityIndicator() {
        self.topActivityIndicatorView  = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        self.topActivityIndicatorView!.transform = self.tableView.transform;
    }
    
    fileprivate func setupLongCellSelection() {
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction))
        self.tableView.addGestureRecognizer(longPressGestureRecognizer)
    }
    
    fileprivate func setupEmptyDialogueLabel() {
        self.emptyDialogueLabel.backgroundColor = self.tableView.backgroundColor
        self.view.insertSubview(self.emptyDialogueLabel, aboveSubview: self.tableView)
    }
    
    fileprivate func setupCompactPost() {
        let size = self.completePost.requeredSize()
        self.completePost.translatesAutoresizingMaskIntoConstraints = false
        self.completePost.isHidden = true
        self.completePost.cancelHandler = {
            self.selectedPost = nil
            self.clearTextView()
            self.dismissKeyboard(true)
            self.completePost.isHidden = true
            self.configureRightButtonWithTitle("Send", action: Constants.PostActionType.SendNew)
        }
        
        self.view.addSubview(self.completePost)
        
        let horizontal = NSLayoutConstraint(item: self.completePost, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0)
        view.addConstraint(horizontal)
        let vertical = NSLayoutConstraint(item: self.completePost, attribute: .bottom, relatedBy: .equal, toItem: self.textView, attribute: .top, multiplier: 1, constant: 0)
        view.addConstraint(vertical)
        
        let width = NSLayoutConstraint(item: self.completePost, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: size.width)
        view.addConstraint(width)
        
        let height = NSLayoutConstraint(item: self.completePost, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: size.height)
        view.addConstraint(height)
    }
    
    fileprivate func setupScrollButton() {
        self.scrollButton = UIButton.init(type: UIButtonType.system)
        self.scrollButton?.frame = CGRect(x: UIScreen.screenWidth() - 60, y: UIScreen.screenHeight() - 100, width: 50, height: 50)
        self.scrollButton?.setBackgroundImage(UIImage(named:"chat_scroll_icon")!, for: UIControlState.normal)
        self.scrollButton?.layer.cornerRadius = (self.scrollButton?.frame.size.width)! / 2
        self.scrollButton?.addTarget(self, action: #selector(scrollToBottom), for: .touchUpInside)
        self.view.addSubview(self.scrollButton!)
        self.view.bringSubview(toFront: self.scrollButton!)
        self.scrollButton?.isHidden = true;
    }
    
    override func textWillUpdate() {
        super.textWillUpdate()
        
        guard self.filesPickingController.attachmentItems.count > 0 else { return }
        self.rightButton.isEnabled = !self.filesAttachmentsModule.fileUploadingInProgress
    }
}


//MARK: Private
extension ChatViewController : Private {
    //TopActivityIndicator
    func showTopActivityIndicator() {
        let activityIndicatorHeight = self.topActivityIndicatorView!.bounds.height
        let tableFooterView = UIView(frame:CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: activityIndicatorHeight * 2))
        self.topActivityIndicatorView!.center = CGPoint(x: tableFooterView.center.x, y: tableFooterView.center.y - activityIndicatorHeight / 5)
        tableFooterView.addSubview(self.topActivityIndicatorView!)
        self.tableView.tableFooterView = tableFooterView;
        self.topActivityIndicatorView!.startAnimating()
    }
    
    func attachmentSelection() {
        self.filesPickingController.pick()
    }
    
    func hideTopActivityIndicator() {
        self.topActivityIndicatorView!.stopAnimating()
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)
    }
    
    func clearTextView() {
        self.textView.text = nil
    }
    
    func configureRightButtonWithTitle(_ title: String, action: String) {
        self.rightButton.setTitle(title, for: UIControlState())
        self.selectedAction = action
    }
    
    func showActionSheetControllerForPost(_ post: Post) {
        
        let actionSheetController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        self.selectedPost = post
        
        let replyAction = UIAlertAction(title: "Reply", style: .default) { action -> Void in
            self.selectedPost = post
            self.completePost.configureWithPost(self.selectedPost, action: ActionType.Reply)
            self.configureRightButtonWithTitle("Send", action: Constants.PostActionType.SendReply)
            self.completePost.isHidden = false
            self.presentKeyboard(true)
        }
        actionSheetController.addAction(replyAction)
        
        let copyAction = UIAlertAction(title: "Copy", style: .default) { action -> Void in
            UIPasteboard.general.string = post.message
        }
        actionSheetController.addAction(copyAction)
        
        let permalinkAction = UIAlertAction(title: "Permalink", style: .default) { action -> Void in
            UIPasteboard.general.string = post.permalink()
        }
        actionSheetController.addAction(permalinkAction)
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
            self.selectedPost = nil
        }
        actionSheetController.addAction(cancelAction)
        
        if (post.author.identifier == Preferences.sharedInstance.currentUserId) {
            let editAction = UIAlertAction(title: "Edit", style: .default) { action -> Void in
                //self.selectedPost = post
                self.completePost.configureWithPost(self.selectedPost, action: ActionType.Edit)
                self.completePost.isHidden = false
                self.configureRightButtonWithTitle("Save", action: Constants.PostActionType.SendUpdate)
                self.presentKeyboard(true)
                self.textView.text = self.selectedPost.message
            }
            actionSheetController.addAction(editAction)
            
            let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { action -> Void in
                self.selectedAction = Constants.PostActionType.DeleteOwn
                self.deletePost()
            }
            actionSheetController.addAction(deleteAction)
        }
        self.present(actionSheetController, animated: true, completion: nil)
    }
    
    fileprivate func showCompletePost(_ post: Post, action: String) {
        
    }
}


//MARK: Action
extension ChatViewController: Action {
    @IBAction func leftMenuButtonAction(_ sender: AnyObject) {
        // tempGallery()
        let state = (self.menuContainerViewController.menuState == MFSideMenuStateLeftMenuOpen) ? MFSideMenuStateClosed : MFSideMenuStateLeftMenuOpen
        self.menuContainerViewController.setMenuState(state, completion: nil)
        self.dismissKeyboard(true)
    }
    
    @IBAction func rigthMenuButtonAction(_ sender: AnyObject) {
        let state = (self.menuContainerViewController.menuState == MFSideMenuStateRightMenuOpen) ? MFSideMenuStateClosed : MFSideMenuStateRightMenuOpen
        self.menuContainerViewController.setMenuState(state, completion: nil)
    }
    
    @IBAction func searchButtonAction(_ sender: AnyObject) {
        proceedToSearchChat()
    }
    
    func titleTapAction() {
        guard Api.sharedInstance.isNetworkReachable() else { self.handleErrorWith(message: "No Internet connectivity detected"); return }
        
        if (self.channel.privateType == Constants.ChannelType.DirectTypeChannel) {
            proceedToProfileFor(user: self.channel.interlocuterFromPrivateChannel())
        } else {
            proceedToChannelSettings(channel: self.channel)
        }
    }
    
    func sendPostAction() {
        guard self.filesAttachmentsModule.fileUploadingInProgress else { self.handleWarningWith(message: "Please, wait until download finishes"); return }
        
        switch self.selectedAction {
        case Constants.PostActionType.SendReply:
            sendPostReply()
        case Constants.PostActionType.SendUpdate:
            updatePost()
        default:
            sendPost()
        }
        
        self.filesPickingController.reset()
        self.filesAttachmentsModule.reset()
    }
    
    
    func refreshControlValueChanged() {
        self.loadFirstPageOfData(isInitial: false)
        self.refreshControl?.endRefreshing()
    }
    
    func longPressAction(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard let indexPath = self.tableView.indexPathForRow(at: gestureRecognizer.location(in: self.tableView)) else { return }
        let post = resultsObserver?.postForIndexPath(indexPath)
        showActionSheetControllerForPost(post!)
    }
    
    func resendAction(_ post:Post) {
        PostUtils.sharedInstance.resend(post: post) { _ in }
    }
    
    func didTapImageAction(notification: NSNotification) {
        let postLocalId = notification.userInfo?["postLocalId"] as! String
        let fileId = notification.userInfo?["fileId"] as! String
        openPreviewWith(postLocalId: postLocalId, fileId: fileId)
    }
    
    func scrollToBottom() {
        self.tableView.setContentOffset(CGPoint(x:0, y:0), animated: true)
        self.scrollButton?.isHidden = true
    }
    
    func scrollBottomUp(keyboardHeight: CGFloat) {
        self.scrollButton?.frame.origin.y = UIScreen.screenHeight() - 100 - keyboardHeight;
    }
    
    func scrollBottomDown(keyboardHeight: CGFloat) {
        self.scrollButton?.frame.origin.y = UIScreen.screenHeight() - 100
    }
}


//MARK: Navigation
extension ChatViewController: Navigation {
    func proceedToSearchChat() {
        let transaction = CATransition()
        transaction.duration = 0.3
        transaction.timingFunction = CAMediaTimingFunction.init(name: kCAMediaTimingFunctionEaseInEaseOut)
        transaction.type = kCATransitionMoveIn
        transaction.subtype = kCATransitionFromBottom
        self.navigationController!.view.layer.add(transaction, forKey: kCATransition)
        let identifier = String(describing: SearchChatViewController.self)
        let searchChat = self.storyboard?.instantiateViewController(withIdentifier: identifier) as! SearchChatViewController
        searchChat.configureWithChannel(channel: self.channel!)
        self.navigationController?.pushViewController(searchChat, animated: false)
    }
    
    func proceedToProfileFor(user: User) {
        Api.sharedInstance.loadChannels(with: { (error) in
            guard (error == nil) else { return }
        })
        let storyboard = UIStoryboard.init(name: "Profile", bundle: nil)
        let profile = storyboard.instantiateInitialViewController()
        (profile as! ProfileViewController).configureFor(user: user)
        let navigation = self.menuContainerViewController.centerViewController
        (navigation! as AnyObject).pushViewController(profile!, animated:true)
    }
    
    func proceedToChannelSettings(channel: Channel) {
        self.dismissKeyboard(true)
        self.showLoaderView()
        Api.sharedInstance.getChannel(channel: self.channel, completion: { (error) in
            guard error == nil else { self.handleErrorWith(message: (error?.message)!); return }
            Api.sharedInstance.loadUsersListFrom(channel: channel, completion: { (error) in
                guard error == nil else {
                    let channelType = (channel.privateType == Constants.ChannelType.PrivateTypeChannel) ? "group" : "channel"
                    self.handleErrorWith(message: "You left this \(channelType)".localized)
                    return
                }
                
                let channelSettingsStoryboard = UIStoryboard(name: "ChannelSettings", bundle:nil)
                let channelSettings = channelSettingsStoryboard.instantiateViewController(withIdentifier: "ChannelSettingsViewController")
                ((channelSettings as! UINavigationController).viewControllers[0] as! ChannelSettingsViewController).channel = try! Realm().objects(Channel.self).filter("identifier = %@", channel.identifier!).first!
                self.navigationController?.present(channelSettings, animated: true, completion: { _ in
                    self.hideLoaderView()
                })
            })
        })
    }
}


//MARK: Requests
extension ChatViewController: Request {
    func loadFirstPageOfData(isInitial: Bool) {
        print("loadFirstPageOfData")
        self.isLoadingInProgress = true
        
        self.showLoaderView()
        
        Api.sharedInstance.loadFirstPage(self.channel!, completion: { (error) in
            self.hideLoaderView()
            self.isLoadingInProgress = false
            self.hasNextPage = true
            self.dismissKeyboard(true)
            
            Api.sharedInstance.updateLastViewDateForChannel(self.channel, completion: {_ in })
        })
    }
    
    func loadNextPageOfData() {
        print("loadNextPageOfData")
        guard !self.isLoadingInProgress else { return }
        
        self.isLoadingInProgress = true
        showTopActivityIndicator()
        Api.sharedInstance.loadNextPage(self.channel!, fromPost: resultsObserver.lastPost()) { (isLastPage, error) in
            self.hasNextPage = !isLastPage
            self.isLoadingInProgress = false
            self.hideTopActivityIndicator()
        }
    }
    
    func loadPostsBeforePost(post: Post, shortSize: Bool? = false) {
        print("loadPostsBeforePost")
        guard !self.isLoadingInProgress else { return }
        
        self.isLoadingInProgress = true
        Api.sharedInstance.loadPostsBeforePost(post: post, shortList: shortSize) { (isLastPage, error) in
            self.hasNextPage = !isLastPage
            if !self.hasNextPage {
                self.postFromSearch = nil
                return
            }
            
            self.isLoadingInProgress = false
            self.resultsObserver.prepareResults()
            self.loadPostsAfterPost(post: post, shortSize: true)
        }
    }
    
    func loadPostsAfterPost(post: Post, shortSize: Bool? = false) {
        print("loadPostsAfterPost")
        guard !self.isLoadingInProgress else { return }
        
        self.isLoadingInProgress = true
        Api.sharedInstance.loadPostsAfterPost(post: post, shortList: shortSize) { (isLastPage, error) in
            self.hasNextPage = !isLastPage
            self.isLoadingInProgress = false
            
            self.resultsObserver.unsubscribeNotifications()
            self.resultsObserver.prepareResults()
            self.resultsObserver.subscribeNotifications()
            
            guard post.channel.identifier == self.channel.identifier else { return }
            
            //let indexPath =  self.resultsObserver.indexPathForPost(post)
            //self.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
            
        }
    }
    
    func sendPost() {
        PostUtils.sharedInstance.sendPost(channel: self.channel!, message: self.textView.text, attachments: nil) { (error) in
            if (error != nil) {
                var message = (error?.message!)!
                if error?.code == -1011{
                    let channelType = (self.channel.privateType == Constants.ChannelType.PrivateTypeChannel) ? "group" : "channel"
                    message = "You left this " + channelType
                }
                if error?.code == -1009 {
                    self.tableView.reloadRows(at: self.tableView.indexPathsForVisibleRows!, with: .none)
                }
                
                self.handleErrorWith(message: message)
            }
            self.hideTopActivityIndicator()
        }
        self.clearTextView()
    }
    
    func sendPostReply() {
        guard (self.selectedPost != nil) else { return }
        guard self.selectedPost.identifier != nil else { return }
        
        PostUtils.sharedInstance.reply(post: self.selectedPost, channel: self.channel!, message: self.textView.text, attachments: nil) { (error) in
            if error != nil {
                self.handleErrorWith(message: (error?.message!)!)
            }
            self.selectedPost = nil
        }
        self.selectedAction = Constants.PostActionType.SendNew
        self.clearTextView()
        self.completePost.isHidden = true
    }
    
    func updatePost() {
        guard self.selectedPost != nil else { return }
        
        guard self.selectedPost.identifier != nil else { return }
        
        PostUtils.sharedInstance.update(post: self.selectedPost, message: self.textView.text, attachments: nil) {_ in self.selectedPost = nil }
        self.configureRightButtonWithTitle("Send", action: Constants.PostActionType.SendUpdate)
        self.selectedAction = Constants.PostActionType.SendNew
        self.clearTextView()
        self.completePost.isHidden = true
    }
    
    func deletePost() {
        guard self.selectedPost != nil else { return }
        
        guard self.selectedPost.identifier != nil else {
            self.selectedAction = Constants.PostActionType.SendNew
            RealmUtils.deleteObject(self.selectedPost)
            self.selectedPost = nil
            return
        }
        
        let postIdentifier = self.selectedPost.identifier!
        PostUtils.sharedInstance.delete(post: self.selectedPost) { (error) in
            self.selectedAction = Constants.PostActionType.SendNew
            
            let comments = RealmUtils.realmForCurrentThread().objects(Post.self).filter("parentId == %@", postIdentifier)
            guard comments.count > 0 else { return }
            
            RealmUtils.deletePostObjects(comments)
            
            RealmUtils.deleteObject(self.selectedPost)
            self.selectedPost = nil
        }
    }
}


//MARK: NotificationObserver
extension ChatViewController: NotificationObserver {
    func addBaseObservers() {
        let center = NotificationCenter.default
        
        center.addObserver(self, selector: #selector(presentDocumentInteractionController),
                           name: NSNotification.Name(rawValue: Constants.NotificationsNames.DocumentInteractionNotification), object: nil)
        center.addObserver(self, selector: #selector(didTapImageAction),
                           name: NSNotification.Name(rawValue: Constants.NotificationsNames.FileImageDidTapNotification), object: nil)
        center.addObserver(self, selector: #selector(reloadChat),
                           name: NSNotification.Name(rawValue: Constants.NotificationsNames.ReloadChatNotification), object: nil)
        center.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.SLKKeyboardWillShow, object: nil)
        center.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.SLKKeyboardWillHide, object: nil)
    }
    
    func addChannelObservers() {
        let center = NotificationCenter.default
        
        center.addObserver(self, selector: #selector(handleChannelNotification),
                           name: NSNotification.Name(ActionsNotification.notificationNameForChannelIdentifier(channel?.identifier)),
                           object: nil)
        center.addObserver(self, selector: #selector(handleLogoutNotification),
                           name: NSNotification.Name(rawValue: Constants.NotificationsNames.UserLogoutNotificationName),
                           object: nil)
    }
    
    func addSLKKeyboardObservers() {
        let center = NotificationCenter.default
        
        center.addObserver(self, selector: #selector(self.handleKeyboardWillHideeNotification),
                           name: NSNotification.Name.SLKKeyboardWillHide, object: nil)
        center.addObserver(self, selector: #selector(self.handleKeyboardWillShowNotification),
                           name: NSNotification.Name.SLKKeyboardWillShow, object: nil)
    }
    
    func removeSLKKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.SLKKeyboardWillHide, object: nil)
    }
    
    func removeActionsObservers() {
        let center = NotificationCenter.default
        
        guard !channel.isInvalidated else { return }
        
        center.removeObserver(self, name: NSNotification.Name(ActionsNotification.notificationNameForChannelIdentifier(channel?.identifier)),
                              object: nil)
    }
    
    func removeDocumentInteractionObservers() {
        let center = NotificationCenter.default
        
        center.removeObserver(self, name: NSNotification.Name(Constants.NotificationsNames.DocumentInteractionNotification),
                              object: nil)
    }
}


//MARK: UITableViewDataSource
extension ChatViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        guard self.resultsObserver != nil else { return 0 }
        if (tableView == self.tableView) {
            self.emptyDialogueLabel.isHidden = (self.resultsObserver.numberOfSections() > 0)
            return self.resultsObserver?.numberOfSections() ?? 1
        }
        
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (tableView == self.tableView) {
            return self.resultsObserver?.numberOfRows(section) ?? 0
        }
        
        return (self.emojiResult != nil) ? (self.emojiResult?.count)! : self.membersResult.count + commandsResult.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (tableView == self.tableView) {
            let post = resultsObserver?.postForIndexPath(indexPath)
            if self.hasNextPage && self.tableView.offsetFromTop() < 200 {
                self.loadNextPageOfData()
            }
            
            let errorHandler = { (post:Post) in
                self.errorAction(post)
            }
            
            let cell = self.builder.cellForPost(post!, errorHandler: errorHandler)
            if (cell.isKind(of: FeedCommonTableViewCell.self)) {
                (cell as! FeedCommonTableViewCell).avatarTapHandler = {
                    guard (post?.author.identifier != "SystemUserIdentifier") else { return }
                    self.proceedToProfileFor(user: (post?.author)!)
                }
            }
            
            return cell
        }
        else {
            if emojiResult != nil {
                return autoCompletionEmojiCellForRowAtIndexPath(indexPath)
            } else {
                return autoCompletionMembersCellForRowAtIndexPath(indexPath)
            }
        }
    }
}


//MARK: UITableViewDelegate
extension ChatViewController {
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard tableView == self.tableView else { return nil }
        guard resultsObserver != nil else { return UIView() }
        var view = tableView.dequeueReusableHeaderFooterView(withIdentifier: FeedTableViewSectionHeader.reuseIdentifier()) as? FeedTableViewSectionHeader
        if view == nil {
            view = FeedTableViewSectionHeader(reuseIdentifier: FeedTableViewSectionHeader.reuseIdentifier())
        }
        let frcTitleForHeader = resultsObserver.titleForHeader(section)
        let titleDate = DateFormatter.sharedConversionSectionsDateFormatter?.date(from: frcTitleForHeader)!
        let titleString = titleDate?.feedSectionDateFormat()
        view!.configureWithTitle(titleString!)
        view!.transform = tableView.transform
        
        return view!
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return (tableView == self.tableView) ? FeedTableViewSectionHeader.height() : 0
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (tableView == self.tableView) {
            let post = resultsObserver?.postForIndexPath(indexPath)
            return self.builder.heightForPost(post!)
        }
        
        return 40
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (tableView == self.autoCompletionView) {
            guard let emojiResult = self.emojiResult else {
                var item: String = ""
                if indexPath.row < self.commandsResult.count {
                    item = self.commandsResult[indexPath.row]
                } else {
                    item = self.membersResult[indexPath.row - self.commandsResult.count].username!
                    
                }
                item  += " "
                self.acceptAutoCompletion(with: item, keepPrefix: true)
                return
            }
            var item = emojiResult[indexPath.row]
            if (self.foundPrefix == ":") {
                item += ":"
            }
            item += " "
            
            self.acceptAutoCompletion(with: item, keepPrefix: true)
        }
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let actualPosition = self.tableView.contentOffset.y
        if actualPosition > UIScreen.screenHeight() {
            self.scrollButton?.isHidden = false
        }
        if actualPosition < 50 {
            self.scrollButton?.isHidden = true
        }
    }
    
    func keyboardWillShow(_ notification:NSNotification) {
        let userInfo:NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame:NSValue = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardRectangle.height
        self.scrollBottomUp(keyboardHeight: keyboardHeight)
    }
    
    func keyboardWillHide(_ notification:NSNotification) {
        let userInfo:NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame:NSValue = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardRectangle.height
        self.scrollBottomDown(keyboardHeight: keyboardHeight)
    }
}


//MARK: AttachmentsModuleDelegate
extension ChatViewController: AttachmentsModuleDelegate {
    func uploading(inProgress: Bool, countItems: Int) {
        DispatchQueue.main.async { [unowned self] in
            guard countItems > 0 else {
                self.rightButton.isEnabled = (self.textView.text.characters.count > 0)
                return
            }
            self.rightButton.isEnabled = inProgress
        }
    }
    
    func removedFromUploading(identifier: String) {
        let items = self.filesPickingController.attachmentItems.filter {
            return ($0.identifier == identifier)
        }
        guard items.count > 0 else { return }
        self.filesPickingController.attachmentItems.removeObject(items.first!)
    }
}


//MARK: ChannelObserverDelegate
extension ChatViewController: ChannelObserverDelegate {
    func didSelectChannelWithIdentifier(_ identifier: String!) -> Void {
        //old channel
        //unsubscribing from realm and channelActions
        if resultsObserver != nil {
            resultsObserver.unsubscribeNotifications()
        }
        self.resultsObserver = nil
        self.emptyDialogueLabel.isHidden = true
        if self.channel != nil {
            //remove action observer from old channel after relogin
            removeActionsObservers()
        }
        
        self.typingIndicatorView?.dismissIndicator()
        
        //new channel
        guard identifier != nil else { return }
        self.channel = RealmUtils.realmForCurrentThread().object(ofType: Channel.self, forPrimaryKey: identifier)
        self.title = self.channel?.displayName
        
        if (self.navigationItem.titleView != nil) {
            (self.navigationItem.titleView as! UILabel).text = self.channel?.displayName
        }
        self.resultsObserver = FeedNotificationsObserver(tableView: self.tableView, channel: self.channel!)
        self.textView.resignFirstResponder()
        
        if (self.postFromSearch == nil) {
            self.loadFirstPageOfData(isInitial: true)
        } else {
            if self.postFromSearch.channel.identifier != identifier {
                self.postFromSearch = nil
                self.loadFirstPageOfData(isInitial: true)
            } else {
                loadPostsBeforePost(post: self.postFromSearch, shortSize: true)
            }
        }
        
        addChannelObservers()
    }
}


//MARK: Handlers
extension ChatViewController {
    func handleChannelNotification(_ notification: Notification) {
        if let actionNotification = notification.object as? ActionsNotification {
            let user = User.self.objectById(actionNotification.userIdentifier)
            switch (actionNotification.event!) {
            case .Typing:
                if (actionNotification.userIdentifier != Preferences.sharedInstance.currentUserId) {
                    typingIndicatorView?.insertUsername(user?.username)
                }
            default:
                typingIndicatorView?.removeUsername(user?.username)
            }
        }
    }
    
    func handleLogoutNotification() {
        self.channel = nil
        self.resultsObserver = nil
        ChannelObserver.sharedObserver.delegate = nil
    }
    
    func errorAction(_ post: Post) {
        let controller = UIAlertController(title: "Your message was not sent", message: "Tap resend to send this message again", preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: "Resend", style: .default, handler: { (action:UIAlertAction) in
            self.resendAction(post)
        }))
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(controller, animated: true) {}
    }
    
    func reloadChat(notification: NSNotification) {
        guard notification.userInfo?["postLocalId"] != nil else { return }
        
        let postLocalId = notification.userInfo?["postLocalId"] as! String
        let post = RealmUtils.realmForCurrentThread().object(ofType: Post.self, forPrimaryKey: postLocalId)
        
        guard post != nil else { return }
        guard !(post?.isInvalidated)! else { return }
        guard self.resultsObserver != nil else { return }
        guard self.channel.identifier == post?.channel.identifier else { return }
        let indexPath = self.resultsObserver.indexPathForPost(post!)
        
        guard (self.tableView.indexPathsForVisibleRows?.contains(indexPath))! else { return }
        
        self.tableView.beginUpdates()
        self.tableView.reloadRows(at: [indexPath], with: .automatic)
        self.tableView.endUpdates()
    }
}


//MARK: UITextViewDelegate
extension ChatViewController {
    func handleKeyboardWillShowNotification() {
    }
    
    func handleKeyboardWillHideeNotification() {
        self.completePost.isHidden = true
    }
    
    override func textViewDidChange(_ textView: UITextView) {
        SocketManager.sharedInstance.sendNotificationAboutAction(.Typing, channel: channel!)
    }
}

extension ChatViewController: FilesPickingControllerDataSource {
    func attachmentsModule(controller: FilesPickingController) -> AttachmentsModule {
        return self.filesAttachmentsModule
    }
}

extension ChatViewController: AttachmentsModuleDataSource {
    func tableView(attachmentsModule: AttachmentsModule) -> UITableView {
        return self.tableView
    }
    func postAttachmentsView(attachmentsModule: AttachmentsModule) -> PostAttachmentsView {
        return self.attachmentsView
    }
    func channel(attachmentsModule: AttachmentsModule) -> Channel {
        return self.channel
    }
}


//MARK: AutoCompletionView
extension ChatViewController {
    func autoCompletionEmojiCellForRowAtIndexPath(_ indexPath: IndexPath) -> EmojiTableViewCell {
        let cell = self.autoCompletionView.dequeueReusableCell(withIdentifier: EmojiTableViewCell.reuseIdentifier) as! EmojiTableViewCell
        cell.selectionStyle = .default
        
        guard let searchResult = self.emojiResult else { return cell }
        guard let prefix = self.foundPrefix else { return cell }
        
        let text = searchResult[indexPath.row]
        let originalIndex = Constants.EmojiArrays.mattermost.index(of: text)
        cell.configureWith(index: originalIndex)
        
        return cell
    }
    
    func autoCompletionMembersCellForRowAtIndexPath(_ indexPath: IndexPath) -> MemberLinkTableViewCell {
        let cell = self.autoCompletionView.dequeueReusableCell(withIdentifier: "memberLinkTableViewCell") as! MemberLinkTableViewCell
        cell.selectionStyle = .default
        
        guard  (self.membersResult != [] || self.commandsResult != []) else { return cell }
        guard let prefix = self.foundPrefix else { return cell }
        if indexPath.row < self.commandsResult.count{
            let commandIndex = Constants.LinkCommands.name.index(of: commandsResult[indexPath.row])
            cell.configureWithIndex(index: commandIndex!)
        } else {
            let member = self.membersResult[indexPath.row - self.commandsResult.count]
            cell.configureWithUser(user: member)
        }
        
        return cell
    }
    
    override func shouldProcessText(forAutoCompletion text: String) -> Bool {
        return true
    }
    
    override func didChangeAutoCompletionPrefix(_ prefix: String, andWord word: String) {
        var array:Array<String> = []
        self.emojiResult = nil
        self.membersResult = []
        self.commandsResult = []
        
        if (prefix == ":") && word.characters.count > 0 {
            array = Constants.EmojiArrays.mattermost.filter { NSPredicate(format: "self BEGINSWITH[c] %@", word).evaluate(with: $0) };
        }
        
        if (prefix == "@") {
            self.membersResult = usersInTeam.filter({
                ($0.username?.lowercased().hasPrefix(word.lowercased()))! || word==""
            })
            
            self.commandsResult = Constants.LinkCommands.name.filter {
                return $0.hasPrefix(word.lowercased())
            }
        }
        
        var show = false
        if array.count > 0 {
            let sortedArray = array.sorted { $0.localizedCaseInsensitiveCompare($1) == ComparisonResult.orderedAscending }
            self.emojiResult = sortedArray
            show = sortedArray.count > 0
        } else {
            show = self.membersResult != [] || self.commandsResult != []
        }
        
        self.showAutoCompletionView(show)
    }
    
    override func heightForAutoCompletionView() -> CGFloat {
        guard let smilesResult = self.emojiResult else {
            guard (self.membersResult != [] || self.commandsResult != []) else { return 0 }
            
            let cellHeight = (self.autoCompletionView.delegate?.tableView!(self.autoCompletionView, heightForRowAt: IndexPath(row: 0, section: 0)))!
            return cellHeight * CGFloat(self.membersResult.count+self.commandsResult.count)
        }
        let cellHeight = (self.autoCompletionView.delegate?.tableView!(self.autoCompletionView, heightForRowAt: IndexPath(row: 0, section: 0)))!
        
        return cellHeight * CGFloat(smilesResult.count)
    }
}


//MARK: ChatViewController
extension ChatViewController {
    func presentDocumentInteractionController(notification: NSNotification) {
        let fileId = notification.userInfo?["fileId"]
        let file = RealmUtils.realmForCurrentThread().object(ofType: File.self, forPrimaryKey: fileId)
        let filePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/" + (file?.name)!
        
        if FileManager.default.fileExists(atPath: filePath) {
            self.documentInteractionController = UIDocumentInteractionController(url: URL(fileURLWithPath: filePath))
            self.documentInteractionController?.delegate = self
            self.documentInteractionController?.presentPreview(animated: true)
        }
    }
}


//MARK: UIDocumentInteractionControllerDelegate
extension ChatViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionController(_ controller: UIDocumentInteractionController, willBeginSendingToApplication application: String?) {
    }
    func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
    }
    func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
    }
    func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) {
    }
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
}


//MARK: ImagesPreviewViewController
extension ChatViewController {
    func openPreviewWith(postLocalId: String, fileId: String) {
        let last = self.navigationController?.viewControllers.last
        guard last != nil else { return }
        guard !(last?.isKind(of: ImagesPreviewViewController.self))! else { return }
        
        let gallery = self.storyboard?.instantiateViewController(withIdentifier: "ImagesPreviewViewController") as! ImagesPreviewViewController

        gallery.configureWith(postLocalId: postLocalId, initalFileId: fileId)
        let transaction = CATransition()
        transaction.duration = 0.5
        transaction.timingFunction = CAMediaTimingFunction.init(name: kCAMediaTimingFunctionEaseInEaseOut)
        transaction.type = kCATransitionMoveIn
        transaction.subtype = kCATransitionFromBottom
        self.navigationController!.view.layer.add(transaction, forKey: kCATransition)
        self.navigationController?.pushViewController(gallery, animated: false)
    }
}
