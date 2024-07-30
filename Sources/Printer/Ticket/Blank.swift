//
//  Blank.swift
//  Ticket
//
//  Created by gix on 2019/7/29.
//  Copyright © 2019 gix. All rights reserved.
//

import Foundation

public struct Blank: BlockDataProvider {
    public func data(using encoding: String.Encoding) -> Data {
        return Data()
    }
}
