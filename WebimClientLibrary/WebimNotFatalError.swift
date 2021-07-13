//
//  WebimNotFatalError.swift
//  WebimClientLibrary
//
//  Created by Nikita Kaberov on 06.10.19.
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

import Foundation

/**
 Abstracts Webim service possible error responses.
 - seealso:
 `FatalErrorHandler` protocol.
 - author:
 Nikita Lazarev-Zubov
 - copyright:
 2017 Webim
 */
public protocol WebimNotFatalError {
    
    /**
     - returns:
     Parsed type of the error.
     - author:
     Nikita Kaberov
     - copyright:
     2019 Webim
     */
    func getErrorType() -> NotFatalErrorType
    
    /**
     - returns:
     String representation of an error.
     - author:
     Nikita Kaberov
     - copyright:
     2019 Webim
     */
    func getErrorString() -> String
    
}

// MARK: -
/**
 Webim service error types.
 - important:
 Mind that most of this errors causes session to destroy.
 - author:
 Nikita Kaberov
 - copyright:
 2019 Webim
 */
public enum NotFatalErrorType {
    
    /**
     This error indicates no network connection.
     - author:
     Nikita Kaberov
     - copyright:
     2019 Webim
     */
    case noNetworkConnection
    
    @available(*, unavailable, renamed: "noNetworkConnection")
    case NO_NETWORK_CONNECTION
    
    /**
     This error occurs when server is not available.
     - author:
     Nikita Kaberov
     - copyright:
     2019 Webim
     */
    case serverIsNotAvailable
    
    @available(*, unavailable, renamed: "serverIsNotAvailable")
    case SERVER_IS_NOT_AVAILABLE
    
}
