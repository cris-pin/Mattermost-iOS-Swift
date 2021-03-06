//
//  ActionsNotification.swift
//  Mattermost
//
//  Created by Maxim Gubin on 26/07/16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

import Foundation

final class ActionsNotification {
    let userIdentifier: String
    let event: Event?
    
    init(userIdentifier: String!, event: Event?) {
        self.userIdentifier = userIdentifier
        self.event = event
    }
    
    static func notificationNameForChannelIdentifier(_ channelIdentifier: String!) -> String! {
        return "channel.notifications.\(channelIdentifier)"
    }
}
