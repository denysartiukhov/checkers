import Foundation

public struct BitBoard {
    public typealias Mask = UInt32
    public typealias MaskIndex = Int
    public typealias CheckIndex = Int

    let white: Mask
    let black: Mask
    let queen: Mask

    let player: Bool
    let range: Range<Int>

    public init() {
        self.init(white: 0x00000FFF, black: 0xFFF00000, queen: 0, player: false)
    }

    public init(white: Mask, black: Mask, queen: Mask, player: Bool, range: Range<Int> = 0..<256) {
        if white & black != 0 {
            fatalError("white and black pieces in the same check")
        }

        if (white | black) & queen != queen {
            fatalError("queen must have a side")
        }

        self.white = white
        self.black = black
        self.queen = queen
        self.player = player
        self.range = range
    }
}

extension BitBoard.Mask {
    public init(maskIndex: BitBoard.MaskIndex) {
        self.init(1 << maskIndex)
    }

    public var description: String {
        return "\(BitBoard(white: self, black: 0, queen: 0, player: false))"
    }

    public func hasIndex(maskIndex: BitBoard.MaskIndex) -> Bool {
        return self & BitBoard.Mask(maskIndex: maskIndex) != 0
    }

    public func indexSet() -> [BitBoard.MaskIndex] {
        return (0..<self.bitWidth).compactMap { self.hasIndex(maskIndex: $0) ? $0 : nil }
    }

    public func checkSet() -> [BitBoard.CheckIndex] {
        return self.indexSet().map { $0.checkIndex() }
    }
}

extension BitBoard.MaskIndex {
    public init(checkIndex: BitBoard.CheckIndex) {
        self = checkIndex >> 1
    }

    public func checkIndex() -> BitBoard.CheckIndex {
        return self << 1 + (self >> 2 & 1)
    }
}

extension BitBoard: CustomStringConvertible {
    public var description: String {
        let check = { (mask: Mask) -> String in
            if self.white & mask != 0 {
                return self.queen & mask != 0 ? "◆" : "●"
            }
            if self.black & mask != 0 {
                return self.queen & mask != 0 ? "◇" : "○"
            }
            return " "
        }

        let top = "┌─┬─┬─┬─┬─┬─┬─┬─┐"
        let bot = "└─┴─┴─┴─┴─┴─┴─┴─┘"
        let header = (0..<8).reduce(""){ "\($0) \($1)" } + (player ? "  ○" : "  ●") + "\n\(top)\n"
        let lines = (0..<8).reversed().reduce(header) { res, row in
            let cols = (0..<4).reduce("") { cur, col in
                let check = "\(check(1 << (row * 4 + col)))"
                let (first, second) = (row & 1 != 0) ? (" ", check) : (check, " ")

                return cur + "\(first)│\(second)│"
            }

            return res + "│\(cols) \(row)\n"
            } + "\(bot)\n"

        return lines
    }
}

extension BitBoard: Sequence {

    static let allMovements = 0..<256

    var isContinuation: Bool { return range != BitBoard.allMovements }

    public func makeIterator() -> AnyIterator<BitBoard> {
        var stack = [self.makeIteratorCont()]

        return AnyIterator {
            while let iter = stack.popLast() {
                guard let res = iter.next() else { continue }

                stack.append(iter)

                guard res.isContinuation else { return res }

                let next = res.makeIteratorCont()
                stack.append(next)
            }
            return nil
        }
    }

    public func makeIteratorCont() -> AnyIterator<BitBoard> {
        var i = self.range.startIndex
        var hasCaptured = false

        let moveMask: [Mask] = [0xF0808080, 0xF1010101, 0x8080808F, 0x0101010F]
        let captMask: [Mask] = [0xFF888888, 0xFF111111, 0x888888FF, 0x111111FF]
        let (playerMask, opponentMask) = player ? (black, white) : (white, black)
        let empty: Mask = ~(white|black)

        let board = self

        return AnyIterator {

            while i < self.range.endIndex {
                let idx = (i >> 2) & 31
                let dir = i & 3
                let this = Mask(1 << idx)
                let cap = i < 128
                i += 1
                guard cap || !hasCaptured else { break }

                guard empty & this == 0 else { continue }

                guard ~(cap ? captMask : moveMask)[dir] & this & playerMask != 0 else { continue }

                let isQueen = board.queen & this != 0
                let isForward = board.player == (dir & 2 != 0)
                guard isQueen || isForward else { continue }

                let odd = (idx >> 2 & 1)
                let wst = (dir & 1)
                let sth = (dir & 2) << 2

                let adj1 = idx + odd - wst - sth
                let mask1 = Mask(0x10 << adj1)

                guard mask1 & (cap ? opponentMask : empty) != 0 else { continue }

                let playerXor: Mask
                let opponentXor: Mask

                if cap {
                    let adj2 = idx - (wst << 1) - (sth << 1) + 9
                    let mask2 = Mask(1 << adj2)

                    guard mask2 & empty != 0 else { continue }

                    hasCaptured = true
                    playerXor = mask2
                    opponentXor = mask1

                } else {
                    playerXor = mask1
                    opponentXor = 0
                }

                let newPlayerMask = playerMask ^ this ^ playerXor
                let newOpponentMask = opponentMask ^ opponentXor
                let (newWhite, newBlack) = board.player ? (newOpponentMask, newPlayerMask) : (newPlayerMask, newOpponentMask)

                let newQueenMaskPromo = playerXor & (board.player ? 0xf : 0xf0000000)
                let newQueenMaskPlayer = (isQueen ? this | playerXor : 0) | (board.queen & opponentXor)
                let newQueenMask = board.queen ^ newQueenMaskPlayer | newQueenMaskPromo

                let new = (idx - (wst << 1) - (sth << 1) + 9) << 2
                let cont = cap && (isQueen || (newQueenMaskPromo == 0))
                let range = cont ? new..<(new + 4) : BitBoard.allMovements
                let newPlayer = cont ? board.player : !board.player

                let res = BitBoard(white: newWhite, black: newBlack, queen: newQueenMask, player: newPlayer, range: range)

                return res
            }

            if !hasCaptured && self.isContinuation {
                hasCaptured = true
                return BitBoard(white: board.white, black: board.black, queen: board.queen, player: !board.player)
            }

            return nil
        }
    }

    func applyMove(from: MaskIndex, to: MaskIndex) -> BitBoard? {

        let playerMask = (player ? black : white) ^ (Mask(maskIndex: from) | Mask(maskIndex: to))

        guard let result = makeIteratorCont().first(where: {
            playerMask == (player ? $0.black : $0.white)
        }) else {
            return nil
        }

        if result.isContinuation {
            guard let next = result.makeIteratorCont().next() else { return nil }
            guard next.player == result.player else { return next }
        }

        return result
    }
}

