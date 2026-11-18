import XCTest
@testable import CAT2RIGCore

final class CIVCodecTests: XCTestCase {

    func testFreqToBCDKnownValues() {
        XCTAssertEqual(CIV.freqToBCD(14_074_000), [0x00, 0x40, 0x07, 0x14, 0x00])
        // ramka z prawdziwego IC-706MKIIG (log z 23:41:37): 144.174.000 Hz
        XCTAssertEqual(CIV.freqToBCD(144_174_000), [0x00, 0x40, 0x17, 0x44, 0x01])
        XCTAssertEqual(CIV.freqToBCD(1_234_567_890), [0x90, 0x78, 0x56, 0x34, 0x12])
        XCTAssertEqual(CIV.freqToBCD(0), [0, 0, 0, 0, 0])
    }

    func testBCDToFreqKnownValues() {
        XCTAssertEqual(CIV.bcdToFreq([0x00, 0x40, 0x17, 0x44, 0x01]), 144_174_000)
        XCTAssertEqual(CIV.bcdToFreq([0x00, 0x50, 0x37, 0x44, 0x01]), 144_375_000)
        // starsze radia wysyłają 4 bajty
        XCTAssertEqual(CIV.bcdToFreq([0x00, 0x40, 0x07, 0x07]), 7_074_000)
    }

    func testInvalidBCDIsRejected() {
        XCTAssertNil(CIV.bcdToFreq([0xFF, 0xFF, 0xFF, 0xFF, 0xFF]))          // nie-cyfry
        XCTAssertNil(CIV.bcdToFreq([0x00, 0x4A, 0x07, 0x14, 0x00]))          // nibble A
        XCTAssertNil(CIV.bcdToFreq([0x00, 0x40, 0x07]))                      // za krótko
        // dwie sklejone ramki (10 bajtów) – tak wyglądały dane, które wywracały program
        XCTAssertNil(CIV.bcdToFreq([0x00, 0x40, 0x07, 0x14, 0x00, 0xFE, 0xFE, 0x00, 0x58, 0x00]))
        XCTAssertNil(CIV.bcdToFreq([]))
    }

    func testRoundTrip() {
        let freqs = [30_000, 1_840_000, 3_573_000, 7_074_000, 10_136_000, 14_074_000,
                     28_074_000, 50_313_000, 144_174_000, 145_500_000, 432_100_000, 470_000_000]
        for f in freqs {
            XCTAssertEqual(CIV.bcdToFreq(CIV.freqToBCD(f)), f, "dla \(f) Hz")
        }
    }

    func testModeTables() {
        XCTAssertEqual(CIV.modes[0x01], "USB")
        XCTAssertEqual(CIV.modes[0x05], "FM")
        XCTAssertEqual(CIV.hamlibToCiv["PKTUSB"], 0x01)
        XCTAssertEqual(CIV.hamlibToCiv["PKTLSB"], 0x00)
        XCTAssertEqual(CIV.hamlibToCiv["CWR"], 0x03)
        // każda emisja z tabeli radia ma odwzorowanie w drugą stronę i szerokość filtra
        for (code, name) in CIV.modes {
            XCTAssertEqual(CIV.hamlibToCiv[name], code)
            XCTAssertNotNil(CIV.normalWidth[name])
            XCTAssertNotNil(CIV.narrowWidth[name])
        }
    }
}
