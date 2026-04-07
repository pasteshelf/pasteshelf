//
//  ContentTypeTests.swift
//  PasteShelfTests
//
//  Tests for ContentType enum functionality.
//

import Foundation
@testable import PasteShelf
import Testing
import UniformTypeIdentifiers

struct ContentTypeTests {
    // MARK: - Priority Tests

    @Test("Rich text has highest priority")
    func richTextHasHighestPriority() {
        #expect(ContentType.richText.priority == 1)
    }

    @Test("Priority order is correct")
    func priorityOrderIsCorrect() {
        let types = ContentType.allCases.sorted { $0.priority < $1.priority }

        #expect(types[0] == .richText)
        #expect(types[1] == .html)
        #expect(types[2] == .plainText)
    }

    @Test("Text types have higher priority than images")
    func textTypesHaveHigherPriorityThanImages() {
        #expect(ContentType.plainText.priority < ContentType.png.priority)
        #expect(ContentType.html.priority < ContentType.jpeg.priority)
    }

    // MARK: - Icon Tests

    @Test("Each content type has an icon")
    func eachTypeHasIcon() {
        for type in ContentType.allCases {
            #expect(!type.icon.isEmpty)
        }
    }

    @Test("Image types share same icon")
    func imageTypesShareIcon() {
        #expect(ContentType.png.icon == ContentType.jpeg.icon)
        #expect(ContentType.jpeg.icon == ContentType.tiff.icon)
    }

    // MARK: - Display Name Tests

    @Test("Display names are human readable")
    func displayNamesAreHumanReadable() {
        #expect(ContentType.plainText.displayName == "Plain Text")
        #expect(ContentType.richText.displayName == "Rich Text")
        #expect(ContentType.png.displayName == "PNG Image")
    }

    // MARK: - Category Tests

    @Test("Text types are correctly categorized")
    func textTypesAreCorrectlyCategorized() {
        #expect(ContentType.plainText.isTextType)
        #expect(ContentType.richText.isTextType)
        #expect(ContentType.html.isTextType)
        #expect(!ContentType.png.isTextType)
    }

    @Test("Image types are correctly categorized")
    func imageTypesAreCorrectlyCategorized() {
        #expect(ContentType.png.isImageType)
        #expect(ContentType.jpeg.isImageType)
        #expect(ContentType.tiff.isImageType)
        #expect(!ContentType.plainText.isImageType)
    }

    @Test("Reference types are correctly categorized")
    func referenceTypesAreCorrectlyCategorized() {
        #expect(ContentType.url.isReferenceType)
        #expect(ContentType.fileURL.isReferenceType)
        #expect(!ContentType.plainText.isReferenceType)
    }

    // MARK: - UTType Conversion Tests

    @Test("UTType conversion works")
    func utTypeConversionWorks() {
        #expect(ContentType.plainText.utType == .plainText)
        #expect(ContentType.png.utType == .png)
        #expect(ContentType.pdf.utType == .pdf)
    }

    @Test("From UTType conversion works")
    func fromUtTypeConversionWorks() {
        #expect(ContentType.from(utType: .plainText) == .plainText)
        #expect(ContentType.from(utType: .png) == .png)
        #expect(ContentType.from(utType: .pdf) == .pdf)
    }

    @Test("From UTI string works")
    func fromUtiStringWorks() {
        #expect(ContentType.from(uti: "public.utf8-plain-text") == .plainText)
        #expect(ContentType.from(uti: "public.png") == .png)
        #expect(ContentType.from(uti: "invalid.type") == nil)
    }

    // MARK: - Raw Value Tests

    @Test("Raw values match UTI strings")
    func rawValuesMatchUtiStrings() {
        #expect(ContentType.plainText.rawValue == "public.utf8-plain-text")
        #expect(ContentType.png.rawValue == "public.png")
        #expect(ContentType.pdf.rawValue == "com.adobe.pdf")
    }
}
