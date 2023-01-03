
import XCTest

@testable
import AirshipCore

final class FarmHashFingerprint64Test: XCTestCase {

    private let testData: [String: UInt64] = [
        "dXB@tDQ-v5<H]rq2Pcc*s>nC-[Mdy": 8365906589669344754,
        "!@#$%^&*():=-_][\\|/?.,<> ": 11772040268694734364,
        "&&3gRU?[^&ok:He[|K:": 11792583603419566171,
        "9JqLl0AW7e69Y.&vMHQ5C": 2827089714349584095,
        "F7479877-4690-4A44-AFC9-8FE987EA512F:some_other_id": 6862335115798125349,
        "hg[F|$D&hb$,V4OeXHOa": 11873385450325105043,
        "/dWQW6&i7h$1@": 11452602314494946942,
        "2/?98ns)xbzEVL^:wCS$7l3@_g!zP^<D.-bd6": 9728733090894310797,
        "?c^6BkI#-SLw": 13133570674398037786,
        "wE,gHSvhK Jv=KR#(R |!%vctTJ0fx)": 413905253809041649,
        "5C $WnO2K@:(4#h": 2463546464490189,
        "Ijiq13Mb_Nn]sA^jhM7eZ\\ExAzSJ": 12345582939087509209,
        ")D<l91": 6440615040757739207,
        "mC=6Tz,AYH|&n99(G!6LyG&QfZ=1^:": 10432240328043398052,
        "7.b^/n=oR_w(vLN?c?xN<5t$p8HY2!s:U": 2506644862971557451,
        "t,SRdW>l=?AH4\\JQ!.A)Wh,O4\\8": 4614517891525318442,
        "K6Pjv<>ad": 16506019169567922731,
        "": 11160318154034397263,
        "Q": 13816109650407654260,
        "bF&d$MYIhB.Ac=qC": 17582099205024456557,
        "#cDR^sLO": 328147020574120176,
        "NXooOPwHej5=c_V0(47=-)N!vNdd:$fMs1B": 5510670329273533446,
        "y2=B@rsu:g9bWU": 2493222351070148393,
        "wi=%v]GoIPI6zm[Rrgmq]7J?.|": 8222623341199956836,
        "Sl,xx&O^l@=TQ[QI(TJ^aD*PS3.K]@Mk:e)e": 12943788826636368730,
        "@05Mz\\\\)VhZ\\S&9vVU,egF%sW)IMIGVHE%#I)D|": 134798502762145076,
        "e#p8": 252499459662674074,
        ">EtzDE,xUUZ%!aCvx#vyN(][Q.eRQO2sBZCwFH": 5047171257402399197,
        "ECCD828C-5D7A-4C8B-9A1B-F244747E96C3": 9693850515132481856,
        "D<wQ1DVVpS": 876767294656777789,
        ",=": 1326014594494455617,
        "EsIIjI65<^!j$)V.,!]M]@Q5[$(oyxI_nF": 4212098974972931626,
        "fDVY|(%&aF#3<l>b?1Y Hqt)qY(0%b@VIk#Rlofs": 1687730506231245221,
        "^b2z)XYJ\\95": 3150268469206098298,
        "9>Nleb)=|CR#4=G2&7[HOP": 10511875379468936029,
        "M)(iJ1-nf>5XCc0L?": 9968500208262240300,
        "WW5": 6316074107149058620,
        "ZyzWj:&3hH78.WUCNW4e&Z ": 13218358187761524434,
        "P9|0-Xg": 15614415556471156694,
        "n?(o|a[EX|KN-9./=tCVEmN%?<MXe8F<": 1754206644017466002,
        "&QEO\\": 673322083973757863,
        "T#e:),mqALpU]hrJ%f.*|=&r": 11789374840096016445,
        "xi\\PvQpHpM:$5\\Zh^U": 4169389423472268625,
        "!/tU|0cMaw=/-Yg)m_*4UNvwB": 14890523890635468863
    ]

    func testKnownOutputs() throws {
        self.testData.forEach { (key: String, value: UInt64) in
            XCTAssertEqual(value, key.farmHashFingerprint64)
        }
    }

    /**
     * Based on https://github.com/google/guava/blob/master/guava-tests/test/com/google/common/hash/FarmHashFingerprint64Test.java#L38
     */
    func testReallySimpleFingerprints() throws {
        XCTAssertEqual(
            8581389452482819506,
            "test".farmHashFingerprint64
        )
        XCTAssertEqual(
            UInt64(bitPattern: -4196240717365766262),
            String(repeating: "test", count: 8).farmHashFingerprint64
        )
        XCTAssertEqual(
            3500507768004279527,
            String(repeating: "test", count: 64).farmHashFingerprint64
        )
    }

    /**
     * Based on https://github.com/google/guava/blob/master/guava-tests/test/com/google/common/hash/FarmHashFingerprint64Test.java#L158
     */
    func testMultipleLengths() throws {
        let iterations = 800
        var buf = [UInt8](repeating: 0, count: iterations * 4)
        var bufLen : Int = 0

        var h : UInt64 = 0
        for i in 0..<iterations {

            h ^= FarmHashFingerprint64.fingerprint(buf, i)
            h = remix(h)
            buf[bufLen] = getChar(h)
            bufLen += 1

            h ^= FarmHashFingerprint64.fingerprint(buf, i * i % bufLen)
            h = remix(h)
            buf[bufLen] = getChar(h)
            bufLen += 1

            h ^= FarmHashFingerprint64.fingerprint(buf, i * i * i % bufLen)
            h = remix(h)
            buf[bufLen] = getChar(h)
            bufLen += 1

            h ^= FarmHashFingerprint64.fingerprint(buf, bufLen)
            h = remix(h)
            buf[bufLen] = getChar(h)
            bufLen += 1

            let x0 : Int = Int(buf[bufLen - 1])
            let x1 : Int = Int(buf[bufLen - 2])
            let x2 : Int = Int(buf[bufLen - 3])
            let x3 : Int = Int(buf[bufLen / 2])

            buf[((x0 << 16) + (x1 << 8) + x2) % bufLen] ^= UInt8(x3)
            buf[((x1 << 16) + (x2 << 8) + x3) % bufLen] ^= UInt8(i % 256)
        }
        XCTAssertEqual(0x7a1d67c50ec7e167, h)
    }

    private func remix(_ v: UInt64) -> UInt64 {
        var h = v
        h ^= h >> 41
        h &*= 949921979
        return h
    }

    private func getChar(_ h: UInt64) -> UInt8 {
        return UInt8(0x61/*a*/) + UInt8((h & 0xfffff) % 26)
    }
}
