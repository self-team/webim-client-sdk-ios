//
//  ExecIfNotDestroyedHandlerExecutor.swift
//  WebimClientLibrary
//
//  Created by Nikita Lazarev-Zubov on 11.09.17.
//  Copyright © 2017 Webim. All rights reserved.
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

import Foundation

/**
 Class that encapsulates asynchronous callbacks calling.
 - author:
 Nikita Lazarev-Zubov
 - copyright:
 2017 Webim
 */
final class ExecIfNotDestroyedHandlerExecutor {
    
    // MARK: - Properties
    private let sessionDestroyer: SessionDestroyer
    private let queue: DispatchQueue
    
    // MARK: - Initialization
    init(sessionDestroyer: SessionDestroyer,
         queue: DispatchQueue) {
        self.sessionDestroyer = sessionDestroyer
        self.queue = queue
    }
    
    // MARK: - Methods
    func execute(task: DispatchWorkItem) {
        if !sessionDestroyer.isDestroyed() {
            DispatchQueue.main.async {
                if !self.sessionDestroyer.isDestroyed() {
                    task.perform()
                }
            }
        }
    }
    
}
