import AppKit
import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum MediaToolError: Error, CustomStringConvertible {
    case invalidArguments
    case invalidVideo
    case imageDestination
    case export(String)

    var description: String {
        switch self {
        case .invalidArguments:
            "Usage: swift scripts/make_landing_media.swift <source.mov> <output-directory>"
        case .invalidVideo:
            "The source recording does not contain a readable video track."
        case .imageDestination:
            "Could not create the animated GIF destination."
        case .export(let message):
            "Could not export the accelerated demo: \(message)"
        }
    }
}

func sourceSecond(for outputSecond: Double, sourceDuration: Double) -> Double {
    let introSourceEnd = min(6, sourceDuration * 0.12)
    let outroSourceStart = max(introSourceEnd, sourceDuration - 7)
    let introOutputEnd = 2.5
    let middleOutputEnd = 9.5
    let outputDuration = 12.0

    if outputSecond <= introOutputEnd {
        return (outputSecond / introOutputEnd) * introSourceEnd
    }
    if outputSecond <= middleOutputEnd {
        let progress = (outputSecond - introOutputEnd) / (middleOutputEnd - introOutputEnd)
        return introSourceEnd + progress * (outroSourceStart - introSourceEnd)
    }
    let progress = (outputSecond - middleOutputEnd) / (outputDuration - middleOutputEnd)
    return outroSourceStart + progress * (sourceDuration - outroSourceStart)
}

func makeGenerator(asset: AVAsset, maximumWidth: CGFloat) -> AVAssetImageGenerator {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = CMTime(seconds: 0.18, preferredTimescale: 600)
    generator.requestedTimeToleranceAfter = CMTime(seconds: 0.18, preferredTimescale: 600)
    generator.maximumSize = CGSize(width: maximumWidth, height: maximumWidth)
    return generator
}

func makeAnimatedGIF(asset: AVAsset, sourceDuration: Double, outputURL: URL) throws {
    let framesPerSecond = 4.0
    let outputDuration = 12.0
    let frameCount = Int(outputDuration * framesPerSecond)
    let frameDelay = 1.0 / framesPerSecond
    let generator = makeGenerator(asset: asset, maximumWidth: 640)

    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.gif.identifier as CFString,
        frameCount,
        nil
    ) else {
        throw MediaToolError.imageDestination
    }

    let containerProperties = [
        kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
    ] as CFDictionary
    CGImageDestinationSetProperties(destination, containerProperties)

    let frameProperties = [
        kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frameDelay]
    ] as CFDictionary

    for index in 0..<frameCount {
        let outputSecond = Double(index) / framesPerSecond
        let inputSecond = sourceSecond(for: outputSecond, sourceDuration: sourceDuration)
        var actualTime = CMTime.zero
        let image = try generator.copyCGImage(
            at: CMTime(seconds: inputSecond, preferredTimescale: 600),
            actualTime: &actualTime
        )
        CGImageDestinationAddImage(destination, image, frameProperties)
    }

    guard CGImageDestinationFinalize(destination) else {
        throw MediaToolError.imageDestination
    }
}

func makeContactSheet(asset: AVAsset, sourceDuration: Double, outputURL: URL) throws {
    let columns = 3
    let rows = 4
    let cellWidth = 360
    let imageHeight = 211
    let labelHeight = 30
    let canvasWidth = columns * cellWidth
    let canvasHeight = rows * (imageHeight + labelHeight)
    let generator = makeGenerator(asset: asset, maximumWidth: CGFloat(cellWidth))

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: canvasWidth,
        pixelsHigh: canvasHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: canvasWidth * 4,
        bitsPerPixel: 32
    ) else {
        throw MediaToolError.invalidVideo
    }

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        NSGraphicsContext.restoreGraphicsState()
        throw MediaToolError.invalidVideo
    }
    NSGraphicsContext.current = context
    NSColor(calibratedRed: 0.025, green: 0.055, blue: 0.05, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight).fill()

    let labelStyle: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.36, green: 0.91, blue: 0.67, alpha: 1)
    ]

    let times = (0..<(columns * rows)).map { index in
        sourceDuration * Double(index) / Double(columns * rows - 1)
    }

    for (index, second) in times.enumerated() {
        let column = index % columns
        let row = rows - 1 - (index / columns)
        let x = column * cellWidth
        let y = row * (imageHeight + labelHeight)
        var actualTime = CMTime.zero
        let cgImage = try generator.copyCGImage(
            at: CMTime(seconds: second, preferredTimescale: 600),
            actualTime: &actualTime
        )
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cellWidth, height: imageHeight))
        image.draw(
            in: NSRect(x: x, y: y + labelHeight, width: cellWidth, height: imageHeight),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        String(format: "%05.1fs", second).draw(
            at: NSPoint(x: x + 10, y: y + 7),
            withAttributes: labelStyle
        )
    }

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw MediaToolError.invalidVideo
    }
    try png.write(to: outputURL, options: .atomic)
}

func makeAcceleratedMP4(asset: AVAsset, sourceDuration: Double, outputURL: URL) throws {
    let composition = AVMutableComposition()
    let fullRange = CMTimeRange(
        start: .zero,
        duration: CMTime(seconds: sourceDuration, preferredTimescale: 600)
    )
    try composition.insertTimeRange(fullRange, of: asset, at: .zero)

    let introEnd = min(6, sourceDuration * 0.12)
    let outroStart = max(introEnd, sourceDuration - 7)
    let middleRange = CMTimeRange(
        start: CMTime(seconds: introEnd, preferredTimescale: 600),
        duration: CMTime(seconds: outroStart - introEnd, preferredTimescale: 600)
    )
    composition.scaleTimeRange(
        middleRange,
        toDuration: CMTime(seconds: 7, preferredTimescale: 600)
    )

    guard let exporter = AVAssetExportSession(
        asset: composition,
        presetName: AVAssetExportPreset1280x720
    ) else {
        throw MediaToolError.export("AVAssetExportSession is unavailable")
    }
    exporter.outputURL = outputURL
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true

    let semaphore = DispatchSemaphore(value: 0)
    exporter.exportAsynchronously {
        semaphore.signal()
    }
    semaphore.wait()

    guard exporter.status == .completed else {
        throw MediaToolError.export(exporter.error?.localizedDescription ?? "status \(exporter.status.rawValue)")
    }
}

do {
    guard CommandLine.arguments.count == 3 else {
        throw MediaToolError.invalidArguments
    }

    let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    let asset = AVURLAsset(url: sourceURL)
    let sourceDuration = CMTimeGetSeconds(asset.duration)
    guard sourceDuration.isFinite,
          sourceDuration > 1,
          !asset.tracks(withMediaType: .video).isEmpty else {
        throw MediaToolError.invalidVideo
    }

    let gifURL = outputDirectory.appendingPathComponent("scan-demo.gif")
    let videoURL = outputDirectory.appendingPathComponent("scan-demo.mp4")
    let contactSheetURL = outputDirectory.appendingPathComponent("scan-contact-sheet.png")
    for url in [gifURL, videoURL, contactSheetURL] where FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
    }

    try makeContactSheet(asset: asset, sourceDuration: sourceDuration, outputURL: contactSheetURL)
    try makeAnimatedGIF(asset: asset, sourceDuration: sourceDuration, outputURL: gifURL)
    try makeAcceleratedMP4(asset: asset, sourceDuration: sourceDuration, outputURL: videoURL)

    print(String(format: "Created a 12s GIF and accelerated MP4 from %.1fs of source footage.", sourceDuration))
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
