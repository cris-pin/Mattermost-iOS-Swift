//
//  Constants.swift
//  Mattermost
//
//  Created by Maxim Gubin on 29/06/16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

import Foundation

struct Constants {
    struct Api {
        static let Route = "api/v3"
    }
    struct Http {
        struct Headers {
            static let ContentType = "Content-Type"
            static let RequestedWith = "X-Requested-With"
            static let AcceptLanguage = "Accept-Language"
            static let Cookie = "Cookie"
        }
    }
    struct Common {
        static let RestKitPrefix = "RK"
        static let MattermostCookieName = "MMAUTHTOKEN"
        static let UserDefaultsPreferencesKey = "com.kilograpp.mattermost.preferences"
    }
    struct Socket {
        static let TimeIntervalBetweenNotifications: Double = 5.0
    }
    
    struct UI {
        static let FeedCellMessageLabelPaddings = 61 as CGFloat
    }
}