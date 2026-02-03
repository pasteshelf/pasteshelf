//
//  ClipboardContentData+CoreDataClass.swift
//  PasteShelf
//
//  Entity for storing binary clipboard content data.
//  Separated from ClipboardItem to optimize memory usage and CloudKit sync.
//

import CoreData
import Foundation

@objc(ClipboardContentData)
public class ClipboardContentData: NSManagedObject {}
