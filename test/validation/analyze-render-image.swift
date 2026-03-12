/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

import CoreGraphics
import Foundation
import ImageIO

enum RenderAnalysisError: Error {
	case imageLoadFailed(String)
	case contextCreateFailed(String)
	case sizeMismatch((Int, Int), (Int, Int))
}

struct ImageData {
	let path: String
	let width: Int
	let height: Int
	let pixels: [UInt8]
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
	let brightPixels: Int
	let averageLuma: Double
	let maxLuma: Int
}

struct RegionDiff {
	let diffPixels: Int
	let maxChannelDelta: Int
}

let regions = [
	Region(name: "top_bar_expected", x: 0.18, y: 0.00, width: 0.64, height: 0.10),
	Region(name: "minimap_expected_bottom_left", x: 0.00, y: 0.74, width: 0.24, height: 0.26),
	Region(name: "minimap_suspicious_mid_left", x: 0.00, y: 0.35, width: 0.24, height: 0.26),
	Region(name: "lower_left_hud_expected", x: 0.00, y: 0.68, width: 0.33, height: 0.32),
	Region(name: "world_center", x: 0.25, y: 0.18, width: 0.50, height: 0.50),
]

func loadRGBA(_ path: String) throws -> ImageData {
	let url = URL(fileURLWithPath: path)

	guard
		let source = CGImageSourceCreateWithURL(url as CFURL, nil),
		let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
	else {
		throw RenderAnalysisError.imageLoadFailed(path)
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
		throw RenderAnalysisError.contextCreateFailed(path)
	}

	context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
	return ImageData(path: path, width: width, height: height, pixels: pixels)
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

func analyzeRegion(_ image: ImageData, region: Region) -> RegionStats {
	let bounds = clampRegion(region, width: image.width, height: image.height)
	var pixelCount = 0
	var nonBlackPixels = 0
	var brightPixels = 0
	var lumaSum = 0
	var maxLuma = 0

	for y in bounds.y0..<bounds.y1 {
		for x in bounds.x0..<bounds.x1 {
			let offset = (y * image.width + x) * 4
			let r = image.pixels[offset]
			let g = image.pixels[offset + 1]
			let b = image.pixels[offset + 2]
			let currentLuma = luma(r: r, g: g, b: b)

			pixelCount += 1
			lumaSum += currentLuma
			maxLuma = max(maxLuma, currentLuma)

			if (Int(r) + Int(g) + Int(b)) > 24 {
				nonBlackPixels += 1
			}

			if currentLuma >= 96 {
				brightPixels += 1
			}
		}
	}

	let averageLuma = (pixelCount > 0) ? (Double(lumaSum) / Double(pixelCount)) : 0.0
	return RegionStats(
		pixelCount: pixelCount,
		nonBlackPixels: nonBlackPixels,
		brightPixels: brightPixels,
		averageLuma: averageLuma,
		maxLuma: maxLuma
	)
}

func diffRegion(reference: ImageData, captured: ImageData, region: Region) -> RegionDiff {
	let bounds = clampRegion(region, width: reference.width, height: reference.height)
	var diffPixels = 0
	var maxChannelDelta = 0

	for y in bounds.y0..<bounds.y1 {
		for x in bounds.x0..<bounds.x1 {
			let offset = (y * reference.width + x) * 4
			var pixelDiffers = false

			for channel in 0..<4 {
				let lhs = reference.pixels[offset + channel]
				let rhs = captured.pixels[offset + channel]
				let delta = abs(Int(lhs) - Int(rhs))

				if delta != 0 {
					pixelDiffers = true
					maxChannelDelta = max(maxChannelDelta, delta)
				}
			}

			if pixelDiffers {
				diffPixels += 1
			}
		}
	}

	return RegionDiff(diffPixels: diffPixels, maxChannelDelta: maxChannelDelta)
}

func formatPercent(_ value: Double) -> String {
	return String(format: "%.2f%%", value * 100.0)
}

func printAnalysisWarnings(_ statsByName: [String: RegionStats]) {
	guard
		let topBar = statsByName["top_bar_expected"],
		let bottomLeftMinimap = statsByName["minimap_expected_bottom_left"],
		let midLeftMinimap = statsByName["minimap_suspicious_mid_left"],
		let lowerLeftHud = statsByName["lower_left_hud_expected"],
		let worldCenter = statsByName["world_center"]
	else {
		return
	}

	let bottomLeftMinimapRatio = Double(bottomLeftMinimap.nonBlackPixels) / Double(max(bottomLeftMinimap.pixelCount, 1))
	let midLeftMinimapRatio = Double(midLeftMinimap.nonBlackPixels) / Double(max(midLeftMinimap.pixelCount, 1))
	let lowerLeftHudRatio = Double(lowerLeftHud.nonBlackPixels) / Double(max(lowerLeftHud.pixelCount, 1))
	let worldCenterRatio = Double(worldCenter.nonBlackPixels) / Double(max(worldCenter.pixelCount, 1))

	if topBar.averageLuma < 70.0 {
		print("warning: expected top-bar region is relatively dark")
	}

	if bottomLeftMinimap.averageLuma < 50.0 {
		print("warning: expected bottom-left minimap region is relatively dark")
	}

	if midLeftMinimap.averageLuma > (bottomLeftMinimap.averageLuma + 4.0) || midLeftMinimapRatio > (bottomLeftMinimapRatio + 0.12) {
		print("warning: suspicious mid-left content is stronger than the expected bottom-left minimap region")
	}

	if lowerLeftHud.averageLuma < 45.0 || lowerLeftHudRatio < 0.10 {
		print("warning: expected lower-left HUD region is relatively dark")
	}

	if worldCenter.averageLuma < 40.0 || worldCenterRatio < 0.20 {
		print("warning: world-center region is relatively dark")
	}
}

guard (2...3).contains(CommandLine.arguments.count) else {
	fputs("Usage: analyze-render-image.swift /path/to/captured.png [/path/to/reference.png]\n", stderr)
	exit(1)
}

let capturedPath = CommandLine.arguments[1]
let referencePath = (CommandLine.arguments.count == 3) ? CommandLine.arguments[2] : nil

do {
	let captured = try loadRGBA(capturedPath)
	let reference = try referencePath.map(loadRGBA)

	if let reference, reference.width != captured.width || reference.height != captured.height {
		throw RenderAnalysisError.sizeMismatch((reference.width, reference.height), (captured.width, captured.height))
	}

	print("Captured image: \(captured.path)")
	print("Image size: \(captured.width)x\(captured.height)")
	if let reference {
		print("Reference image: \(reference.path)")
	}

	var statsByName = [String: RegionStats]()

	for region in regions {
		let stats = analyzeRegion(captured, region: region)
		statsByName[region.name] = stats

		let nonBlackRatio = Double(stats.nonBlackPixels) / Double(max(stats.pixelCount, 1))
		let brightRatio = Double(stats.brightPixels) / Double(max(stats.pixelCount, 1))

		print("region \(region.name): nonBlack=\(formatPercent(nonBlackRatio)) bright=\(formatPercent(brightRatio)) avgLuma=\(String(format: "%.2f", stats.averageLuma)) maxLuma=\(stats.maxLuma)")

		if let reference {
			let diff = diffRegion(reference: reference, captured: captured, region: region)
			let diffRatio = Double(diff.diffPixels) / Double(max(stats.pixelCount, 1))
			print("region \(region.name) diff: pixels=\(diff.diffPixels) ratio=\(formatPercent(diffRatio)) maxChannelDelta=\(diff.maxChannelDelta)")
		}
	}

	printAnalysisWarnings(statsByName)
} catch RenderAnalysisError.imageLoadFailed(let path) {
	fputs("Failed to load image for render analysis: \(path)\n", stderr)
	exit(1)
} catch RenderAnalysisError.contextCreateFailed(let path) {
	fputs("Failed to create RGBA bitmap context for render analysis: \(path)\n", stderr)
	exit(1)
} catch RenderAnalysisError.sizeMismatch(let refSize, let capSize) {
	fputs("Render image sizes differ: reference=\(refSize.0)x\(refSize.1) captured=\(capSize.0)x\(capSize.1)\n", stderr)
	exit(1)
} catch {
	fputs("Unexpected render analysis failure: \(error)\n", stderr)
	exit(1)
}
