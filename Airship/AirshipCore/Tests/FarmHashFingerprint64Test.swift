
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

    private let crossPlatformCases: [String: UInt64] = [
           "0376d8dc-a717-425a-9dd2-d4b36bcaddac:65d52a5d-4f88-4a78-97c9-08464d44bbb6": 14340110469024474010,
           "62087079-4f3b-4350-88a9-67667493a48f:a9689ef1-ef7f-45e7-8841-ba0f6cdc6b4d": 3536341280875387670,
           "3d50751d-360f-4c37-a818-0e2d7b83a795:962a1b84-8ecc-44d7-95ff-3ec60215075a": 6852554232698863320,
           "9ecfe0bf-b24b-422f-83e2-e8de9c336493:27abe283-5937-43f0-a4f2-c8ee71f682e8": 16343172889285518932,
           "601cfb3b-b69f-4b88-b52d-e1fc201df11c:29d407e8-bbc9-4b48-b789-e5af84b22810": 18171507073648632955,
           "67b9dcdf-4d8d-42ed-a000-bf90c3b47fa8:e90c7986-0231-4c80-a10d-fc60bdf05ebc": 6180626819026048726,
           "9431edf5-a862-405e-82bd-0f64283304e9:478f73b9-f324-42f6-9d8f-bb0445f11247": 5342572022420056632,
           "5c24c242-4b81-496d-9d56-31f320d20a26:8155f96f-f3b1-4bcd-8a54-378150ea3d03": 5403761470481847248,
           "976bddc7-7b5c-48fa-a285-a10dc2d64009:6a4ed766-017e-4b19-9cb2-0299e97a995b": 404533724234009115,
           "cede4631-b57a-447d-b94b-4c31a71e1f3c:f46f1e00-1e78-4c01-8a89-989106182ecd": 2662685979233479610,
           "dd464de7-2f57-4787-a14b-35bd57dd515d:2da0af42-35b0-423e-99ed-bc5cb5dd7099": 5656984155782857542,
           "3f1d41bc-ac7e-49e2-8f88-30744f0fff4e:8561c5d7-cbb1-4b67-afd0-669e369420b6": 3506311998853318899,
           "c65ef2ae-44b0-4c5e-b37e-57b4fda7ee8e:d4933f58-d257-41ff-b0fa-11aa524d642e": 14192866033732275238,
           "d19964d4-59e3-49d6-8d61-4dfa97e794f7:6cbc589e-3695-4cc6-afe7-4bcdcea01480": 8310185173796126101,
           "813c09f5-a0ae-410d-99c6-7bf7e87b2738:c5d50a64-bacf-4887-b3ac-e53d8cdc555b": 15599208209427113891,
           "a1db3c20-673e-48e4-9967-b49834b6fac6:a3bc58d1-f389-4113-97d1-28d3bf12cbe5": 1700656031758233133,
           "5b431ab8-975e-4207-8550-62da7665a01b:095c1b48-131e-477c-90d4-17894acc1246": 7441422609642864761,
           "92f4a2ca-46d5-4e15-87c5-f7b33497286c:7811c125-2348-47a6-84e6-9343bb12a0f7": 592674394864765514,
           "cbb0399d-a803-4a27-91a0-7732b308278e:f61a366a-7c20-45eb-b40a-bed0b012607c": 492797389607996305,
           "2c333e41-e702-4096-a71f-8c3df488a990:9c1d45d9-439c-490e-99cc-f159ce7010e7": 764412364649713065,
           "optic_acquit:eef25358-6577-4b84-bbcd-82c0f2de80e2": 2791352902118037828,
           "warthog_punts:bbe20d0c-143d-4d1a-8973-182b7d10c7bb": 7332285015592839891,
           "vanilla_hither:70d7d1ce-09da-468c-9864-d0188f70c1fe": 8273296097385490599,
           "crepe_frumps:bbe484c8-af06-4477-863e-35cfdb284f71": 8795467158546487560,
           "clinic_scouts:ec85318f-dd20-4cde-bc81-69bb1e21b12b": 6650034920187666365,
           "trying_gapped:d72565c0-2d7e-4e37-a309-ad47c9c14da9": 4989233212801864762,
           "snuffly_pithy:84811fbf-badd-405a-8564-7f354190943f": 15791669038156053022,
           "graters_fields:37281aec-3848-4ef2-ac7d-e926618865f7": 9056534536604691350,
           "mirrors_dangs:ddb42326-49f6-40e5-b428-b966f6ab4887": 4084541845741700082,
           "expend_raying:b3054772-ed90-4a79-8866-4a8753f93d2d": 11334098313106439423,
           "peewees_autobus:5de6faf8-e039-4b2c-ba37-ccdd0401758e": 1590885424516612823,
           "giant_boozy:9ceecbc5-0372-4a5c-b12f-4a6d696dece9": 3196424533567189237,
           "glazers_zagging:74e3f557-3064-4d99-8809-f6b4c897a710": 18418949167652646364,
           "paces_acuate:4c08c06d-7ddc-4773-8fcb-4833c5a03b36": 13404925037839805568,
           "makes_coiner:108af86f-b273-463c-96ee-9b4c948e92ac": 13939548535417169537,
           "patinas_posted:e8ff9cd9-e335-4b6c-93ff-51aba68951c9": 15877907202098665149,
           "further_agents:4fb082f2-2db8-4cf0-b367-b22ee0e590e1": 16609400165765915699,
           "hubbubs_parked:b97ff960-af53-42a2-b5fe-9b8e248012f9": 1116732196685121691,
           "deeply_outworn:ef48d2be-76ef-465d-a993-b92cf8f958ac": 16625481623000662505,
           "girded_heave:30aebf7f-8a0c-4b89-adbc-b010b0619f94": 4262921022933957472,
       ]

    func testKnownOutputs() throws {
        self.testData.forEach { (key: String, value: UInt64) in
            XCTAssertEqual(value, key.farmHashFingerprint64)
        }
    }

    func testCrossPlatformCases() throws {
        self.crossPlatformCases.forEach { (key: String, value: UInt64) in
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
