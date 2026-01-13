//
//  LastTimeWidgetLiveActivity.swift
//  LastTimeWidget
//
//  Created by Malik Jamal on 1/10/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LastTimeWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LastTimeWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LastTimeWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension LastTimeWidgetAttributes {
    fileprivate static var preview: LastTimeWidgetAttributes {
        LastTimeWidgetAttributes(name: "World")
    }
}

extension LastTimeWidgetAttributes.ContentState {
    fileprivate static var smiley: LastTimeWidgetAttributes.ContentState {
        LastTimeWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LastTimeWidgetAttributes.ContentState {
         LastTimeWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LastTimeWidgetAttributes.preview) {
   LastTimeWidgetLiveActivity()
} contentStates: {
    LastTimeWidgetAttributes.ContentState.smiley
    LastTimeWidgetAttributes.ContentState.starEyes
}
