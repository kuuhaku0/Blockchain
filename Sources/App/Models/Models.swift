//
//  Models.swift
//  App
//
//  Created by C4Q on 4/27/18.
//

import Foundation
import Vapor
import HTTP

class BlockchainNode: Codable {
    
    var address: String
    
    init?(request: Request) {
        guard let address = request.data["address"]?.string else {
            return nil
        }
        self.address = address
    }
    
    init(address: String) {
        self.address = address
    }
}


protocol SmartContract {
    func apply(transaction: Transaction)
}

class TransactionTypeSmartContract: SmartContract {
    func apply(transaction: Transaction) {
        var fees = 0.0
        switch transaction.transactionType {
        case .domestic:
            fees = 0.05
        case .international:
            fees = 0.05
        }
        transaction.fees = transaction.amount * fees
        transaction.amount -= transaction.fees
    }
}

enum TransactionType: String, Codable {
    case domestic
    case international
}

class Transaction: Codable {

    var from: String
    var to: String
    var amount: Double
    var fees: Double = 0.0
    var transactionType: TransactionType

    init?(request: Request, transactionType: TransactionType) {

        guard let from = request.data["from"]?.string,
            let to = request.data["to"]?.string,
            let amount = request.data["amount"]?.double else {
                return nil
        }
        self.from = from
        self.to = to
        self.amount = amount
        self.transactionType = transactionType
    }

    init(from: String, to: String, amount: Double, transactionType: TransactionType) {
        self.from = from
        self.to = to
        self.amount = amount
        self.transactionType = transactionType
    }

}

class Block: Codable {
    var index: Int = 0
    var previousHash: String = ""
    var hash: String!
    var nounce: Int
    
    private(set) var transaction: [Transaction] = [Transaction]()
    
    var key: String {
        get {
            let transactionsData = try! JSONEncoder().encode(self.transaction)
            let transactionsJSONString = String(data: transactionsData, encoding: .utf8)
            
            return String(self.index) + self.previousHash + String(self.nounce) + transactionsJSONString!
        }
    }
    
    func addTransaction(_ transaction: Transaction) {
        self.transaction.append(transaction)
    }
    
    init() {
        self.nounce = 0
    }
}

class Blockchain: Codable {
    
    var blocks: [Block] = [Block]()
    private(set) var nodes: [BlockchainNode] = [BlockchainNode]()
    private(set) var smartContracts: [SmartContract] = [TransactionTypeSmartContract()]
    
    init(genesisBlock: Block) {
        addBlock(genesisBlock)
    }
    
    private enum CodingKeys: CodingKey {
        case blocks
    }
    
    func addNode(_ node: BlockchainNode) {
        self.nodes.append(node)
    }
    
    func addBlock(_ block: Block) {
        if self.blocks.isEmpty {
            block.previousHash = "0000000000000000"
            block.hash = generateHash(for: block)
        }
        self.blocks.append(block)
    }
    
    func getNextBlock(transactions: [Transaction]) -> Block {
        
        let block = Block()
        transactions.forEach { transaction in
            block.addTransaction(transaction)
        }
        
        let previousBlock = getPreviousBlock()
        block.index = self.blocks.count
        block.previousHash = previousBlock.hash
        block.hash = generateHash(for: block)
        return block
    }
    
    private func getPreviousBlock() -> Block {
        return self.blocks[self.blocks.count - 1]
    }
    
    func generateHash(for block: Block) -> String {
        var hash = block.key.sha1Hash()
        
        while !hash.hasPrefix("00") {
            block.nounce += 1
            hash = block.key.sha1Hash()
            print(hash)
        }
        
        return hash
    }
}

extension String {
    
    func sha1Hash() -> String{
        
        let task = Process()
        task.launchPath = "/usr/bin/shasum"
        task.arguments = []
        
        let inputPipe = Pipe()
        
        inputPipe.fileHandleForWriting.write(self.data(using: .utf8)!)
        inputPipe.fileHandleForWriting.closeFile()
        
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardInput = inputPipe
        task.launch()
        
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let hash = String(data: data, encoding: .utf8)!
        return hash.replacingOccurrences(of: "  -\n", with: "")
    }
}
