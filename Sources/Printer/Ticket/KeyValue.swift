//
//  KeyValue.swift
//  
//
//  Created by Tuan Nguyen Anh on 10/28/22.
//

import Foundation

public struct KeyValue: BlockDataProvider {

  let key: Text
  let space: Text
  let value: Text

  public init(key: Text, value: Text) {
    self.key = key
    self.value = value

    let printDensity: Int = 384
    let fontDensity: Int = 12
    var num = printDensity / fontDensity

    let k = key.content
    let v = value.content
    let string = k + v

    for c in string {
      if (c >= "\u{2E80}" && c <= "\u{FE4F}") || c == "\u{FFE5}"{
        num -= 2
      } else  {
        num -= 1
      }
    }

    let contentsOfSpace = stride(from: 0, to: num, by: 1).map { _ in " " }
    self.space = Text(contentsOfSpace.joined())
  }

  public func data(using encoding: String.Encoding) -> Data {
    var result = Data()

    [key, space, value].enumerated().forEach { (offset, text) in
      if let attrs = text.attributes {
        result.append(Data(attrs.flatMap { $0.attribute }))
      }

      if let cd = text.content.data(using: encoding) {
        result.append(cd)
      }

      if offset == 0 {
        result.append(Data(ESC_POSCommand.emphasize(mode: false).rawValue))
      }
    }

    return result
  }
}
