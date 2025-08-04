import Foundation
import TachikomaCore

// MARK: - Modern PeekabooTools Implementation

/// Modern Peekaboo automation toolkit using the @ToolKit result builder pattern
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct PeekabooTools: ToolKit {
    public var tools: [Tool<PeekabooTools>] {
        [
            self.screenshotTool,
            self.clickTool,
            self.typeTool,
            self.getWindowsTool,
            self.shellTool,
            self.menuClickTool,
            self.dialogInputTool,
            self.focusWindowTool,
            self.scrollTool,
            self.hotkeyTool,
            self.swipeTool,
            self.sleepTool,
            self.appControlTool,
            self.windowManagementTool,
            self.dockTool,
            self.spaceTool,
        ]
    }

    public init() {}

    // MARK: - Tool Definitions

    private var screenshotTool: Tool<PeekabooTools> {
        createTool(
            name: "screenshot",
            description: "Take a screenshot of the screen or a specific application window"
        ) { input, context in
            let app = input.stringValue("app", default: nil)
            let path = input.stringValue("path", default: nil)
            let format = input.stringValue("format", default: "png")
            let windowTitle = input.stringValue("window_title", default: nil)
            let windowIndex = input.intValue("window_index", default: nil)
            let captureFocus = input.stringValue("capture_focus", default: "auto")

            return try await context.takeScreenshot(
                app: app,
                path: path,
                format: format,
                windowTitle: windowTitle,
                windowIndex: windowIndex,
                captureFocus: captureFocus
            )
        }
    }

    private var clickTool: Tool<PeekabooTools> {
        createTool(
            name: "click",
            description: "Click on a UI element by description, coordinates, or element ID"
        ) { input, context in
            let element = try input.stringValue("element")
            let coords = input.stringValue("coords", default: nil)
            let double = input.boolValue("double", default: false)
            let right = input.boolValue("right", default: false)
            let waitFor = input.intValue("wait_for", default: 5000)

            return try await context.clickElement(
                element: element,
                coords: coords,
                double: double,
                right: right,
                waitFor: waitFor
            )
        }
    }

    private var typeTool: Tool<PeekabooTools> {
        createTool(
            name: "type",
            description: "Type text into the currently focused input field or a specific element"
        ) { input, context in
            let text = try input.stringValue("text")
            let element = input.stringValue("element", default: nil)
            let clear = input.boolValue("clear", default: false)
            let pressReturn = input.boolValue("press_return", default: false)
            let delay = input.intValue("delay", default: 5)

            return try await context.typeText(
                text: text,
                element: element,
                clear: clear,
                pressReturn: pressReturn,
                delay: delay
            )
        }
    }

    private var getWindowsTool: Tool<PeekabooTools> {
        createTool(
            name: "get_windows",
            description: "List windows for a specific application or all applications"
        ) { input, context in
            let app = input.stringValue("app", default: nil)
            let includeDetails = input.boolValue("include_details", default: false)
            let onlyVisible = input.boolValue("only_visible", default: true)

            return try await context.getWindows(
                app: app,
                includeDetails: includeDetails,
                onlyVisible: onlyVisible
            )
        }
    }

    private var shellTool: Tool<PeekabooTools> {
        createTool(
            name: "shell",
            description: "Execute a shell command and return the output"
        ) { input, context in
            let command = try input.stringValue("command")
            let timeout = input.intValue("timeout", default: 30)
            let workingDirectory = input.stringValue("working_directory", default: nil)

            return try await context.executeShellCommand(
                command: command,
                timeout: timeout,
                workingDirectory: workingDirectory
            )
        }
    }

    private var menuClickTool: Tool<PeekabooTools> {
        createTool(
            name: "menu_click",
            description: "Click on a menu item in the application menu bar"
        ) { input, context in
            let app = try input.stringValue("app")
            let path = input.stringValue("path", default: nil)
            let item = input.stringValue("item", default: nil)

            return try await context.clickMenuItem(
                app: app,
                path: path,
                item: item
            )
        }
    }

    private var dialogInputTool: Tool<PeekabooTools> {
        createTool(
            name: "dialog_input",
            description: "Interact with system dialogs, alerts, and file choosers"
        ) { input, context in
            let action = try input.stringValue("action")
            let button = input.stringValue("button", default: nil)
            let text = input.stringValue("text", default: nil)
            let field = input.stringValue("field", default: nil)
            let path = input.stringValue("path", default: nil)
            let force = input.boolValue("force", default: false)

            return try await context.interactWithDialog(
                action: action,
                button: button,
                text: text,
                field: field,
                path: path,
                force: force
            )
        }
    }

    private var focusWindowTool: Tool<PeekabooTools> {
        createTool(
            name: "focus_window",
            description: "Bring a specific application window to the foreground"
        ) { input, context in
            let app = try input.stringValue("app")
            let windowTitle = input.stringValue("window_title", default: nil)
            let windowIndex = input.intValue("window_index", default: nil)
            let bringToCurrentSpace = input.boolValue("bring_to_current_space", default: true)

            return try await context.focusWindow(
                app: app,
                windowTitle: windowTitle,
                windowIndex: windowIndex,
                bringToCurrentSpace: bringToCurrentSpace
            )
        }
    }

    private var scrollTool: Tool<PeekabooTools> {
        createTool(
            name: "scroll",
            description: "Scroll in a specific direction within a window or element"
        ) { input, context in
            let direction = try input.stringValue("direction")
            let amount = input.intValue("amount", default: 3)
            let element = input.stringValue("element", default: nil)
            let smooth = input.boolValue("smooth", default: false)
            let delay = input.intValue("delay", default: 2)

            return try await context.scroll(
                direction: direction,
                amount: amount,
                element: element,
                smooth: smooth,
                delay: delay
            )
        }
    }

    private var hotkeyTool: Tool<PeekabooTools> {
        createTool(
            name: "hotkey",
            description: "Press keyboard shortcuts and key combinations"
        ) { input, context in
            let keys = try input.stringValue("keys")
            let holdDuration = input.intValue("hold_duration", default: 50)

            return try await context.pressHotkey(
                keys: keys,
                holdDuration: holdDuration
            )
        }
    }

    private var swipeTool: Tool<PeekabooTools> {
        createTool(
            name: "swipe",
            description: "Perform swipe/drag gestures between two points"
        ) { input, context in
            let from = try input.stringValue("from")
            let to = try input.stringValue("to")
            let duration = input.intValue("duration", default: 500)
            let steps = input.intValue("steps", default: 10)

            return try await context.performSwipe(
                from: from,
                to: to,
                duration: duration,
                steps: steps
            )
        }
    }

    private var sleepTool: Tool<PeekabooTools> {
        createTool(
            name: "sleep",
            description: "Pause execution for a specified duration"
        ) { input, context in
            let duration = try input.intValue("duration")
            return try await context.sleep(duration: duration)
        }
    }

    private var appControlTool: Tool<PeekabooTools> {
        createTool(
            name: "app_control",
            description: "Launch, quit, focus, hide, or manage applications"
        ) { input, context in
            let action = try input.stringValue("action")
            let app = try input.stringValue("app")
            let force = input.boolValue("force", default: false)
            let wait = input.intValue("wait", default: 2)
            let waitUntilReady = input.boolValue("wait_until_ready", default: false)

            return try await context.controlApplication(
                action: action,
                app: app,
                force: force,
                wait: wait,
                waitUntilReady: waitUntilReady
            )
        }
    }

    private var windowManagementTool: Tool<PeekabooTools> {
        createTool(
            name: "window_management",
            description: "Close, minimize, maximize, move, or resize windows"
        ) { input, context in
            let action = try input.stringValue("action")
            let app = try input.stringValue("app")
            let windowTitle = input.stringValue("window_title", default: nil)
            let windowIndex = input.intValue("window_index", default: nil)
            let x = input.intValue("x", default: nil)
            let y = input.intValue("y", default: nil)
            let width = input.intValue("width", default: nil)
            let height = input.intValue("height", default: nil)

            return try await context.manageWindow(
                action: action,
                app: app,
                windowTitle: windowTitle,
                windowIndex: windowIndex,
                x: x, y: y,
                width: width, height: height
            )
        }
    }

    private var dockTool: Tool<PeekabooTools> {
        createTool(
            name: "dock",
            description: "Interact with the macOS Dock"
        ) { input, context in
            let action = try input.stringValue("action")
            let app = input.stringValue("app", default: nil)
            let select = input.stringValue("select", default: nil)

            return try await context.interactWithDock(
                action: action,
                app: app,
                select: select
            )
        }
    }

    private var spaceTool: Tool<PeekabooTools> {
        createTool(
            name: "space",
            description: "Manage macOS Spaces (virtual desktops)"
        ) { input, context in
            let action = try input.stringValue("action")
            let spaceNumber = input.intValue("space_number", default: nil)
            let app = input.stringValue("app", default: nil)
            let follow = input.boolValue("follow", default: false)

            return try await context.manageSpace(
                action: action,
                spaceNumber: spaceNumber,
                app: app,
                follow: follow
            )
        }
    }
}

// MARK: - Tool Implementation Methods

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension PeekabooTools {
    func takeScreenshot(
        app: String?,
        path: String?,
        format: String?,
        windowTitle: String?,
        windowIndex: Int?,
        captureFocus: String?
    ) async throws
    -> String {
        // This would integrate with the actual PeekabooCore services
        // For now, return a placeholder
        let appText = app.map { " of \($0)" } ?? ""
        let pathText = path.map { " saved to \($0)" } ?? " saved to temporary location"
        return "Screenshot taken\(appText)\(pathText)"
    }

    func clickElement(
        element: String,
        coords: String?,
        double: Bool,
        right: Bool,
        waitFor: Int
    ) async throws
    -> String {
        let clickType = double ? "Double-clicked" : (right ? "Right-clicked" : "Clicked")
        let coordsText = coords.map { " at \($0)" } ?? ""
        return "\(clickType) on '\(element)'\(coordsText)"
    }

    func typeText(
        text: String,
        element: String?,
        clear: Bool,
        pressReturn: Bool,
        delay: Int
    ) async throws
    -> String {
        let elementText = element.map { " in '\($0)'" } ?? ""
        let clearText = clear ? " (cleared first)" : ""
        let returnText = pressReturn ? " and pressed Return" : ""
        return "Typed '\(text)'\(elementText)\(clearText)\(returnText)"
    }

    func getWindows(
        app: String?,
        includeDetails: Bool,
        onlyVisible: Bool
    ) async throws
    -> String {
        let appText = app.map { " for \($0)" } ?? " for all applications"
        return "Listed windows\(appText)"
    }

    func executeShellCommand(
        command: String,
        timeout: Int,
        workingDirectory: String?
    ) async throws
    -> String {
        "Executed shell command: \(command)"
    }

    func clickMenuItem(
        app: String,
        path: String?,
        item: String?
    ) async throws
    -> String {
        if let path {
            return "Clicked menu item '\(path)' in \(app)"
        } else if let item {
            return "Clicked menu item '\(item)' in \(app)"
        } else {
            throw ToolError.invalidInput("Either 'path' or 'item' must be provided")
        }
    }

    func interactWithDialog(
        action: String,
        button: String?,
        text: String?,
        field: String?,
        path: String?,
        force: Bool
    ) async throws
    -> String {
        switch action {
        case "click":
            guard let button else {
                throw ToolError.invalidInput("Button name required for click action")
            }
            return "Clicked '\(button)' button in dialog"
        case "input":
            guard let text else {
                throw ToolError.invalidInput("Text required for input action")
            }
            let fieldText = field.map { " in '\($0)' field" } ?? ""
            return "Entered '\(text)'\(fieldText)"
        case "file":
            guard let path else {
                throw ToolError.invalidInput("File path required for file action")
            }
            return "Selected file: \(path)"
        case "dismiss":
            let forceText = force ? " (forced)" : ""
            return "Dismissed dialog\(forceText)"
        default:
            throw ToolError.invalidInput("Unknown dialog action: \(action)")
        }
    }

    func focusWindow(
        app: String,
        windowTitle: String?,
        windowIndex: Int?,
        bringToCurrentSpace: Bool
    ) async throws
    -> String {
        let windowText = windowTitle.map { " '\($0)'" } ??
            windowIndex.map { " (index \($0))" } ?? ""
        return "Focused \(app) window\(windowText)"
    }

    func scroll(
        direction: String,
        amount: Int,
        element: String?,
        smooth: Bool,
        delay: Int
    ) async throws
    -> String {
        let elementText = element.map { " in '\($0)'" } ?? ""
        let smoothText = smooth ? " smoothly" : ""
        return "Scrolled \(direction)\(smoothText) \(amount) times\(elementText)"
    }

    func pressHotkey(
        keys: String,
        holdDuration: Int
    ) async throws
    -> String {
        "Pressed hotkey: \(keys)"
    }

    func performSwipe(
        from: String,
        to: String,
        duration: Int,
        steps: Int
    ) async throws
    -> String {
        "Swiped from \(from) to \(to) over \(duration)ms"
    }

    func sleep(duration: Int) async throws -> String {
        try await Task.sleep(nanoseconds: UInt64(duration) * 1_000_000)
        return "Slept for \(duration)ms"
    }

    func controlApplication(
        action: String,
        app: String,
        force: Bool,
        wait: Int,
        waitUntilReady: Bool
    ) async throws
    -> String {
        let forceText = force ? " (forced)" : ""
        return "\(action.capitalized) \(app)\(forceText)"
    }

    func manageWindow(
        action: String,
        app: String,
        windowTitle: String?,
        windowIndex: Int?,
        x: Int?, y: Int?,
        width: Int?, height: Int?
    ) async throws
    -> String {
        let windowText = windowTitle.map { " '\($0)'" } ??
            windowIndex.map { " (index \($0))" } ?? ""

        switch action {
        case "move":
            guard let x, let y else {
                throw ToolError.invalidInput("X and Y coordinates required for move action")
            }
            return "Moved \(app) window\(windowText) to (\(x), \(y))"
        case "resize":
            guard let width, let height else {
                throw ToolError.invalidInput("Width and height required for resize action")
            }
            return "Resized \(app) window\(windowText) to \(width)x\(height)"
        default:
            return "\(action.capitalized) \(app) window\(windowText)"
        }
    }

    func interactWithDock(
        action: String,
        app: String?,
        select: String?
    ) async throws
    -> String {
        switch action {
        case "launch":
            guard let app else {
                throw ToolError.invalidInput("App name required for launch action")
            }
            return "Launched \(app) from Dock"
        case "right_click":
            guard let app else {
                throw ToolError.invalidInput("App name required for right-click action")
            }
            let selectText = select.map { " and selected '\($0)'" } ?? ""
            return "Right-clicked \(app) in Dock\(selectText)"
        case "list":
            return "Listed Dock applications"
        case "hide":
            return "Hid Dock"
        case "show":
            return "Showed Dock"
        default:
            throw ToolError.invalidInput("Unknown dock action: \(action)")
        }
    }

    func manageSpace(
        action: String,
        spaceNumber: Int?,
        app: String?,
        follow: Bool
    ) async throws
    -> String {
        switch action {
        case "list":
            return "Listed available Spaces"
        case "switch":
            guard let spaceNumber else {
                throw ToolError.invalidInput("Space number required for switch action")
            }
            return "Switched to Space \(spaceNumber)"
        case "move_window":
            guard let app, let spaceNumber else {
                throw ToolError.invalidInput("App name and space number required for move_window action")
            }
            let followText = follow ? " and followed" : ""
            return "Moved \(app) window to Space \(spaceNumber)\(followText)"
        default:
            throw ToolError.invalidInput("Unknown space action: \(action)")
        }
    }
}
