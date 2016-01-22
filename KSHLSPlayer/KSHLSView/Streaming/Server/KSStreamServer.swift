//
//  KSStreamServer.swift
//  KSHLSPlayer
//
//  Created by Ken Sun on 2016/1/21.
//  Copyright © 2016年 KS. All rights reserved.
//

import Foundation
import Swifter

public class KSStreamServer {
    
    struct Config {
        /**
            Timeout in seconds of client being idle from requesting m3u8 playlist.
         */
        static let clientIdleTimeout = 5
        /**
            Number of times we tolerate playlist requests failed in a sequence.
         */
        static let playlistFailureMax = 10
        /**
            Number of times we tolerate unchanged playlist is received in a sequence.
         */
        static let playlistUnchangeMax = 10
        /**
            Playlist filename.
         */
        static let playlistFilename = "stream.m3u8"
    }
    
    weak var delegate: KSStreamServerDelegate?
    
    /**
        Stream source url.
     */
    internal let sourceUrl: String
    /**
        Local server address. Dynamically generated every time {@link #startService()} is called.
        http://x.x.x.x:port
     */
    internal var serviceUrl: String!
    /**
        Local http server for HLS service.
     */
    internal var httpServer: HttpServer?
    
    internal(set) public var streaming = false
    
    internal var serviceReadyNotified = false
    
    internal var playlistFailureTimes = 0
    
    internal var playlistUnchangeTimes = 0
    
    private var idleTimer: NSTimer?
    
    public init(source: String) {
        self.sourceUrl = source
    }
    
    public func playlistUrl() -> String? {
        return serviceUrl != nil ? serviceUrl + "/" + Config.playlistFilename : nil
    }
    
    // override
    public func startService() {
        
    }
    // override
    public func stopService() {
        
    }
    // override
    public func outputPlaylist() -> String? {
        return nil
    }
    // override
    public func outputSegmentData() -> NSData? {
        return nil
    }
    
    internal func prepareHttpServer() {
        
    }
    
    internal func resetIdleTimer() {
        
    }
    
    internal func stopIdleTimer() {
        
    }
    
    internal func serviceDidReady() {
        if serviceReadyNotified { return }
        if let url = playlistUrl() {
            serviceReadyNotified = true
            dispatch_async(dispatch_get_main_queue(), {
                
            })
        }
    }
}

public protocol KSStreamServerDelegate: class {
    
    func streamServer(server: KSStreamServer, streamDidReady url: NSURL)
    
    func streamServer(server: KSStreamServer, streamDidFail error: KSError)
    
    func streamServer(clientIdle server: KSStreamServer)
}
