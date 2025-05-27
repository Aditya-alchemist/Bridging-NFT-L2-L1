// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IMintableNFT {
    function mint(address to, uint256 tokenId) external;
    function burn(uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IStarknetMessaging {
    function sendMessageToL2(
        uint256 to_address,
        uint256 selector,
        uint256[] calldata payload
    ) external payable;

    function consumeMessageFromL2(
        uint256 fromAddress,
        uint256[] calldata payload
    ) external;
}
// 0x9d89d21a5510e3f7430ee12dc994e2c1b20e02ea 
contract MintableNFTMock is ERC721 {
    address public bridge;
    uint256 private _currentTokenId;

    error InvalidAddress();
    error Unauthorized();
    error TokenNotExists();

    constructor(address _bridge) ERC721("Bridge NFT", "BNFT") {
        if (_bridge == address(0)) {
            revert InvalidAddress();
        }
        bridge = _bridge;
        
        for (uint256 i = 1; i <= 5; i++) {
            _mint(msg.sender, i);
            _currentTokenId = i;
        }
    }

    modifier onlyBridge() {
        if (bridge != msg.sender) {
            revert Unauthorized();
        }
        _;
    }

    function mint(address to, uint256 tokenId) external onlyBridge {
        _mint(to, tokenId);
        if (tokenId > _currentTokenId) {
            _currentTokenId = tokenId;
        }
    }

    function burn(uint256 tokenId) external onlyBridge {
        if (!_exists(tokenId)) {
            revert TokenNotExists();
        }
        _burn(tokenId);
    }

    function setBridge(address newBridge) external onlyBridge {
        if (newBridge == address(0)) {
            revert InvalidAddress();
        }
        bridge = newBridge;
    }

    function getCurrentTokenId() external view returns (uint256) {
        return _currentTokenId;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
// 0x0a6A7a6d12AEE62d6b0CE52D5cB64a0B186B3D15
contract NFTBridge {
    address public governor;
    IMintableNFT public nftCollection;
    IStarknetMessaging public snMessaging;
    uint256 public l2Bridge;
    uint256 public l2HandlerSelector;

    error InvalidTokenId();
    error InvalidAddress(string param);
    error InvalidRecipient();
    error InvalidSelector();
    error OnlyGovernor();
    error NotTokenOwner();
    error UninitializedL2Bridge();
    error UninitializedNFTCollection();

    event L2BridgeSet(uint256 indexed l2Bridge);
    event NFTCollectionSet(address indexed nftCollection);
    event SelectorSet(uint256 indexed selector);
    event BridgedToL2(address indexed sender, uint256 indexed recipient, uint256 tokenId);
    event WithdrawnFromL2(uint256 indexed fromAddress, address indexed recipient, uint256 tokenId);
    event GovernorUpdated(address indexed oldGovernor, address indexed newGovernor);

    constructor(
        address _governor,
        address _snMessaging,
        uint256 _l2HandlerSelector
    ) {
        if (_governor == address(0)) revert InvalidAddress("_governor");
        if (_snMessaging == address(0)) revert InvalidAddress("_snMessaging");
        if (_l2HandlerSelector == 0) revert InvalidSelector();

        governor = _governor;
        snMessaging = IStarknetMessaging(_snMessaging);
        l2HandlerSelector = _l2HandlerSelector;
    }

    modifier onlyGovernor() {
        if (msg.sender != governor) revert OnlyGovernor();
        _;
    }

    modifier onlyWhenL2BridgeInitialized() {
        if (l2Bridge == 0) revert UninitializedL2Bridge();
        _;
    }

    modifier onlyWhenNFTCollectionInitialized() {
        if (address(nftCollection) == address(0)) revert UninitializedNFTCollection();
        _;
    }

    function setL2Bridge(uint256 newL2Bridge) external onlyGovernor {
        if (newL2Bridge == 0) revert InvalidAddress("newL2Bridge");
        l2Bridge = newL2Bridge;
        emit L2BridgeSet(newL2Bridge);
    }

    function setNFTCollection(address newNFTCollection) external onlyGovernor {
        if (newNFTCollection == address(0)) revert InvalidAddress("newNFTCollection");
        nftCollection = IMintableNFT(newNFTCollection);
        emit NFTCollectionSet(newNFTCollection);
    }

    function setL2HandlerSelector(uint256 newSelector) external onlyGovernor {
        if (newSelector == 0) revert InvalidSelector();
        l2HandlerSelector = newSelector;
        emit SelectorSet(newSelector);
    }

    function bridgeToL2(
        uint256 recipientAddress,
        uint256 tokenId
    ) external payable onlyWhenL2BridgeInitialized onlyWhenNFTCollectionInitialized {
        if (recipientAddress == 0) revert InvalidRecipient();
        if (tokenId == 0) revert InvalidTokenId();

        // Check if caller owns the NFT
        address owner = nftCollection.ownerOf(tokenId);
        if (owner != msg.sender) revert NotTokenOwner();

        // Burn the NFT on L1
        nftCollection.burn(tokenId);

        // Send tokenId as u256 (Starknet will automatically split it)
        uint256[] memory payload = new uint256[](2);
        payload[0] = recipientAddress;
        payload[1] = tokenId;

        snMessaging.sendMessageToL2{value: msg.value}(
            l2Bridge,
            l2HandlerSelector,
            payload
        );

        emit BridgedToL2(msg.sender, recipientAddress, tokenId);
    }

    function consumeWithdrawal(
        uint256 fromAddress,
        address recipient,
        uint256 tokenId
    ) external onlyWhenNFTCollectionInitialized {
        if (recipient == address(0)) revert InvalidAddress("recipient");
        if (tokenId == 0) revert InvalidTokenId();
        
        uint256[] memory payload = new uint256[](2);
        payload[0] = uint256(uint160(recipient));
        payload[1] = tokenId;

        snMessaging.consumeMessageFromL2(fromAddress, payload);
        
        nftCollection.mint(recipient, tokenId);

        emit WithdrawnFromL2(fromAddress, recipient, tokenId);
    }

    function splitUint256(
        uint256 value
    ) private pure returns (uint128 low, uint128 high) {
        low = uint128(value & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        high = uint128(value >> 128);
    }

    function setGovernor(address newGovernor) external onlyGovernor {
        if (newGovernor == address(0)) revert InvalidAddress("newGovernor");
        address oldGovernor = governor;
        governor = newGovernor;
        emit GovernorUpdated(oldGovernor, newGovernor);
    }

    function recoverETH() external onlyGovernor {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(governor).call{value: balance}("");
            require(success, "ETH transfer failed");
        }
    }

    function getConfiguration() 
        external 
        view 
        returns (
            address _governor,
            address _nftCollection,
            address _snMessaging,
            uint256 _l2Bridge,
            uint256 _l2HandlerSelector
        ) 
    {
        return (
            governor,
            address(nftCollection),
            address(snMessaging),
            l2Bridge,
            l2HandlerSelector
        );
    }
}