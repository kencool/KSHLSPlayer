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
        static let clientIdleTimeout = 5.0
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
    public func outputSegmentData(filename: String) -> NSData? {
        return nil
    }
    
    internal func prepareHttpServer() throws {
        httpServer = HttpServer()
        if let server = httpServer {
            // m3u8
            server["/" + Config.playlistFilename] = { [weak self] request in
                if let m3u8 = self?.outputPlaylist() {
                    return .OK(.Text(m3u8))
                } else {
                    return .NotFound
                }
            }
            // ts
            server["/(.+).ts"] = { [weak self] request in
                if let filename = request.path.split("/").last {
                    if let data = self?.outputSegmentData(filename) {
                        return .RAW(200, "OK", nil, { writer in
                            writer.write(data.byteArray())
                        })
                    } else {
                        return .NotFound
                    }
                } else {
                    return .BadRequest
                }
            }
            try server.start(0)
        }
    }
    
    internal func resetIdleTimer() {
        stopIdleTimer()
        idleTimer = NSTimer.scheduledTimerWithTimeInterval(Config.clientIdleTimeout, target: self, selector: "clientDidIdle", userInfo: nil, repeats: false)
    }
    
    internal func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }
    
    internal func serviceDidReady() {
        if serviceReadyNotified { return }
        
        if let urlStr = playlistUrl(), url = NSURL(string: urlStr) where delegate != nil  {
            serviceReadyNotified = true
            dispatch_async(dispatch_get_main_queue(), { [weak self] in
                self?.delegate?.streamServer(self!, streamDidReady: url)
            })
        }
    }
    
    private func clientDidIdle() {
        delegate?.streamServer(clientIdle: self)
    }
}

public protocol KSStreamServerDelegate: class {
    
    func streamServer(server: KSStreamServer, streamDidReady url: NSURL)
    
    func streamServer(server: KSStreamServer, streamDidFail error: KSError)
    
    func streamServer(clientIdle server: KSStreamServer)
}

extension NSData {
    
    func byteArray() -> [UInt8] {
        return Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(self.bytes), count: self.length))
    }
}
