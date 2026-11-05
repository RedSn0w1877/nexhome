import Foundation

/// Deterministic PRNG (SplitMix64) so the generated house is identical on every launch, the way
/// `kotlin.random.Random(seed)` behaved on Android. The exact sequence differs from Kotlin's, so the
/// Swift build generates a house of the same shape and size but not the same individual values.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// 0.0 ..< 1.0
    mutating func nextDouble() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    /// `from ..< until`
    mutating func nextInt(_ from: Int, _ until: Int) -> Int {
        guard until > from else { return from }
        return from + Int(nextDouble() * Double(until - from))
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        nextInt(range.lowerBound, range.upperBound + 1)
    }

    mutating func nextDouble(_ from: Double, _ until: Double) -> Double {
        from + nextDouble() * (until - from)
    }

    mutating func chance(_ probability: Double) -> Bool {
        nextDouble() < probability
    }

    mutating func pick<T>(_ values: [T]) -> T {
        values[nextInt(0, values.count)]
    }

    mutating func pick<T: CaseIterable>(_ type: T.Type) -> T where T.AllCases == [T] {
        let all = T.allCases
        return all[nextInt(0, all.count)]
    }

    mutating func shuffle<T>(_ values: [T]) -> [T] {
        var copy = values
        guard copy.count > 1 else { return copy }
        for i in stride(from: copy.count - 1, to: 0, by: -1) {
            let j = nextInt(0, i + 1)
            copy.swapAt(i, j)
        }
        return copy
    }
}
