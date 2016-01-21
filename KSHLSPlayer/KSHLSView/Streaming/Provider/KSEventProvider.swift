//
//  KSEventProvider.swift
//  KSHLSPlayer
//
//  Created by Ken Sun on 2016/1/18.
//  Copyright © 2016年 KS. All rights reserved.
//

import Foundation

public class KSEventProvider: KSStreamProvider {
    
    struct Config {
        /**
            Output segment data cache may be full if consumption is not fast enough. To prevent manager
            from halting forever, we set the maximum times allowing output unchanged. It this limit is hit,
            manager will clean cache automatically for receiving new segment data.
         */
        static let unchangedOutputMax = 10
    }
    
    /**
        Event will be cached with this id as key.
     */
    let eventId: String
    
    /**
        Event storage for `eventId`.
     */
    private let storage: KSEventStorage
    
    private let playlist: HLSPlaylist
    
    /**
        If true, manager will clean segment data cache automatically when cache is full.
        Otherwise, you should clean by yourself. Monitor segment data cache and call
        {@link #consumeSegment(String)} to consume segment. Default is false.
     */
    var autoManageCache = false
    
    private var consumedSegments: Set<String> = Set()
    
    private var outputPlaylist: String?
    
    private var outputUnchangeTimes = 0
    
    /**
        Represent whether preload from disk is complete.
     
        While initializing provider, playlist and TS data will be loaded from disk if they were cached.
        If this playlist is ended and all TS data of segments in it are available, this property will be true.
     */
    private(set) public var completePreload = false
    
    private var ending = false
    
    private var buffering = false
    
    public override convenience init(serviceUrl: String) {
        self.init(serviceUrl: serviceUrl, eventId: "\(NSDate.init().timeIntervalSince1970)")
    }
    
    required public init(serviceUrl: String, eventId: String) {
        self.eventId = eventId
        storage = KSEventStorage(eventId: eventId)
        playlist = storage.loadPlaylist() ?? HLSPlaylist(version: Config.HLSVersion, targetDuration: nil, sequence: nil, segments: [])
        super.init(serviceUrl: serviceUrl)
        
        /* Load ts data from disk */
        if playlist.segments.count > 0 {
            var incomplete = false
            // load ts data from disk
            for ts in playlist.segments {
                segments.append(ts)
                if !hasSegmentData(ts.filename()) {
                    incomplete = true
                }
            }
            // update status
            completePreload = !incomplete && playlist.isEnd()
        } else if playlist.isEnd() {
            completePreload = true
        }
        if completePreload {
            ending = true
        }
    }
    
    public func cleanUp() {
        synced(segmentFence, closure: { [unowned self] in
            self.segments.removeAll()
            self.segmentData.removeAll()
            self.outputSegments.removeAll()
        })
        outputPlaylist = nil
    }
    
    /**
        Whether segment data exists in memory or disk.
        If not in memory but in disk, load it to memory.
        @param filename
        @return
     */
    public func hasSegmentData(filename: String) -> Bool {
        if segmentData[filename] != nil {
            return true
        } else {
            if let data = storage.loadTS(filename) {
                segmentData[filename] = data
                return true
            } else {
                return false
            }
        }
    }
    
    /**
        Whether playlist is ended and all data of segments in playlist exist in memory or disk.
     */
    public func hasAllSegmentData() -> Bool {
        if !playlist.isEnd() { return false }
        
        for ts in playlist.segments {
            let filename = ts.filename()
            if segmentData[filename] != nil { continue }
            if !storage.tsFileExists(filename) { return false }
        }
        return true
    }
    
    /**
        Push segment to input list.
     */
    public func push(ts: TSSegment) {
        synced(segmentFence, closure: { [unowned self] in
            if !self.playlist.segmentNames.contains(ts.filename()) {
                /* Add segment to playlist */
                self.playlist.addSegment(ts)
                self.segments += [ts]
                /* Try to load segment data from disk */
                self.hasSegmentData(ts.filename())
            }
        })
    }
    
    /**
        Drop segment from input list if data doesn't exist.
     */
    public func drop(ts: TSSegment) {
        synced(segmentFence, closure: { [unowned self] in
            if self.segmentData[ts.filename()] == nil {
                if let index = self.segments.indexOf(ts) {
                    self.segments.removeAtIndex(index)
                }
            }
        })
    }
    
    public func fill(ts: TSSegment, data: NSData) {
        synced(segmentFence, closure: { [unowned self] in
            let filename = ts.filename()
            self.segmentData[filename] = data
            self.storage.saveTS(data, filename: filename)
        })
    }
    
    public func consume(filename: String) -> NSData? {
        return synced(segmentFence, closure: { [unowned self] () -> NSData? in
            for i in 0..<self.segments.count {
                if self.segments[i].filename() == filename {
                    self.consumedSegments.insert(filename)
                    self.segments.removeAtIndex(i)
                    break
                }
            }
            return self.segmentData.removeValueForKey(filename)
        })
    }
    
    public func endPlaylist() {
        ending = true
        buffering = false
        playlist.end = true
        updateEndingList()
    }
    
    private func updateOutputPlaylist() -> Bool {
        return true
    }
    
    private func updateEndingList() {
        
    }
    
    override public func providePlaylist() -> String {
        /* If we don't have enough segments, start buffering */
        if outputSegments.count < Config.tsPrebufferSize && !ending {
            buffering = true
        }
        /* Before we have enough buffer, we don't update playlist */
        if buffering {
            /* If buffer is enough, stop buffering and update playlist */
            if bufferedSegmentCount() >= Config.tsPrebufferSize {
                buffering = false
                updateOutputPlaylist()
                outputUnchangeTimes = 0
            }
            /* If output list unchanged limit hits, clean cache */
            outputUnchangeTimes++
            if outputUnchangeTimes > Config.unchangedOutputMax {
                synced(segmentFence, closure: { [unowned self] in
                    self.outputUnchangeTimes = 0
                    /* Drop some segments */
                    if self.outputSegments.count > 0 {
                        if let ts = self.outputSegments.last {
                            if let index = self.segments.indexOf(ts) where ts != self.segments.last {
                                let remove = self.segments.removeAtIndex(index + 1)
                                self.segmentData[remove.filename()] = nil
                            }
                        }
                    }
                })
            }
        } else {
            if ending {
                updateEndingList()
            } else {
                /* If playlist is not changed, start buffering */
                if !updateOutputPlaylist() {
                    buffering = true
                }
            }
        }
        return outputPlaylist ?? ""
    }
}

