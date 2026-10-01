import Cocoa
import Vision

struct DetectedText: Codable {
    let text: String
    let confidence: Float
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let centerX: Double
    let centerY: Double
}

struct WindowInfo: Codable {
    let windowId: UInt32
    let ownerName: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct VisionResult: Codable {
    let window: WindowInfo?
    let scale: Double
    let texts: [DetectedText]
    let captureType: String
}

func getBestWindow(owner: String) -> (id: CGWindowID, bounds: CGRect)? {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements)
    guard let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
    var candidates: [(id: CGWindowID, bounds: CGRect, onScreen: Bool, area: CGFloat)] = []
    
    for info in windowListInfo {
        guard let name = info[kCGWindowOwnerName as String] as? String,
              name.localizedCaseInsensitiveContains(owner),
              let id = info[kCGWindowNumber as String] as? CGWindowID,
              let boundsDict = info[kCGWindowBounds as String] as? [CFString: Any] else { continue }
        
        let onScreen = info[kCGWindowIsOnscreen as String] as? Bool ?? false
        var rect = CGRect.zero
        if CGRectMakeWithDictionaryRepresentation(boundsDict as CFDictionary, &rect),
           rect.width >= 300 && rect.height >= 200 {
            candidates.append((id: id, bounds: rect, onScreen: onScreen, area: rect.width * rect.height))
        }
    }
    
    // Sort: onscreen true first, then largest window area
    candidates.sort { (a, b) -> Bool in
        if a.onScreen != b.onScreen {
            return a.onScreen && !b.onScreen
        }
        return a.area > b.area
    }
    
    if let best = candidates.first {
        return (best.id, best.bounds)
    }
    return nil
}

func performOCR(imagePath: String, winBounds: CGRect, isWindowCapture: Bool, queryText: String) -> (scale: Double, texts: [DetectedText]) {
    guard let image = NSImage(contentsOfFile: imagePath),
          let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let cgImage = bitmap.cgImage else {
        return (1.0, [])
    }

    let imgWidth = Double(cgImage.width)
    let imgHeight = Double(cgImage.height)
    let screenW = NSScreen.main?.frame.width ?? 1470.0
    let scale = (isWindowCapture && winBounds.width > 0) ? (imgWidth / winBounds.width) : (imgWidth / screenW)

    var detectedTexts: [DetectedText] = []

    let request = VNRecognizeTextRequest { request, _ in
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
        for obs in observations {
            guard let candidate = obs.topCandidates(1).first else { continue }
            let bbox = obs.boundingBox
            // Normalized (0,0 bottom-left) to macOS screen points (0,0 top-left)
            let pixelX = bbox.origin.x * imgWidth
            let pixelY = (1.0 - bbox.origin.y - bbox.size.height) * imgHeight
            let pixelW = bbox.size.width * imgWidth
            let pixelH = bbox.size.height * imgHeight

            let screenX = (isWindowCapture ? winBounds.origin.x : 0.0) + (pixelX / scale)
            let screenY = (isWindowCapture ? winBounds.origin.y : 0.0) + (pixelY / scale)
            let screenW = pixelW / scale
            let screenH = pixelH / scale

            let textStr = candidate.string
            if queryText.isEmpty || textStr.lowercased().contains(queryText) {
                detectedTexts.append(DetectedText(
                    text: textStr,
                    confidence: candidate.confidence,
                    x: screenX,
                    y: screenY,
                    width: screenW,
                    height: screenH,
                    centerX: screenX + (screenW / 2.0),
                    centerY: screenY + (screenH / 2.0)
                ))
            }
        }
    }
    request.recognitionLevel = .fast
    request.usesLanguageCorrection = false

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try? handler.perform([request])
    return (scale, detectedTexts)
}

let args = CommandLine.arguments
let owner = args.count > 1 ? args[1] : "WhatsApp"
let queryText = args.count > 2 ? args[2].lowercased() : ""

var winBounds = CGRect.zero
var winId: CGWindowID = 0
var windowInfo: WindowInfo? = nil

let forceFullScreen = owner.lowercased() == "screen" || owner.lowercased() == "fullscreen" || owner.isEmpty

if !forceFullScreen, let win = getBestWindow(owner: owner) {
    winId = win.id
    winBounds = win.bounds
    windowInfo = WindowInfo(
        windowId: UInt32(winId),
        ownerName: owner,
        x: winBounds.origin.x,
        y: winBounds.origin.y,
        width: winBounds.width,
        height: winBounds.height
    )
}

let tmpPath = "/tmp/lofly_vision_temp_\(ProcessInfo.processInfo.processIdentifier).png"
defer {
    try? FileManager.default.removeItem(atPath: tmpPath)
}

var usedCaptureType = "screen"
var ocrScale = 2.0
var finalTexts: [DetectedText] = []

// Try window capture first if window was found
if winId > 0 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    p.arguments = ["-o", "-x", "-l", "\(winId)", tmpPath]
    try? p.run()
    p.waitUntilExit()
    
    if let attr = try? FileManager.default.attributesOfItem(atPath: tmpPath),
       let size = attr[.size] as? Int, size > 15000 {
        let (scale, texts) = performOCR(imagePath: tmpPath, winBounds: winBounds, isWindowCapture: true, queryText: queryText)
        if !texts.isEmpty {
            usedCaptureType = "window"
            ocrScale = scale
            finalTexts = texts
        }
    }
}

// Fallback to full-screen capture if window capture yielded no text or was skipped
if finalTexts.isEmpty {
    try? FileManager.default.removeItem(atPath: tmpPath)
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    p.arguments = ["-x", tmpPath]
    try? p.run()
    p.waitUntilExit()

    let (scale, texts) = performOCR(imagePath: tmpPath, winBounds: .zero, isWindowCapture: false, queryText: queryText)
    usedCaptureType = "screen"
    ocrScale = scale
    finalTexts = texts
}

let result = VisionResult(window: windowInfo, scale: ocrScale, texts: finalTexts, captureType: usedCaptureType)
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
if let data = try? encoder.encode(result), let str = String(data: data, encoding: .utf8) {
    print(str)
}
