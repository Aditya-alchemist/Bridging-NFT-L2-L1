
---

# 🌉 NFT Bridge: Ethereum ↔ StarkNet

Welcome to the **NFT Bridge** project — a fully functional L1 ↔ L2 NFT bridge that allows users to seamlessly move their NFTs between Ethereum and StarkNet. This bridge ensures asset security and consistency through lock-and-mint/burn-and-release mechanisms, empowering users to interact with NFTs across chains without compromising ownership or authenticity.

---

## ✨ Key Features

* 🔗 **Cross-Layer Bridging**: Move NFTs from Ethereum (L1) to StarkNet (L2) and vice versa.
* 🔒 **Lock-and-Mint Mechanism**: NFTs on Ethereum are locked, and equivalent NFTs are minted on StarkNet.
* 🔥 **Burn-and-Release Mechanism**: NFTs are burned on StarkNet and released back to Ethereum.
* 📦 **ERC-721 Compatibility**: Fully supports the ERC-721 standard.
* 🕸️ **Bridge Contract Interoperability**: Uses messaging and event consumption for cross-chain communication.
* ⏱️ **Fast L1 → L2 Transfers**: Bridge transactions from Ethereum to StarkNet typically settle in \~3 minutes.
* 🧱 **Modular Cairo & Solidity Code**: Easily extensible architecture using Solidity for L1 and Cairo 1.0 for L2.



---

## ⚙️ How It Works

### 🟢 Bridging from Ethereum to StarkNet

1. **User calls `bridgeNFTToL2(tokenId)`** on `NFTBridge.sol`.
2. The bridge locks the NFT in the L1 contract (`NFTContract.sol`) via `safeTransferFrom`.
3. A message is sent to L2 using `StarknetCore`'s `send_message_to_l2`.
4. The `NFTBridge.cairo` contract on L2 receives the message.
5. It mints a new NFT with the same metadata using `ERC721.cairo` to the user's L2 address.

### 🔁 Bridging back from StarkNet to Ethereum

1. **User calls `bridgeNFTToL1(tokenId)`** on `NFTBridge.cairo`.
2. The NFT is burned on L2.
3. A message is sent to L1 using `StarkNetCore.emit_message_to_l1`.
4. The message is consumed on L1 via `consumeMessageFromL2`.
5. The original NFT is unlocked from the L1 bridge contract and transferred back to the user.

---

## 🧑‍💻 Contracts

### 📦 Ethereum L1

* **`ERC721.sol`**
  Standard NFT contract implementing ERC721, using OpenZeppelin.

* **`NFTBridge.sol`**
  Handles locking NFTs and sending messages to L2. Unlocks them upon successful withdrawal.

### ⚛️ StarkNet L2

* **`ERC721.cairo`**
  Implements the ERC721 interface using Cairo 1.0 with metadata support.

* **`NFTBridge.cairo`**
  Handles minting new NFTs upon L1 message receipt, and burning for L2 → L1 withdrawals.

---

## 🧪 Testing

* **Foundry** used for Ethereum-side unit tests.
* **StarkNet Devnet** used for local L2 simulation.
* Messaging was mocked using:

  * `StarknetMessagingMock.sol` for L1.
  * `@dojoengine/toolkit` for L2 mocking in TypeScript.

Example Foundry Test (L1 → L2):

```solidity
function testBridgeNFTToL2() public {
    uint256 tokenId = 1;
    nft.mint(user, tokenId);
    vm.prank(user);
    bridge.bridgeNFTToL2(tokenId, starknetL2Address);
    assertEq(nft.ownerOf(tokenId), address(bridge));
}
```

Example Cairo Test (L2 → L1):

```cairo
#[test]
fn test_bridge_nft_to_l1() {
    let token_id = 1;
    let l2_user = 0x123;
    let l1_user = 0xABC;
    // simulate mint and bridge
    assert_eq!(erc721.owner_of(token_id), l2_user);
    bridge.bridge_to_l1(token_id, l1_user);
    assert!(erc721.owner_of(token_id).is_none());
}
```

---

## 🧩 Deployment Instructions

### 1. Deploy L1 contracts

```bash
forge create --rpc-url $RPC_URL --private-key $PK src/NFTBridge.sol:NFTBridge
```

### 2. Deploy L2 contracts

```bash
starkli deploy --contract target/dev/NFTBridge.contract_class.json
```

### 3. Set up bridge communication

* Register L1 ↔ L2 addresses on both sides.
* Configure `StarknetCore` address on L1 bridge.
* Verify message selectors match.

---

## 🔐 Security Considerations

* 🧷 **Replay Protection**: All messages consumed once with nonce checks.
* 🔐 **Reentrancy Guards**: All external functions protected using `nonReentrant`.
* 🛑 **Only Contract Owner Can Configure** bridge parameters.
* 💾 **Metadata Handling**: Metadata is verified using `tokenURI` hashing.

---

## 🌍 Use Cases

* 🎮 **Cross-chain Gaming Assets**: Bring unique items into StarkNet games.
* 🖼️ **NFT Galleries**: Display NFTs on StarkNet while preserving L1 provenance.
* 💰 **Layer 2 Scaling**: Offload high gas interactions for NFTs to StarkNet.
* 🔄 **NFT Rentals**: Temporarily mint NFTs on L2 and burn upon return.

---

## 📈 Performance

* **L1 → L2** bridging: 2–5 minutes average.
* **L2 → L1** withdrawal: Up to 3+ hours due to L1 message finality.
* Cost savings: 90%+ lower mint gas fees on StarkNet.

---

## 📎 Resources

* StarkNet Docs: [https://docs.starknet.io](https://docs.starknet.io)
* Cairo Book: [https://book.cairo-lang.org](https://book.cairo-lang.org)
* OpenZeppelin Contracts: [https://docs.openzeppelin.com/contracts](https://docs.openzeppelin.com/contracts)

---

## 🛠️ Tech Stack

| Layer   | Technology                                         |
| ------- | -------------------------------------------------- |
| L1      | Solidity, OpenZeppelin, Foundry                    |
| L2      | Cairo 1.0, Starkli, StarkNet.js                    |
| Tooling | Hardhat, StarkNet Devnet, Forge, Cairo test runner |

---

## 📣 Contributing

PRs, feedback, and issues are welcome! Please open an issue or fork the repo and submit a pull request. Contributions in both Solidity and Cairo are appreciated.

---

## 📜 License

MIT License © 2025 \[Aditya]

---


