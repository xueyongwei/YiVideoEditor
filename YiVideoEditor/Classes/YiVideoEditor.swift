//
//  YiVideoEditor.swift
//  YiVideoEditor
//
//  Created by coderyi on 2021/10/4.
//

import Foundation
import AVFoundation

public enum YiVideoEditorRotateDegree: Int {
    case rotateDegree90 = 0
    case rotateDegree180 = 1
    case rotateDegree270 = 2
}

protocol YiVideoEditorCommandProtocol: NSObjectProtocol {
    func execute()
}

open class YiVideoEditor: NSObject {
    var videoData: YiVideoEditorData
    var commands: [Any]
    public private(set) var exportSession: AVAssetExportSession?
    private var timer: Timer?
    public init(videoURL: URL) {
        let asset = AVURLAsset(url: videoURL)
        self.videoData = YiVideoEditorData(asset: asset)
        self.commands = []
        super.init()
    }
    
    public func rotate(rotateDegree: YiVideoEditorRotateDegree) -> Void {
        var commandCount = 0
        switch rotateDegree {
        case .rotateDegree90:
            commandCount = 1
        case .rotateDegree180:
            commandCount = 2
        case .rotateDegree270:
            commandCount = 3
        }
        for _ in 0..<commandCount {
            let command = YiRotateCommand(videoData: videoData)
            commands.append(command)
        }
    }
    
    public func crop(cropFrame: CGRect) {
        let command = YiCropCommand(videoData: videoData, cropFrame: cropFrame)
        commands.append(command)
    }
    
    public func addLayer(layer: CALayer) {
        let command = YiAddLayerCommand(videoData: videoData, layer: layer)
        commands.append(command)
    }

    public func addAudio(asset: AVAsset, startingAt: CGFloat, trackDuration: CGFloat) {
        let command = YiAddAudioCommand(videoData: videoData, audioAsset: asset, startingAt: startingAt, trackDuration: trackDuration)
        commands.append(command)
    }
    
    public func addAudio(asset: AVAsset, startingAt: CGFloat) {
        let command = YiAddAudioCommand(videoData: videoData, audioAsset: asset, startingAt: startingAt, trackDuration: nil)
        commands.append(command)
    }

    public func addAudio(asset: AVAsset) {
        let command = YiAddAudioCommand(videoData: videoData, audioAsset: asset, startingAt: nil, trackDuration: nil)
        commands.append(command)
    }

    func applyCommands() {
        var addLayerCommand: YiAddLayerCommand?
        for item in commands {
            if let command = item as? YiAddLayerCommand {
                addLayerCommand = command
                continue
            }
            if let command = item as? YiVideoEditorCommandProtocol {
                command.execute()
            }
        }
        addLayerCommand?.execute()
    }
    
    public func export(exportURL: URL,
                presetName: String = AVAssetExportPresetHighestQuality,
                optimizeForNetworkUse: Bool = true,
                outputFileType: AVFileType = .mov,
                progressCallback: @escaping ((Float)->Void),
                completionCallback: @escaping (AVAssetExportSession)->Void) {
        applyCommands()
        if let videoDataComposition = videoData.composition?.copy() as? AVAsset {
            exportSession = AVAssetExportSession(asset: videoDataComposition, presetName: presetName)
        }
        if let videoComposition = videoData.videoComposition {
            exportSession?.videoComposition = videoComposition
        }
        if FileManager.default.isDeletableFile(atPath: exportURL.path) {
            do {
                try FileManager.default.removeItem(atPath: exportURL.path)
            } catch {
            }
        }
        exportSession?.outputFileType = outputFileType
        exportSession?.outputURL = exportURL
        exportSession?.shouldOptimizeForNetworkUse = optimizeForNetworkUse
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] (time) in
            guard let self else {return}
            if let progress = exportSession?.progress {
                progressCallback(progress)
                if progress >= 1 {
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
        }
        exportSession?.exportAsynchronously {
            DispatchQueue.main.async {
                let asset = AVURLAsset(url: exportURL)
                self.videoData = YiVideoEditorData(asset: asset)
                self.commands = []
                if let exportSession = self.exportSession {
                    completionCallback(exportSession)
                }
                self.timer?.invalidate()
                self.timer = nil
            }
        }
    }
}
