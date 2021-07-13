//
//  ChatTableViewController.swift
//  WebimClientLibrary_Example
//
//  Created by Eugene Ilyin on 19/09/2019.
//  Copyright © 2019 Webim. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import AVFoundation
import UIKit
import WebimClientLibrary
import SnapKit
import Nuke

class ChatTableViewController: UITableViewController, DepartmentListHandlerDelegate {

    // MARK: - Properties
    var selectedCellRow: Int?
    var scrollButtonIsHidden = true
    var surveyCounter = -1
    // MARK: - Private properties
    private let newRefreshControl = UIRefreshControl()
    
    private var alreadyRatedOperators = [String: Bool]()
    var cellHeights = [IndexPath: CGFloat]()
    private var overlayWindow: UIWindow?
    private var visibleRows = [IndexPath]()
    
    weak var chatViewController: ChatViewController?
    
    var rateStarsViewController: RateStarsViewController?
    var surveyCommentViewController: SurveyCommentViewController?
    var surveyRadioButtonViewController: SurveyRadioButtonViewController?
    
    lazy var messages = [Message]()
    lazy var alertDialogHandler = UIAlertHandler(delegate: self)

    // MARK: - View Life Cycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        setupWebimSession()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showFile),
            name: .shouldShowFile,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setVisitorTypingDraft),
            name: .shouldSetVisitorTypingDraft,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hideOverlayWindow),
            name: .shouldHideOverlayWindow,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sendKeyboardRequest),
            
            name: .shouldSendKeyboardRequest,
            object: nil
        )
        
        registerCells()
        
        setupRefreshControl()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        WebimServiceController.shared.notFatalErrorHandler = self
        WebimServiceController.shared.departmentListHandlerDelegate = self
        WebimServiceController.shared.fatalErrorHandlerDelegate = self
        updateCurrentOperatorInfo(to: WebimServiceController.currentSession.getCurrentOperator())
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Will not trigger method hidePopupActionsViewController()
        // if PopupActionsTableView is not presented
        NotificationCenter.default.postInMainThread(
            name: .shouldHidePopupActionsViewController,
            object: nil
        )
        
        coordinator.animate(
            alongsideTransition: { context in
                // Save visible rows position
                if let visibleRows = self.tableView.indexPathsForVisibleRows {
                    self.visibleRows = visibleRows
                }
                context.viewController(forKey: .from)
            },
            completion: { _ in
                // Scroll to the saved position prior to screen rotate
                if let lastVisibleRow = self.visibleRows.last {
                    self.tableView.scrollToRowSafe(
                        at: lastVisibleRow,
                        at: .bottom,
                        animated: true
                    )
                }
            }
        )
    }
    
    // MARK: - Methods
    /// Preparation for the future
    internal func set(messages: [Message]) {
        self.messages = messages
    }
    
    @objc
    private func sendKeyboardRequest(_ notification: Notification) {
        guard let buttonInfoDictionary = notification.userInfo as? [String: String],
            let messageID = buttonInfoDictionary["Message"],
            let buttonID = buttonInfoDictionary["ButtonID"],
            buttonInfoDictionary["ButtonTitle"] != nil
            else { return }
        
        if let message = findMessage(withID: messageID),
            let button = findButton(inMessage: message, buttonID: buttonID) {
            // TODO: Send request
            print("Sending keyboard request...")
            
            WebimServiceController.currentSession.sendKeyboardRequest(
                button: button,
                message: message,
                completionHandler: self
            )
        } else {
            print("HALT! There isn't such message or button in #function")
        }
    }
    
    private func findMessage(withID id: String) -> Message? {
        for message in messages {
            if message.getID() == id {
                return message
            }
        }
        return nil
    }
    
    private func findButton(
        inMessage message: Message,
        buttonID: String
    ) -> KeyboardButton? {
        guard let buttonsArrays = message.getKeyboard()?.getButtons() else { return nil }
        let buttons = buttonsArrays.flatMap { $0 }
        
        for button in buttons {
            if button.getID() == buttonID {
                return button
            }
        }
        return nil
    }
    ///
    
    func sendMessage(_ message: String) {
        WebimServiceController.currentSession.send(message: message) {
            self.chatViewController?.textInputTextView.updateText("")
            // Delete visitor typing draft after message is sent.
            WebimServiceController.currentSession.setVisitorTyping(draft: nil)
        }
    }
    
    func sendImage(image: UIImage, imageURL: URL?) {
        chatViewController?.dismissKeyboardNow()
        
        var imageData = Data()
        var imageName = String()
        var mimeType = MimeType()
        
        if let imageURL = imageURL {
            mimeType = MimeType(url: imageURL as URL)
            imageName = imageURL.lastPathComponent
            
            let imageExtension = imageURL.pathExtension.lowercased()
            
            switch imageExtension {
            case "jpg", "jpeg":
                guard let unwrappedData = image.jpegData(compressionQuality: 1.0)
                    else { return }
                imageData = unwrappedData
                
            case "heic", "heif":
                guard let unwrappedData = image.jpegData(compressionQuality: 0.5)
                    else { return }
                imageData = unwrappedData
            
                var components = imageName.components(separatedBy: ".")
                if components.count > 1 {
                    components.removeLast()
                    imageName = components.joined(separator: ".")
                }
                imageName += ".jpeg"
                
            default:
                guard let unwrappedData = image.pngData()
                    else { return }
                imageData = unwrappedData
            }
        } else {
            guard let unwrappedData = image.jpegData(compressionQuality: 1.0)
                else { return }
            imageData = unwrappedData
            imageName = "photo.jpeg"
        }
        
        WebimServiceController.currentSession.send(
            file: imageData,
            fileName: imageName,
            mimeType: mimeType.value,
            completionHandler: self
        )
    }
    
    func sendFile(file: Data, fileURL: URL?) {
        if let fileURL = fileURL {
            WebimServiceController.currentSession.send(
                file: file,
                fileName: fileURL.lastPathComponent,
                mimeType: MimeType(url: fileURL as URL).value,
                completionHandler: self
            )
        } else {
            let url = URL(fileURLWithPath: "document.pdf")
            WebimServiceController.currentSession.send(
                file: file,
                fileName: url.lastPathComponent,
                mimeType: MimeType(url: url).value,
                completionHandler: self
            )
        }
    }
    
    func getSelectedMessage() -> Message? {
        guard let selectedCellRow = selectedCellRow,
            selectedCellRow >= 0,
            selectedCellRow < messages.count else { return nil }
        return messages[selectedCellRow]
    }
    
    func replyToMessage(_ message: String) {
        guard let messageToReply = getSelectedMessage() else { return }
        WebimServiceController.currentSession.reply(
            message: message,
            repliedMessage: messageToReply,
            completion: {
                // Delete visitor typing draft after message is sent.
                WebimServiceController.currentSession.setVisitorTyping(draft: nil)
            }
        )
    }
    
    func copyMessage() {
        guard let messageToCopy = getSelectedMessage() else { return }
        UIPasteboard.general.string = messageToCopy.getText()
    }
    
    func editMessage(_ message: String) {
        guard let messageToEdit = getSelectedMessage() else { return }
        WebimServiceController.currentSession.edit(
            message: messageToEdit,
            text: message,
            completionHandler: self
        )
    }
    
    func deleteMessage() {
        guard let messageToDelete = getSelectedMessage() else { return }
        WebimServiceController.currentSession.delete(
            message: messageToDelete,
            completionHandler: self
        )
    }
    
    @objc
    func scrollToBottom(animated: Bool) {
        if messages.isEmpty {
            return
        }
        
        let row = (tableView.numberOfRows(inSection: 0)) - 1
        let bottomMessageIndex = IndexPath(row: row, section: 0)
        tableView.scrollToRowSafe(at: bottomMessageIndex, at: .bottom, animated: animated)
    }
    
    @objc
    func scrollToTop(animated: Bool) {
        if messages.isEmpty {
            return
        }
        
        let indexPath = IndexPath(row: 0, section: 0)
        self.tableView.scrollToRowSafe(at: indexPath, at: .top, animated: animated)
    }
    
    // MARK: - Private methods
    private func setupRefreshControl() {
        if #available(iOS 10.0, *) {
            tableView?.refreshControl = newRefreshControl
        } else {
            tableView?.addSubview(newRefreshControl)
        }
        newRefreshControl.layer.zPosition -= 1
        newRefreshControl.addTarget(
            self,
            action: #selector(requestMessages),
            for: .valueChanged
        )
        newRefreshControl.tintColor = refreshControlTintColour
        let attributes = [NSAttributedString.Key.foregroundColor: refreshControlTextColour]
        newRefreshControl.attributedTitle = NSAttributedString(
            string: "Fetching more messages...".localized,
            attributes: attributes
        )
    }
    
    private func reloadTableWithNewData() {
        self.tableView?.reloadData()
        WebimServiceController.currentSession.setChatRead()
    }
    
    @objc
    private func requestMessages() {
        WebimServiceController.currentSession.getNextMessages { [weak self] messages in
            self?.messages.insert(contentsOf: messages, at: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.reloadTableWithNewData()
                self?.tableView?.scrollToRowSafe(at: IndexPath(row: messages.count, section: 0), at: .middle, animated: false)
                self?.newRefreshControl.endRefreshing()
               
            }
        }
    }
    
    func shouldShowFullDate(forMessageNumber index: Int) -> Bool {
        guard index - 1 >= 0 else { return true }
        let currentMessageTime = messages[index].getTime()
        let previousMessageTime = messages[index - 1].getTime()
        let differenceBetweenDates = Calendar.current.dateComponents(
            [.day],
            from: previousMessageTime,
            to: currentMessageTime
        )
        return differenceBetweenDates.day != 0
    }
    
    func shouldShowOperatorInfo(forMessageNumber index: Int) -> Bool {
        guard messages[index].isOperatorType() else { return false }
        guard index + 1 < messages.count else { return true }
        
        let nextMessage = messages[index + 1]
        if nextMessage.isOperatorType() {
            return false
        } else {
            return true
        }
    }
    
    @objc
    func showPopoverMenu(_ gestureRecognizer: UIGestureRecognizer) {

        AppDelegate.keyboardHidden(true)
        
        var stateToCheck = UIGestureRecognizer.State.ended
        
        if gestureRecognizer is UILongPressGestureRecognizer {
            stateToCheck = UIGestureRecognizer.State.began
        }
        
        if gestureRecognizer.state == stateToCheck {
            let touchPoint = gestureRecognizer.location(in: self.tableView)
            if let indexPath = self.tableView.indexPathForRow(at: touchPoint) {
                
                guard let selectedCell = self.tableView.cellForRow(at: indexPath)
                    as? FlexibleTableViewCell
                    else { return }
                let selectedCellRow = indexPath.row
                self.selectedCellRow = selectedCellRow
                
                let viewController = PopupActionsViewController()
                viewController.modalPresentationStyle = .overFullScreen
                viewController.cellImageViewImage = selectedCell.takeScreenshot()
                
                guard let globalYPosition = selectedCell.superview?
                    .convert(selectedCell.center, to: nil)
                    else { return }
                viewController.cellImageViewCenterYPosition = globalYPosition.y
                
                guard let cellHeight = cellHeights[indexPath] else { return }
                viewController.cellImageViewHeight = cellHeight
                
                let message = messages[selectedCellRow]
                
                if message.isOperatorType() {
                    viewController.originalCellAlignment = .leading
                } else if message.isVisitorType() {
                    viewController.originalCellAlignment = .trailing
                }
                
                if message.canBeReplied() {
                    viewController.actions.append(.reply)
                }
                
                if message.canBeCopied() {
                    viewController.actions.append(.copy)
                }
                
                if message.canBeEdited() {
                    viewController.actions.append(.edit)

                    // If image hide show edit action
                    if let contentType = message.getData()?.getAttachment()?.getFileInfo().getContentType() {
                        if isImage(contentType: contentType) {
                            viewController.actions.removeLast()
                        }
                    }
                    viewController.actions.append(.delete)
                }
                
                if !viewController.actions.isEmpty {
                    DispatchQueue.main.async {
                        self.present(viewController, animated: false)
                    }
                }
            }
        }
    }
    
    @objc
    private func hideOverlayWindow(notification: Notification) {
        AppDelegate.keyboardHidden(false)
    }

    private func showOverlayWindow() {
        
        if AppDelegate.keyboardWindow != nil {
            overlayWindow?.isHidden = false
        }
        AppDelegate.keyboardHidden(true)
    }
    
    @objc
    func showImage(_ recognizer: UIGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        let tapLocation = recognizer.location(in: tableView)
        
        guard let tapIndexPath = tableView?.indexPathForRow(at: tapLocation) else { return }
        let message = messages[tapIndexPath.row]
        guard let url = message.getData()?.getAttachment()?.getFileInfo().getURL(),
            let vc = storyboard?.instantiateViewController(withIdentifier: "ImageView")
                as? ImageViewController
            else { return }

        let request = ImageRequest(url: url)
        vc.selectedImageURL = url
        vc.selectedImage = ImageCache.shared[request]
        
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc
    private func showFile(sender: Notification) {
        guard let files = sender.userInfo as? [String: String],
            let fileName = files["FullName"]
            else { return }
        
        let documentsPath = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask)[0]
        
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: destinationURL.path),
            let vc = storyboard?.instantiateViewController(withIdentifier: "FileView")
                as? FileViewController
            else { return }
        
        vc.fileDestinationURL = destinationURL
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc
    func rateOperatorByTappingAvatar(recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        let tapLocation = recognizer.location(in: tableView)
        
        guard let tapIndexPath = tableView?.indexPathForRow(at: tapLocation) else { return }
        let message = messages[tapIndexPath.row]
        
        self.showRateOperatorDialog(operatorId: message.getOperatorID())
    }

    @objc
    private func addRatedOperator(_ notification: Notification) {
        guard let ratingInfoDictionary = notification.userInfo
        as? [String: Int]
        else { return }
        
        for (id, rating) in ratingInfoDictionary {
            rateOperator(
                operatorID: id,
                rating: rating
            )
        }
    }
    
    // Webim methods
    private func setupWebimSession() {
        
        WebimServiceController.currentSession.setMessageTracker(withMessageListener: self)
        WebimServiceController.currentSession.set(operatorTypingListener: self)
        WebimServiceController.currentSession.set(currentOperatorChangeListener: self)
        WebimServiceController.currentSession.set(chatStateListener: self)
        WebimServiceController.currentSession.set(surveyListener: self)
        WebimServiceController.currentSession.getLastMessages { [weak self] messages in
            self?.messages.insert(contentsOf: messages, at: 0)
            DispatchQueue.main.async {
                self?.reloadTableWithNewData()
                self?.scrollToBottom(animated: false)
            }
        }
    }
    
    private func updateCurrentOperatorInfo(to newOperator: Operator?) {
        let operatorInfoDictionary: [String: String]
        if let currentOperator = newOperator {
            let operatorURLString: String
            if let avatarURLString = currentOperator.getAvatarURL()?.absoluteString {
                operatorURLString = avatarURLString
            } else {
                operatorURLString = OperatorAvatar.placeholder.rawValue
            }
        
            operatorInfoDictionary = [
                "OperatorName": currentOperator.getName(),
                "OperatorAvatarURL": operatorURLString
            ]
        } else {
            operatorInfoDictionary = [
                "OperatorName": "Webim demo-chat".localized,
                "OperatorAvatarURL": OperatorAvatar.empty.rawValue
            ]
        }
        
        NotificationCenter.default.postInMainThread(
            name: .shouldUpdateOperatorInfo,
            object: nil,
            userInfo: operatorInfoDictionary
        )
    }
    
    @objc
    private func setVisitorTypingDraft(_ notification: Notification) {
        guard let typingDraftDictionary = notification.userInfo as? [String: String] else { // Not string passed (nil) set draft to nil
            WebimServiceController.currentSession.setVisitorTyping(draft: nil)
            return
        }
        guard let draftText = typingDraftDictionary["DraftText"] else { return }
        WebimServiceController.currentSession.setVisitorTyping(draft: draftText)
    }
    
    private func registerCells() {
        tableView?.register(
            FlexibleTableViewCell.self,
            forCellReuseIdentifier: "FlexibleTableViewCell"
        )
    }
    
    // MARK: - WEBIM: DepartmentListHandlerDelegate
    func showDepartmentsList(_ departaments: [Department], action: @escaping (String) -> Void) {
        alertDialogHandler.showDepartmentListDialog(
            withDepartmentList: departaments,
            action: action,
            senderButton: self.chatViewController?.textInputButton,
            cancelAction: { }
        )
    }
}

// MARK: - WEBIM: MessageListener
extension ChatTableViewController: MessageListener {
    
    // MARK: - Methods
    
    func added(message newMessage: Message,
               after previousMessage: Message?) {
        var inserted = false
        
        if let previousMessage = previousMessage {
            for (index, message) in messages.enumerated() {
                if previousMessage.isEqual(to: message) {
                    messages.insert(newMessage, at: index)
                    inserted = true
                    break
                }
            }
        }
        
        if !inserted {
            messages.append(newMessage)
        }
        
        DispatchQueue.main.async {
            self.tableView?.reloadData()
            self.scrollToBottom(animated: true)
            WebimServiceController.currentSession.setChatRead()
        }
    }
    
    func removed(message: Message) {
        var toUpdate = false
        if message.getCurrentChatID() == getSelectedMessage()?.getCurrentChatID() {
            NotificationCenter.default.postInMainThread(
                name: .shouldHideQuoteEditBar,
                object: nil,
                userInfo: nil
            )
        }
        
        for (messageIndex, iteratedMessage) in messages.enumerated() {
            if iteratedMessage.getID() == message.getID() {
                messages.remove(at: messageIndex)
                let indexPath = IndexPath(row: messageIndex, section: 0)
                cellHeights.removeValue(forKey: indexPath)
                toUpdate = true
                
                break
            }
        }
        
        if toUpdate {
            DispatchQueue.main.async {
                self.tableView?.reloadData()
                self.scrollToBottom(animated: true)
            }
        }
    }
    
    func removedAllMessages() {
        messages.removeAll()
        cellHeights.removeAll()
        
        DispatchQueue.main.async {
            self.tableView?.reloadData()
        }
    }
    
    func changed(message oldVersion: Message,
                 to newVersion: Message) {
        let messagesCountBefore = messages.count
        var toUpdate = false
        var cellIndexToUpdate = 0
        
        for (messageIndex, iteratedMessage) in messages.enumerated() {
            if iteratedMessage.getID() == oldVersion.getID() {
                messages[messageIndex] = newVersion
                toUpdate = true
                cellIndexToUpdate = messageIndex
                
                break
            }
        }
        
        if toUpdate {
            DispatchQueue.main.async {
                let indexPath = IndexPath(row: cellIndexToUpdate, section: 0)
                if self.messages.count != messagesCountBefore ||
                    self.messages.count != self.tableView.numberOfRows(inSection: 0) {
                        self.tableView.reloadData()
                } else {
                    self.tableView.reloadRows(at: [indexPath], with: .automatic)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.scrollToBottom(animated: false)
        }
    }
}

// MARK: - WEBIM: HelloMessageListener
extension ChatViewController: HelloMessageListener {
    func helloMessage(message: String) {
        print("Received Hello message: \"\(message)\"")
    }
}

// MARK: - WEBIM: FatalErrorHandler
extension ChatTableViewController: FatalErrorHandlerDelegate {
    
    // MARK: - Methods
    func showErrorDialog(withMessage message: String) {
        alertDialogHandler.showCreatingSessionFailureDialog(withMessage: message)
    }
    
}

// MARK: - WEBIM: CompletionHandlers
extension ChatTableViewController: SendFileCompletionHandler,
                                   EditMessageCompletionHandler,
                                   DeleteMessageCompletionHandler,
                                   SendKeyboardRequestCompletionHandler {
    // MARK: - Methods
    
    func onSuccess(messageID: String) {
        // Ignored.
        // Delete visitor typing draft after message is sent.
        WebimServiceController.currentSession.setVisitorTyping(draft: nil)
    }
    
    // SendFileCompletionHandler
    func onFailure(messageID: String, error: SendFileError) {
        DispatchQueue.main.async {
            var message = "Find sending unknown error".localized
            switch error {
            case .fileSizeExceeded:
                message = "File is too large.".localized
            case .fileTypeNotAllowed:
                message = "File type is not supported".localized
            case .unknown:
                message = "Find sending unknown error".localized
            case .uploadedFileNotFound:
                message = "Sending files in body is not supported".localized
            case .unauthorized:
                message = "Failed to upload file: visitor is not logged in".localized
            case .maxFilesCountPerChatExceeded:
                message = "MaxFilesCountExceeded".localized
            case .fileSizeTooSmall:
                message = "File is too small".localized
            }
            
            self.alertOnFailure(
                with: message,
                id: messageID,
                title: "File sending failed".localized
            )
        }
    }
    
    // EditMessageCompletionHandler
    func onFailure(messageID: String, error: EditMessageError) {
        DispatchQueue.main.async {
            var message = "Edit message unknown error".localized
            switch error {
            case .unknown:
                message = "Edit message unknown error".localized
            case .notAllowed:
                message = "Editing messages is turned off on the server".localized
            case .messageEmpty:
                message = "Editing message is empty".localized
            case .messageNotOwned:
                message = "Message not owned by visitor".localized
            case .maxLengthExceeded:
                message = "MaxMessageLengthExceeded".localized
            case .wrongMesageKind:
                message = "Wrong message kind (not text)".localized
            }
            
            self.alertOnFailure(
                with: message,
                id: messageID,
                title: "Message editing failed".localized
            )
        }
    }
    
    // DeleteMessageCompletionHandler
    func onFailure(messageID: String, error: DeleteMessageError) {
        DispatchQueue.main.async {
            var message = "Delete message unknown error".localized
            switch error {
            case .unknown:
                message = "Delete message unknown error".localized
            case .notAllowed:
                message = "Deleting messages is turned off on the server".localized
            case .messageNotOwned:
                message = "Message not owned by visitor".localized
            case .messageNotFound:
                message = "Message not found".localized
            }
            
            self.alertOnFailure(
                with: message,
                id: messageID,
                title: "Message deleting failed".localized
            )
        }
    }
    
    // SendKeyboardRequestCompletionHandler
    func onFailure(messageID: String, error: KeyboardResponseError) {
        DispatchQueue.main.async {
            var message = "Send keyboard request unknown error".localized
            switch error {
            case .unknown:
                message = "Send keyboard request unknown error".localized
            case .noChat:
                message = "Chat does not exist".localized
            case .buttonIdNotSet:
                message = "Wrong button ID in request".localized
            case .requestMessageIdNotSet:
                message = "Wrong message ID in request".localized
            case .canNotCreateResponse:
                message = "Response cannot be created for this request".localized
            }
            
            let title = "Send keyboard request failed".localized
            
            self.alertDialogHandler.showSendFailureDialog(
                withMessage: message,
                title: title,
                action: { [weak self] in
                    guard self != nil else { return }
                
                // TODO: Make sure to delete message if needed
//                    for (index, message) in self.messages.enumerated() {
//                        if message.getID() == messageID {
//                            self.messages.remove(at: index)
//                            DispatchQueue.main.async {
//                                self.tableView?.reloadData()
//                            }
//
//                            return
//                        }
//                    }
                }
            )
        }
    }
    
    func alertOnFailure(with message: String, id messageID: String, title: String) {
        alertDialogHandler.showSendFailureDialog(
            withMessage: message,
            title: title,
            action: { [weak self] in
                guard let self = self else { return }
                
                for (index, message) in self.messages.enumerated() {
                    if message.getID() == messageID {
                        self.messages.remove(at: index)
                        DispatchQueue.main.async {
                            self.tableView?.reloadData()
                        }
                        return
                    }
                }
            }
        )
    }
}

// MARK: - WEBIM: OperatorTypingListener
extension ChatTableViewController: OperatorTypingListener {
    func onOperatorTypingStateChanged(isTyping: Bool) {
        guard WebimServiceController.currentSession.getCurrentOperator() != nil else { return }
        
        if isTyping {
            let statusTyping = "typing".localized
            let operatorStatus = ["Status": statusTyping]
            NotificationCenter.default.postInMainThread(
                name: .shouldChangeOperatorStatus,
                object: nil,
                userInfo: operatorStatus
            )
        } else {
            let operatorStatus = ["Status": "Online".localized]
            NotificationCenter.default.postInMainThread(
                name: .shouldChangeOperatorStatus,
                object: nil,
                userInfo: operatorStatus
            )
        }
    }
}

// MARK: - WEBIM: CurrentOperatorChangeListener
extension ChatTableViewController: CurrentOperatorChangeListener {
    func changed(operator previousOperator: Operator?, to newOperator: Operator?) {
        updateCurrentOperatorInfo(to: newOperator)
    }
}

// MARK: - WEBIM: ChatStateLisneter
extension ChatTableViewController: ChatStateListener {
    func changed(state previousState: ChatState, to newState: ChatState) {
        if newState == .closedByVisitor || newState == .closed || newState == .closedByOperator {
            // TODO: rating operator
        }
    }
}

// MARK: - WEBIM: NotFatalErrorHandler
extension ChatTableViewController: NotFatalErrorHandler {
    
    func on(error: WebimNotFatalError) {
    }
    
    func connectionStateChanged(connected: Bool) {
        chatViewController?.setConnectionStatus(connected: connected)
    }
}
