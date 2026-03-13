import AppKit
import Foundation

let screenCount = NSScreen.screens.count

if CommandLine.arguments.dropFirst().contains("--count-only") {
	print(screenCount)
	exit(screenCount > 0 ? EXIT_SUCCESS : EXIT_FAILURE)
}

if screenCount > 0 {
	print("macOS GUI session detected (\(screenCount) screen(s))")
	exit(EXIT_SUCCESS)
}

fputs("No Aqua-attached screens are visible from this process.\n", stderr)
exit(EXIT_FAILURE)
