/* Copyright Airship and Contributors */

import Foundation

/**
 * Implementation of FarmHash Fingerprint64, an open-source fingerprinting algorithm for strings.
 *
 * Based on https://github.com/google/guava/blob/master/guava/src/com/google/common/hash/FarmHashFingerprint64.java
 * 
 */
struct FarmHashFingerprint64 {

    // some fun primes
    private static let k0: UInt64 = 0xc3a5c85c97cb3127
    private static let k1: UInt64 = 0xb492b66fbe98f273
    private static let k2: UInt64 = 0x9ae16a3b2f90404f

    public static func fingerprint(_ value: String) -> UInt64 {
        let bytes: [UInt8] = Array(value.utf8)
        return fingerprint(bytes)
    }

    public static func fingerprint(_ bytes: [UInt8]) -> UInt64 {
        if (bytes.count <= 32) {
            if (bytes.count <= 16) {
                return hashLength0to16(bytes)
            } else {
                return hashLength17to32(bytes)
            }
        } else if (bytes.count <= 64) {
            return hashLength33To64(bytes)
        } else {
            return hashLength65Plus(bytes)
        }
    }

    public static func fingerprint(_ bytes: [UInt8], _ length: Int) -> UInt64 {
        let trimmedBytes : [UInt8] = Array(bytes.prefix(length))
        return fingerprint(trimmedBytes)
    }

    private static func load64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
        var result: UInt64 = 0
        for i in 0...7 {
            let value: UInt64 = UInt64(bytes[offset + i]) << (i * 8)
            result = result | value
        }

        return result
    }

    private static func load32(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
        var result: UInt64 = 0
        for i in 0...3 {
            let value: UInt64 = UInt64(bytes[offset + i]) << (i * 8)
            result = result | value
        }

        return result
    }

    private static func rotateRight(_ value: UInt64, _ distance: Int) -> UInt64 {
        return (value >> UInt64(distance)) | (value << (value.bitWidth - distance))
    }

    private static func hashLength16(_ u: UInt64, _ v: UInt64, _ mul: UInt64) -> UInt64 {
        var a = (u ^ v) &* mul
        a ^= (a >> 47)
        var b = (v ^ a) &* mul
        b ^= (b >> 47)
        b = b &* mul
        return b
    }

    private static func shiftMix(_ value: UInt64) -> UInt64 {
        return value ^ (value >> 47)
    }

    private static func hashLength0to16(_ bytes: [UInt8]) -> UInt64 {
        let length: Int = bytes.count
        if (length >= 8) {
            let mul = k2 + UInt64(length) &* 2
            let a = load64(bytes, 0) &+ k2
            let b = load64(bytes, length - 8)
            let c = rotateRight(b, 37) &* mul &+ a
            let d = (rotateRight(a, 25) &+ b) &* mul
            return hashLength16(c, d, mul)
        }

        if (length >= 4) {
            let mul: UInt64 = k2 + UInt64(length) &* 2
            let a: UInt64 = load32(bytes, 0)
            return hashLength16(
                UInt64(length) &+ (a << 3),
                load32(bytes, length - 4),
                mul
            )
        }

        if (length > 0) {
            let a = Int(bytes[0])
            let b = Int(bytes[Int(length >> 1)])
            let c = bytes[Int(length - 1)]
            let y = a + (b << 8)
            let z = length + ((Int(c) << 2))
            return shiftMix(UInt64(y) &* k2 ^ UInt64(z) &* k0) &* k2
        }

        return k2
    }

    static func hashLength17to32(_ bytes: [UInt8]) -> UInt64 {
        let length = bytes.count
        let mul: UInt64 = k2 + UInt64(length) &* 2
        let a: UInt64 = load64(bytes, 0) &* k1
        let b: UInt64 = load64(bytes, 8)
        let c: UInt64 = load64(bytes, length - 8) &* mul
        let d: UInt64 = load64(bytes, length - 16) &* k2
        return hashLength16(
            rotateRight(a &+ b, 43) &+ rotateRight(c, 30) &+ d,
            a &+ rotateRight(b &+ k2, 18) &+ c,
            mul
        )
    }

    static func hashLength33To64(_ bytes: [UInt8]) -> UInt64 {
        let length: UInt64 = UInt64(bytes.count)
        let mul: UInt64 = k2 &+ length &* 2
        let a: UInt64 = load64(bytes, 0) &* k2
        let b: UInt64 = load64(bytes, 8)
        let c: UInt64 = load64(bytes, Int(length) - 8) &* mul
        let d: UInt64 = load64(bytes, Int(length) - 16) &* k2
        let y: UInt64 = rotateRight(a &+ b, 43) &+ rotateRight(c, 30) &+ d
        let z: UInt64 = hashLength16(y, a &+ rotateRight(b &+ k2, 18) &+ c, mul)
        let e: UInt64 = load64(bytes, 16) &* mul
        let f: UInt64 = load64(bytes, 24)
        let g: UInt64 = (y &+ load64(bytes, Int(length) - 32)) &* mul
        let h: UInt64 = (z &+ load64(bytes, Int(length) - 24)) &* mul
        return hashLength16(
            rotateRight(e &+ f, 43) &+ rotateRight(g, 30) &+ h,
            e &+ rotateRight(f &+ a, 18) &+ g,
            mul
        )
    }

    /**
     * Computes intermediate hash of 32 bytes of byte array from the given offset.
     */
    static func weakHashLength32WithSeeds(
        _ bytes: [UInt8],
        _ offset: Int,
        _ seedA: UInt64,
        _ seedB: UInt64
    ) -> [UInt64] {
        let part1 = load64(bytes, offset)
        let part2 = load64(bytes, offset + 8)
        let part3 = load64(bytes, offset + 16)
        let part4 = load64(bytes, offset + 24)

        var mutableSeedA = seedA &+ part1;
        var mutableSeedB = rotateRight(seedB &+ mutableSeedA &+ part4, 21)
        let c = mutableSeedA
        mutableSeedA &+= part2
        mutableSeedA &+= part3
        mutableSeedB &+= rotateRight(mutableSeedA, 44)

        return [
            mutableSeedA &+ part4,
            mutableSeedB &+ c
        ]
    }

    private static func hashLength65Plus(_ bytes: [UInt8]) -> UInt64 {
        let length: Int = bytes.count

        let seed: UInt64 = 81
        // For strings over 64 bytes we loop. Internal state consists of 56 bytes: v, w, x, y, and z.
        var x: UInt64 = seed

        var offset = 0

        var y: UInt64 = seed &* k1 &+ 113
        var z: UInt64 = shiftMix(y &* k2 &+ 113) &* k2
        var v: [UInt64] = [0,0]
        var w: [UInt64] = [0,0]
        x = x &* k2 &+ load64(bytes, offset)

        // Set end so that after the loop we have 1 to 64 bytes left to process.
        let end = offset + ((length - 1) / 64) * 64
        let last64offset = end + ((length - 1) & 63) - 63
        repeat {
            x = rotateRight(x &+ y &+ v[0] &+ load64(bytes, offset + 8), 37) &* k1
            y = rotateRight(y &+ v[1] &+ load64(bytes, offset + 48), 42) &* k1
            x ^= w[1]
            y &+= v[0] &+ load64(bytes, offset + 40)
            z = rotateRight(z &+ w[0], 33) &* k1
            v = weakHashLength32WithSeeds(bytes, offset, v[1] &* k1, x &+ w[0])
            w = weakHashLength32WithSeeds(
                bytes,
                offset + 32,
                z &+ w[1],
                y &+ load64(bytes, offset + 16)
            )
            let tmp: UInt64 = x
            x = z
            z = tmp
            offset += 64
        } while (offset != end)

        let mul : UInt64 = k1 &+ ((z & 0xFF) << 1)

        // Operate on the last 64 bytes of input.
        offset = last64offset
        w[0] &+= UInt64((length - 1) & 63)
        v[0] &+= w[0]
        w[0] &+= v[0]
        x = rotateRight(x &+ y &+ v[0] &+ load64(bytes, offset + 8), 37) &* mul
        y = rotateRight(y &+ v[1] &+ load64(bytes, offset + 48), 42) &* mul
        x ^= w[1] &* 9
        y &+= v[0] &* 9 &+ load64(bytes, offset + 40)
        z = rotateRight(z &+ w[0], 33) &* mul
        v = weakHashLength32WithSeeds(bytes, offset, v[1] &* mul, x &+ w[0])
        w = weakHashLength32WithSeeds(
            bytes,
            offset + 32,
            z &+ w[1],
            y &+ load64(bytes, offset + 16)
        )
        return hashLength16(
            hashLength16(v[0], w[0], mul) &+ shiftMix(y) &* k0 &+ x,
            hashLength16(v[1], w[1], mul) &+ z,
            mul
        )
    }
}

extension String {
    var farmHashFingerprint64: UInt64 {
        return FarmHashFingerprint64.fingerprint(self)
    }
}
