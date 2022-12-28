import SpriteKit
import GameplayKit


class GameScene: SKScene {

    var strategy: GKStrategist!
    var model: Board { return strategy.gameModel as! Board }

    var gameBoard: SKNode!
    var label1: SKLabelNode!
    var newLabel2: SKLabelNode!
    var labelWhite: SKLabelNode!
    var labelBlack: SKLabelNode!
    var boardPieces: [SKNode?] = Array(repeating: nil, count: 64)

    func isValidIndex(index i: Int) -> Bool {
        return (i >> 3) & 1 == i & 1
    }

    func getLocationForIndex(index i: Int) -> CGPoint {
        let x = check * CGFloat((i % 8) - 4) + check / 2
        let y = check * CGFloat((i / 8) - 4) + check / 2
        return CGPoint(x: x, y: y)
    }

    func indexForLocation(location l: CGPoint) -> Int? {
        guard abs(l.x) < (side / 2) && abs(l.y) < (side / 2) else { return nil }

        let i = l.x / check + 4
        let j = l.y / check + 4

        let position = Int(floor(i) + floor(j) * 8)
        print(position)

        return position
    }

    var side: CGFloat { return min(size.width, size.height) * 0.8 }
    var check: CGFloat { return side / 8}
    var radius: CGFloat { return check * 0.4 }

    override func didChangeSize(_ oldSize: CGSize) {
        gameBoard?.position = CGPoint(x: frame.midX, y: frame.midY)
    }

    override func didMove(to view: SKView) {
        strategy = GKMonteCarloStrategist()
//        (strategist as? GKMinmaxStrategist)?.maxLookAheadDepth = 4
//        strategist = GKMinmaxStrategist()
        strategy.randomSource = GKLinearCongruentialRandomSource()
        strategy.gameModel = Board(BitBoard())

        gameBoard = SKShapeNode(rectOf: CGSize(width: side, height: side))
        gameBoard.name = "board"
        gameBoard.position = CGPoint(x: frame.midX, y: frame.midY)
        addChild(gameBoard)
        let fontSize = side / 32
        let offset = CGPoint(x: side / 2, y: side / 2 + fontSize * 1.5)
        label1 = SKLabelNode(text: "Checkers!")
        label1.verticalAlignmentMode = .baseline
        label1.horizontalAlignmentMode = .right
        label1.fontSize = fontSize
        label1.fontColor = SKColor.yellow
        label1.fontName = "Avenir"
        label1.position = CGPoint(x: offset.x, y: -offset.y)
        gameBoard.addChild(label1)
        newLabel2 = SKLabelNode(text: "New Game")
        newLabel2.verticalAlignmentMode = .baseline
        newLabel2.horizontalAlignmentMode = .left
        newLabel2.fontSize = fontSize
        newLabel2.fontColor = SKColor.yellow
        newLabel2.fontName = "Avenir"
        newLabel2.position = CGPoint(x: -offset.x, y: offset.y - fontSize)
        gameBoard.addChild(newLabel2)
        labelWhite = SKLabelNode(text: "\(Player.White)")
        labelWhite.verticalAlignmentMode = .baseline
        labelWhite.horizontalAlignmentMode = .left
        labelWhite.fontSize = fontSize
        labelWhite.fontColor = .white
        labelWhite.fontName = "Avenir"
        labelWhite.position = CGPoint(x: -offset.x, y: -offset.y)
        gameBoard.addChild(labelWhite)

        labelBlack = SKLabelNode(text: "\(Player.Black)")
        labelBlack.verticalAlignmentMode = .baseline
        labelBlack.horizontalAlignmentMode = .right
        labelBlack.fontSize = fontSize
        labelBlack.fontColor = .white
        labelBlack.fontName = "Avenir"
        labelBlack.position = CGPoint(x: offset.x, y: offset.y - fontSize)
        gameBoard.addChild(labelBlack)

        for i in 0..<64 {
            let position = getLocationForIndex(index: i)

            let square = SKShapeNode(rectOf: CGSize(width: check, height: check))
            let gray = isValidIndex(index: i)
            square.fillColor = gray ? .clear : .gray
            square.position = position
            square.name = "square"
            gameBoard.addChild(square)

            if isValidIndex(index: i) {
                let label = SKLabelNode(text: "\(i >> 1)")
                label.fontSize = radius * 0.8
                label.fontColor = .yellow
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.position = position
                label.name = "label"
                label.zPosition = 9
                gameBoard.addChild(label)
            }
        }

        resetBoard()
    }

    func resetBoard() {
        gameBoard.enumerateChildNodes(withName: "piece", using: { (node, nil) in
            node.removeFromParent()
        })

        boardPieces = Array(repeating: nil, count: 64)

        for index in model.checkSet() {
            let color: SKColor = model.isWhite(index) ? .red : .blue
            let piece = SKShapeNode(circleOfRadius: radius)
            let inner = SKShapeNode(circleOfRadius: radius * 0.8)
            inner.fillColor = color
            piece.addChild(inner)
            piece.position = self.getLocationForIndex(index: index)
            piece.name = "piece"
            piece.fillColor = model.isQueen(index) ? .yellow : color
            piece.zPosition = 2

            boardPieces[index] = piece

            gameBoard.addChild(piece)
        }

        nextTurn()
    }

    var moving: SKNode?
    var fromPosition: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if labelWhite.contains(touch.location(in: gameBoard)) {
                Player.White.isComp = !Player.White.isComp
                labelWhite.text = "\(Player.White)"
                if let activePlayer = model.activePlayer as? Player, activePlayer == Player.White {
                    nextTurn()
                }
                return
            }

            if labelBlack.contains(touch.location(in: gameBoard)) {
                Player.Black.isComp = !Player.Black.isComp
                labelBlack.text = "\(Player.Black)"
                if let activePlayer = model.activePlayer as? Player, activePlayer == Player.Black {
                    nextTurn()
                }
                return
            }
        }

        if let activePlayer = model.activePlayer as? Player {
            guard !activePlayer.isComp else { return }
        }

        for touch in touches {
            if newLabel2.contains(touch.location(in: gameBoard)) {
                strategy.gameModel = Board(BitBoard())
                resetBoard()
                return
            }

            let location = touch.location(in: gameBoard)

            for node in gameBoard.nodes(at: location) {
                guard node.name == "piece", node.contains(location) else { continue }

                moving = node
                node.zPosition = 3
                fromPosition = node.position
                return
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let node = moving, let touch = touches.first else { return }
        node.position = touch.location(in: gameBoard)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let node = moving, let touch = touches.first else { return }

        defer {
            node.position = fromPosition!
            node.zPosition = 1
            moving = nil
            fromPosition = nil
        }

        let newLocation = touch.location(in: gameBoard)
        guard let to = indexForLocation(location: newLocation) else { return }
        guard let from = indexForLocation(location: fromPosition!) else { return }
        guard let update = model.update(from, to) else { return }

        let action = SKAction.move(to: getLocationForIndex(index: to), duration: 0.0)
        runAction(action, node)

        updateBoard(update)
        nextTurn()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let node = moving else { return }

        node.position = fromPosition!
        node.zPosition = 1
        moving = nil
        fromPosition = nil
    }

    func runAction(_ action:SKAction, _ piece: SKNode) {
        if piece.hasActions() {
            DispatchQueue.main.async {
                action.timingMode = SKActionTimingMode.easeIn
                self.runAction(action, piece)
            }
        } else {
            piece.run(action)
        }
    }

    func updateBoard(_ update: Update) {
        model.apply(update)
        print("move: \(String(describing: update.move))")
        print("capture: \(String(describing: update.capture))")
        print("promotion: \(String(describing: update.promotion))")

        let duration = Player.White.isComp && Player.Black.isComp ? 0.01 : 0.25

        if let (from, to) = update.move, let piece = boardPieces[from] as? SKShapeNode {
            boardPieces[to] = boardPieces[from]
            boardPieces[from] = nil

            let action = SKAction.move(to: getLocationForIndex(index: to), duration: duration)
            if model.isQueen(from) == model.isQueen(to) {
                runAction(action, piece)
            } else {
                let color = piece.fillColor
                let glow = SKAction.customAction(withDuration: duration) { (node, elapsedTime) in
                    piece.fillColor = UIColor.interpolate(from: color, to: .white, with: elapsedTime / CGFloat(duration))
                }
                let group = SKAction.group([action, glow])
                runAction(group, piece)
            }
        }

        if let pos = update.capture, let piece = boardPieces[pos] {
            boardPieces[pos] = nil
            piece.zPosition = 1

            let action = SKAction.sequence([SKAction.fadeOut(withDuration: duration), SKAction.removeFromParent()])
            runAction(action, piece)
        }
    }

    func nextTurn() {
        if let player = model.activePlayer as? Player {
            if player.isComp {
                label1.text = "Thinking ..."
                DispatchQueue.global(qos: .background).async {
                    DispatchQueue.main.async {
                        if let update = self.strategy.bestMoveForActivePlayer() as? Update {
                            self.updateBoard(update)
                        } else {
                            print("wat")
                        }
                        self.nextTurn()
                    }
                }
            } else {
                label1.text =  "Move!" + " (\(model.move))"
            }
        } else {
            if model.isWin(for: Player.White) {
                label1.text = "\(Player.White) wins!"
            } else if model.isWin(for: Player.Black) {
                label1.text = "\(Player.Black) wins!"
            } else {
                label1.text = "Draw at move \(model.move)"
            }
        }
    }
}

public extension UIColor {
    var components: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let components = self.cgColor.components!

        switch components.count == 2 {
        case true : return (r: components[0], g: components[0], b: components[0], a: components[1])
        case false: return (r: components[0], g: components[1], b: components[2], a: components[3])
        }
    }

    static func interpolate(from fromColor: UIColor, to toColor: UIColor, with progress: CGFloat) -> UIColor {
        let fromComponents = fromColor.components
        let toComponents = toColor.components

        let r = (1 - progress) * fromComponents.r + progress * toComponents.r
        let g = (1 - progress) * fromComponents.g + progress * toComponents.g
        let b = (1 - progress) * fromComponents.b + progress * toComponents.b
        let a = (1 - progress) * fromComponents.a + progress * toComponents.a

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
