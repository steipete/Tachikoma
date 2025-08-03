import Foundation
import TachikomaCore

// MARK: - Modern PeekabooTools Implementation

/// Modern Peekaboo automation toolkit using the @ToolKit result builder pattern
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct PeekabooTools: ToolKit {
    public var tools: [Tool<PeekabooTools>] {
        [
            screenshotTool,
            clickTool,
            typeTool,
            getWindowsTool,
            shellTool,
            menuClickTool,
            dialogInputTool,
            focusWindowTool,
            scrollTool,
            hotkeyTool,
            swipeTool,
            sleepTool,
            appControlTool,
            windowManagementTool,
            dockTool,
            spaceTool
        ]
    }
    
    public init() {}
    
    // MARK: - Tool Definitions
    
    private var screenshotTool: Tool<PeekabooTools> {
        tool(
            name: "screenshot",
            description: "Take a screenshot of the screen or a specific application window",
            parameters: .object(
                properties: [
                    "app": .string(description: "Optional application name to capture (e.g., 'Safari', 'TextEdit')"),
                    "path": .string(description: "Optional file path to save the screenshot"),
                    "format": .enumeration(["png", "jpg", "data"], description: "Image format (default: png)"),
                    "window_title": .string(description: "Optional specific window title to capture"),
                    "window_index": .integer(description: "Optional window index for multi-window apps"),
                    "capture_focus": .enumeration(["auto", "background", "foreground"], description: "Focus behavior during capture")
                ]
            )
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
        tool(
            name: "click",
            description: "Click on a UI element by description, coordinates, or element ID",
            parameters: .object(
                properties: [
                    "element": .string(description: "Description of element to click (e.g., 'Submit button', 'Save As menu item')"),
                    "coords": .string(description: "Optional coordinates in format 'x,y' (e.g., '100,200')"),
                    "double": .boolean(description: "Whether to double-click instead of single click"),
                    "right": .boolean(description: "Whether to right-click instead of left-click"),
                    "wait_for": .integer(description: "Maximum milliseconds to wait for element to become actionable")
                ],
                required: ["element"]
            )
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
        tool(
            name: "type",
            description: "Type text into the currently focused input field or a specific element",
            parameters: .object(
                properties: [
                    "text": .string(description: "Text to type"),
                    "element": .string(description: "Optional element to type into"),
                    "clear": .boolean(description: "Whether to clear the field before typing"),
                    "press_return": .boolean(description: "Whether to press Enter after typing"),
                    "delay": .integer(description: "Delay between keystrokes in milliseconds")
                ],
                required: ["text"]
            )
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
        tool(
            name: "get_windows",
            description: "List windows for a specific application or all applications",
            parameters: .object(
                properties: [
                    "app": .string(description: "Optional application name to list windows for"),
                    "include_details": .boolean(description: "Whether to include detailed window information"),
                    "only_visible": .boolean(description: "Whether to only include visible windows")
                ]
            )
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
        tool(
            name: "shell",
            description: "Execute a shell command and return the output",
            parameters: .object(
                properties: [
                    "command": .string(description: "Shell command to execute"),
                    "timeout": .integer(description: "Timeout in seconds (default: 30)"),
                    "working_directory": .string(description: "Optional working directory for the command")
                ],
                required: ["command"]
            )
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
        tool(
            name: "menu_click",
            description: "Click on a menu item in the application menu bar",
            parameters: .object(
                properties: [
                    "app": .string(description: "Application name (e.g., 'Safari', 'TextEdit')"),
                    "path": .string(description: "Menu path with '>' separator (e.g., 'File > Save As...')"),
                    "item": .string(description: "Simple menu item name for non-nested items")
                ],
                required: ["app"]
            )
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
        tool(
            name: "dialog_input",
            description: "Interact with system dialogs, alerts, and file choosers",
            parameters: .object(
                properties: [
                    "action": .enumeration(["click", "input", "file", "dismiss"], description: "Action to perform"),
                    "button": .string(description: "Button text to click (e.g., 'Save', 'Cancel', 'OK')"),
                    "text": .string(description: "Text to input in dialog fields"),
                    "field": .string(description: "Field name or placeholder text"),
                    "path": .string(description: "File path for file selection dialogs"),
                    "force": .boolean(description: "Force dismiss dialog if normal methods fail")
                ],
                required: ["action"]
            )
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
        tool(
            name: "focus_window",
            description: "Bring a specific application window to the foreground",
            parameters: .object(
                properties: [
                    "app": .string(description: "Application name"),
                    "window_title": .string(description: "Optional specific window title"),
                    "window_index": .integer(description: "Optional window index for multi-window apps"),
                    "bring_to_current_space": .boolean(description: "Whether to bring window to current desktop space")
                ],
                required: ["app"]
            )
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
        tool(
            name: "scroll",
            description: "Scroll in a specific direction within a window or element",
            parameters: .object(
                properties: [
                    "direction": .enumeration(["up", "down", "left", "right"], description: "Scroll direction"),
                    "amount": .integer(description: "Number of scroll ticks/lines (default: 3)"),
                    "element": .string(description: "Optional element to scroll within"),
                    "smooth": .boolean(description: "Whether to use smooth scrolling"),
                    "delay": .integer(description: "Delay between scroll ticks in milliseconds")
                ],
                required: ["direction"]
            )
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
        tool(
            name: "hotkey",
            description: "Press keyboard shortcuts and key combinations",
            parameters: .object(
                properties: [
                    "keys": .string(description: "Comma-separated keys (e.g., 'cmd,c' for copy, 'cmd,shift,t' for new tab)"),
                    "hold_duration": .integer(description: "Duration to hold keys in milliseconds")
                ],
                required: ["keys"]
            )
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
        tool(
            name: "swipe",
            description: "Perform swipe/drag gestures between two points",
            parameters: .object(
                properties: [
                    "from": .string(description: "Starting coordinates in format 'x,y'"),
                    "to": .string(description: "Ending coordinates in format 'x,y'"),
                    "duration": .integer(description: "Duration of swipe in milliseconds"),
                    "steps": .integer(description: "Number of intermediate steps for smooth movement")
                ],
                required: ["from", "to"]
            )
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
        tool(
            name: "sleep",
            description: "Pause execution for a specified duration",
            parameters: .object(
                properties: [
                    "duration": .integer(description: "Sleep duration in milliseconds")
                ],
                required: ["duration"]
            )
        ) { input, context in
            let duration = try input.intValue("duration")
            return try await context.sleep(duration: duration)
        }
    }
    
    private var appControlTool: Tool<PeekabooTools> {
        tool(
            name: "app_control",
            description: "Launch, quit, focus, hide, or manage applications",
            parameters: .object(
                properties: [
                    "action": .enumeration(["launch", "quit", "focus", "hide", "unhide", "relaunch"], description: "Action to perform"),
                    "app": .string(description: "Application name or bundle ID"),
                    "force": .boolean(description: "Force quit if normal quit fails"),
                    "wait": .integer(description: "Wait time in seconds for relaunch"),
                    "wait_until_ready": .boolean(description: "Wait for app to be ready after launch")
                ],
                required: ["action", "app"]
            )
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
        tool(
            name: "window_management",
            description: "Close, minimize, maximize, move, or resize windows",
            parameters: .object(
                properties: [
                    "action": .enumeration(["close", "minimize", "maximize", "move", "resize"], description: "Window action"),
                    "app": .string(description: "Application name"),
                    "window_title": .string(description: "Optional window title"),
                    "window_index": .integer(description: "Optional window index"),
                    "x": .integer(description: "X coordinate for move action"),
                    "y": .integer(description: "Y coordinate for move action"),
                    "width": .integer(description: "Width for resize action"),
                    "height": .integer(description: "Height for resize action")
                ],
                required: ["action", "app"]
            )
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
        tool(
            name: "dock",
            description: "Interact with the macOS Dock",
            parameters: .object(
                properties: [
                    "action": .enumeration(["launch", "right_click", "hide", "show", "list"], description: "Dock action"),
                    "app": .string(description: "Application name for launch/right-click"),
                    "select": .string(description: "Menu item to select after right-click")
                ],
                required: ["action"]
            )
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
        tool(
            name: "space",
            description: "Manage macOS Spaces (virtual desktops)",
            parameters: .object(
                properties: [
                    "action": .enumeration(["list", "switch", "move_window"], description: "Space action"),
                    "space_number": .integer(description: "Space number to switch to or move window to"),
                    "app": .string(description: "Application name for move_window action"),
                    "follow": .boolean(description: "Whether to follow window when moving")
                ],
                required: ["action"]
            )
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
    ) async throws -> String {
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
    ) async throws -> String {
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
    ) async throws -> String {
        let elementText = element.map { " in '\($0)'" } ?? ""
        let clearText = clear ? " (cleared first)" : ""
        let returnText = pressReturn ? " and pressed Return" : ""
        return "Typed '\(text)'\(elementText)\(clearText)\(returnText)"
    }
    
    func getWindows(
        app: String?,
        includeDetails: Bool,
        onlyVisible: Bool
    ) async throws -> String {
        let appText = app.map { " for \($0)" } ?? " for all applications"
        return "Listed windows\(appText)"
    }
    
    func executeShellCommand(
        command: String,
        timeout: Int,
        workingDirectory: String?
    ) async throws -> String {
        return "Executed shell command: \(command)"
    }
    
    func clickMenuItem(
        app: String,
        path: String?,
        item: String?
    ) async throws -> String {
        if let path = path {
            return "Clicked menu item '\(path)' in \(app)"
        } else if let item = item {
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
    ) async throws -> String {
        switch action {
        case "click":
            guard let button = button else {
                throw ToolError.invalidInput("Button name required for click action")
            }
            return "Clicked '\(button)' button in dialog"
        case "input":
            guard let text = text else {
                throw ToolError.invalidInput("Text required for input action")
            }
            let fieldText = field.map { " in '\($0)' field" } ?? ""
            return "Entered '\(text)'\(fieldText)"
        case "file":
            guard let path = path else {
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
    ) async throws -> String {
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
    ) async throws -> String {
        let elementText = element.map { " in '\($0)'" } ?? ""
        let smoothText = smooth ? " smoothly" : ""
        return "Scrolled \(direction)\(smoothText) \(amount) times\(elementText)"
    }
    
    func pressHotkey(
        keys: String,
        holdDuration: Int
    ) async throws -> String {
        return "Pressed hotkey: \(keys)"
    }
    
    func performSwipe(
        from: String,
        to: String,
        duration: Int,
        steps: Int
    ) async throws -> String {
        return "Swiped from \(from) to \(to) over \(duration)ms"
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
    ) async throws -> String {
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
    ) async throws -> String {
        let windowText = windowTitle.map { " '\($0)'" } ?? 
                        windowIndex.map { " (index \($0))" } ?? ""
        
        switch action {
        case "move":
            guard let x = x, let y = y else {
                throw ToolError.invalidInput("X and Y coordinates required for move action")
            }
            return "Moved \(app) window\(windowText) to (\(x), \(y))"
        case "resize":
            guard let width = width, let height = height else {
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
    ) async throws -> String {
        switch action {
        case "launch":
            guard let app = app else {
                throw ToolError.invalidInput("App name required for launch action")
            }
            return "Launched \(app) from Dock"
        case "right_click":
            guard let app = app else {
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
    ) async throws -> String {
        switch action {
        case "list":
            return "Listed available Spaces"
        case "switch":
            guard let spaceNumber = spaceNumber else {
                throw ToolError.invalidInput("Space number required for switch action")
            }
            return "Switched to Space \(spaceNumber)"
        case "move_window":
            guard let app = app, let spaceNumber = spaceNumber else {
                throw ToolError.invalidInput("App name and space number required for move_window action")
            }
            let followText = follow ? " and followed" : ""
            return "Moved \(app) window to Space \(spaceNumber)\(followText)"
        default:
            throw ToolError.invalidInput("Unknown space action: \(action)")
        }
    }
}