/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

import CoreGraphics
import Foundation
import ImageIO

enum FrameSelectError: Error {
	case imageLoadFailed(String)
	case contextCreateFailed(String)
	case invalidEnvironmentValue(String, String)
}

struct Region {
	let name: String
	let x: Double
	let y: Double
	let width: Double
	let height: Double
}

struct RegionStats {
	let pixelCount: Int
	let nonBlackPixels: Int
	let averageLuma: Double
}

struct FrameSummary {
	let path: String
	let width: Int
	let height: Int
	let nonBlackPixels: Int
	let maxChannelValue: Int
	let statsByName: [String: RegionStats]
	let heuristicScore: Double

	var totalPixels: Int {
		width * height
	}
}

let selectionRegions = [
	Region(name: "top_bar_expected", x: 0.18, y: 0.00, width: 0.64, height: 0.10),
	Region(name: "minimap_expected_bottom_left", x: 0.00, y: 0.74, width: 0.24, height: 0.26),
	Region(name: "minimap_suspicious_mid_left", x: 0.00, y: 0.35, width: 0.24, height: 0.26),
	Region(name: "lower_left_hud_expected", x: 0.00, y: 0.68, width: 0.33, height: 0.32),
	Region(name: "world_center", x: 0.25, y: 0.18, width: 0.50, height: 0.50),
]

func loadRGBA(_ path: String) throws -> (pixels: [UInt8], width: Int, height: Int) {
	let url = URL(fileURLWithPath: path)

	guard
		let source = CGImageSourceCreateWithURL(url as CFURL, nil),
		let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
	else {
		throw FrameSelectError.imageLoadFailed(path)
	}

	let width = image.width
	let height = image.height
	let bytesPerPixel = 4
	let bytesPerRow = width * bytesPerPixel
	var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

	let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
	guard let context = CGContext(
		data: &pixels,
		width: width,
		height: height,
		bitsPerComponent: 8,
		bytesPerRow: bytesPerRow,
		space: CGColorSpaceCreateDeviceRGB(),
		bitmapInfo: bitmapInfo
	) else {
		throw FrameSelectError.contextCreateFailed(path)
	}

	context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
	return (pixels, width, height)
}

func clampRegion(_ region: Region, width: Int, height: Int) -> (x0: Int, y0: Int, x1: Int, y1: Int) {
	let x0 = max(0, min(width - 1, Int(Double(width) * region.x)))
	let y0 = max(0, min(height - 1, Int(Double(height) * region.y)))
	let x1 = max(x0 + 1, min(width, Int(Double(width) * (region.x + region.width))))
	let y1 = max(y0 + 1, min(height, Int(Double(height) * (region.y + region.height))))
	return (x0, y0, x1, y1)
}

func luma(r: UInt8, g: UInt8, b: UInt8) -> Int {
	return (2126 * Int(r) + 7152 * Int(g) + 722 * Int(b)) / 10000
}

func analyzeRegion(pixels: [UInt8], width: Int, height: Int, region: Region) -> RegionStats {
	let bounds = clampRegion(region, width: width, height: height)
	var pixelCount = 0
	var nonBlackPixels = 0
	var lumaSum = 0

	for y in bounds.y0..<bounds.y1 {
		for x in bounds.x0..<bounds.x1 {
			let pixelOffset = (y * width + x) * 4
			let red = pixels[pixelOffset]
			let green = pixels[pixelOffset + 1]
			let blue = pixels[pixelOffset + 2]
			let currentLuma = luma(r: red, g: green, b: blue)

			pixelCount += 1
			lumaSum += currentLuma

			if (Int(red) + Int(green) + Int(blue)) > 24 {
				nonBlackPixels += 1
			}
		}
	}

	let averageLuma = (pixelCount > 0) ? (Double(lumaSum) / Double(pixelCount)) : 0.0
	return RegionStats(
		pixelCount: pixelCount,
		nonBlackPixels: nonBlackPixels,
		averageLuma: averageLuma
	)
}

func ratio(_ numerator: Int, _ denominator: Int) -> Double {
	guard denominator > 0 else {
		return 0.0
	}

	return Double(numerator) / Double(denominator)
}

func cappedScore(_ value: Double, target: Double, weight: Double) -> Double {
	guard target > 0.0 else {
		return 0.0
	}

	return min(1.0, max(0.0, value / target)) * weight
}

func scoreFrame(width: Int, height: Int, nonBlackPixels: Int, statsByName: [String: RegionStats]) -> Double {
	guard
		let topBar = statsByName["top_bar_expected"],
		let bottomLeftMinimap = statsByName["minimap_expected_bottom_left"],
		let midLeftMinimap = statsByName["minimap_suspicious_mid_left"],
		let lowerLeftHud = statsByName["lower_left_hud_expected"],
		let worldCenter = statsByName["world_center"]
	else {
		return 0.0
	}

	let totalNonBlackRatio = ratio(nonBlackPixels, width * height)
	let topBarNonBlackRatio = ratio(topBar.nonBlackPixels, topBar.pixelCount)
	let bottomLeftMinimapRatio = ratio(bottomLeftMinimap.nonBlackPixels, bottomLeftMinimap.pixelCount)
	let midLeftMinimapRatio = ratio(midLeftMinimap.nonBlackPixels, midLeftMinimap.pixelCount)
	let lowerLeftHudRatio = ratio(lowerLeftHud.nonBlackPixels, lowerLeftHud.pixelCount)
	let worldCenterRatio = ratio(worldCenter.nonBlackPixels, worldCenter.pixelCount)

	var score = 0.0
	score += cappedScore(totalNonBlackRatio, target: 0.08, weight: 10.0)
	score += cappedScore(topBar.averageLuma, target: 80.0, weight: 18.0)
	score += cappedScore(topBarNonBlackRatio, target: 0.20, weight: 14.0)
	score += cappedScore(bottomLeftMinimap.averageLuma, target: 65.0, weight: 16.0)
	score += cappedScore(bottomLeftMinimapRatio, target: 0.18, weight: 14.0)
	score += cappedScore(lowerLeftHudRatio, target: 0.18, weight: 10.0)
	score += cappedScore(lowerLeftHud.averageLuma, target: 55.0, weight: 8.0)
	score += cappedScore(worldCenterRatio, target: 0.25, weight: 18.0)
	score += cappedScore(worldCenter.averageLuma, target: 55.0, weight: 10.0)

	if topBar.averageLuma < 35.0 {
		score -= 6.0
	}

	if bottomLeftMinimap.averageLuma < 28.0 {
		score -= 6.0
	}

	if worldCenter.averageLuma < 24.0 || worldCenterRatio < 0.08 {
		score -= 6.0
	}

	if midLeftMinimap.averageLuma > (bottomLeftMinimap.averageLuma + 4.0) || midLeftMinimapRatio > (bottomLeftMinimapRatio + 0.12) {
		score -= 18.0
	}

	return score
}

func summarizeFrame(_ path: String) throws -> FrameSummary {
	let imageData = try loadRGBA(path)
	let pixels = imageData.pixels
	var nonBlackPixels = 0
	var maxChannelValue = 0

	for pixelOffset in stride(from: 0, to: pixels.count, by: 4) {
		let red = Int(pixels[pixelOffset])
		let green = Int(pixels[pixelOffset + 1])
		let blue = Int(pixels[pixelOffset + 2])
		let channelMax = max(red, max(green, blue))

		if channelMax > maxChannelValue {
			maxChannelValue = channelMax
		}

		if channelMax != 0 {
			nonBlackPixels += 1
		}
	}

	var statsByName = [String: RegionStats]()
	for region in selectionRegions {
		statsByName[region.name] = analyzeRegion(
			pixels: pixels,
			width: imageData.width,
			height: imageData.height,
			region: region
		)
	}

	let heuristicScore = scoreFrame(
		width: imageData.width,
		height: imageData.height,
		nonBlackPixels: nonBlackPixels,
		statsByName: statsByName
	)

	return FrameSummary(
		path: path,
		width: imageData.width,
		height: imageData.height,
		nonBlackPixels: nonBlackPixels,
		maxChannelValue: maxChannelValue,
		statsByName: statsByName,
		heuristicScore: heuristicScore
	)
}

func stderrPrint(_ line: String) {
	fputs("\(line)\n", stderr)
}

func formatDouble(_ value: Double) -> String {
	String(format: "%.2f", value)
}

func nearlyEqual(_ lhs: Double, _ rhs: Double, tolerance: Double = 0.001) -> Bool {
	abs(lhs - rhs) <= tolerance
}

func envInt(_ name: String, defaultValue: Int) throws -> Int {
	guard let rawValue = ProcessInfo.processInfo.environment[name], !rawValue.isEmpty else {
		return defaultValue
	}

	guard let parsed = Int(rawValue), parsed >= 0 else {
		throw FrameSelectError.invalidEnvironmentValue(name, rawValue)
	}

	return parsed
}

guard CommandLine.arguments.count >= 2 else {
	fputs("Usage: select-first-nonblack-render-frame.swift /path/to/frame1.png [/path/to/frame2.png ...]\n", stderr)
	exit(1)
}

do {
	let minNonBlackPixels = try envInt(
		"RECOIL_RENDER_FRAME_SELECTION_MIN_NONBLACK_PIXELS",
		defaultValue: 1
	)
	let verboseDiagnostics = try envInt(
		"RECOIL_RENDER_FRAME_SELECTION_VERBOSE",
		defaultValue: 0
	) != 0

	var bestFrameSummary: FrameSummary?

	for candidatePath in CommandLine.arguments.dropFirst() {
		let frameSummary = try summarizeFrame(candidatePath)
		let isUsable = frameSummary.nonBlackPixels >= minNonBlackPixels
		let topBar = frameSummary.statsByName["top_bar_expected"]
		let bottomLeftMinimap = frameSummary.statsByName["minimap_expected_bottom_left"]
		let worldCenter = frameSummary.statsByName["world_center"]

		if verboseDiagnostics {
			stderrPrint(
				"frame-select: path=\(frameSummary.path) " +
				"nonBlackPixels=\(frameSummary.nonBlackPixels)/\(frameSummary.totalPixels) " +
				"maxChannel=\(frameSummary.maxChannelValue) " +
				"score=\(formatDouble(frameSummary.heuristicScore)) " +
				"topBarLuma=\(formatDouble(topBar?.averageLuma ?? 0.0)) " +
				"minimapLuma=\(formatDouble(bottomLeftMinimap?.averageLuma ?? 0.0)) " +
				"worldLuma=\(formatDouble(worldCenter?.averageLuma ?? 0.0)) " +
				"usable=\(isUsable ? "yes" : "no")"
			)
		}

		guard isUsable else {
			continue
		}

		guard let currentBest = bestFrameSummary else {
			bestFrameSummary = frameSummary
			continue
		}

		if frameSummary.heuristicScore > (currentBest.heuristicScore + 0.001) {
			bestFrameSummary = frameSummary
			continue
		}

		if nearlyEqual(frameSummary.heuristicScore, currentBest.heuristicScore) {
			if frameSummary.nonBlackPixels > currentBest.nonBlackPixels {
				bestFrameSummary = frameSummary
				continue
			}

			if frameSummary.nonBlackPixels == currentBest.nonBlackPixels && frameSummary.maxChannelValue > currentBest.maxChannelValue {
				bestFrameSummary = frameSummary
			}
		}
	}

	if let selectedFrameSummary = bestFrameSummary {
		stderrPrint(
			"frame-select: selected \(selectedFrameSummary.path) " +
			"nonBlackPixels=\(selectedFrameSummary.nonBlackPixels)/\(selectedFrameSummary.totalPixels) " +
			"maxChannel=\(selectedFrameSummary.maxChannelValue) " +
			"score=\(formatDouble(selectedFrameSummary.heuristicScore))"
		)
		print(selectedFrameSummary.path)
		exit(0)
	}

	stderrPrint(
		"No usable render frame found. " +
		"minNonBlackPixels=\(minNonBlackPixels)"
	)
	exit(1)
} catch FrameSelectError.imageLoadFailed(let path) {
	fputs("Failed to load render frame: \(path)\n", stderr)
	exit(1)
} catch FrameSelectError.contextCreateFailed(let path) {
	fputs("Failed to create RGBA bitmap context for render frame: \(path)\n", stderr)
	exit(1)
} catch FrameSelectError.invalidEnvironmentValue(let name, let rawValue) {
	fputs("Invalid integer environment value for \(name): \(rawValue)\n", stderr)
	exit(1)
} catch {
	fputs("Unexpected render-frame selection failure: \(error)\n", stderr)
	exit(1)
}
