//class hash 0x0590229bb37d1387652cf3cb4e5decfe8da79937fd995b7af3208a2f07506647
//deployed at 0x073a27818d7a5a229fbf9b06f68a4bb2275d191cfde10e0bbc82fcbef6910c83


use starknet::{ContractAddress, EthAddress};

#[starknet::interface]
pub trait IMintableNFT<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn burn(ref self: TContractState, token_id: u256);
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256);
}

#[starknet::interface]
pub trait INFTBridge<TContractState> {
    fn bridge_to_l1(ref self: TContractState, l1_recipient: EthAddress, token_id: u256);
    fn set_l1_bridge(ref self: TContractState, l1_bridge_address: EthAddress);
    fn set_nft_collection(ref self: TContractState, l2_nft_address: ContractAddress);
    fn governor(self: @TContractState) -> ContractAddress;
    fn l1_bridge(self: @TContractState) -> felt252;
    fn l2_nft_collection(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
pub mod NFTBridge {
    use core::num::traits::Zero;
    use starknet::{ContractAddress, EthAddress, get_caller_address, syscalls, SyscallResultTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::{IMintableNFTDispatcher, IMintableNFTDispatcherTrait};

    #[storage]
    pub struct Storage {
        pub governor: ContractAddress,
        pub l1_bridge: felt252,
        pub l2_nft_collection: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        WithdrawInitiated: WithdrawInitiated,
        DepositHandled: DepositHandled,
        L1BridgeSet: L1BridgeSet,
        L2NFTCollectionSet: L2NFTCollectionSet,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WithdrawInitiated {
        pub l1_recipient: EthAddress,
        pub token_id: u256,
        pub caller_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DepositHandled {
        pub account: ContractAddress,
        pub token_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct L1BridgeSet {
        l1_bridge_address: EthAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct L2NFTCollectionSet {
        l2_nft_address: ContractAddress,
    }

    pub mod Errors {
        pub const EXPECTED_FROM_BRIDGE_ONLY: felt252 = 'Expected from bridge only';
        pub const INVALID_ADDRESS: felt252 = 'Invalid address';
        pub const INVALID_TOKEN_ID: felt252 = 'Invalid token ID';
        pub const UNAUTHORIZED: felt252 = 'Unauthorized';
        pub const NOT_TOKEN_OWNER: felt252 = 'Not token owner';
        pub const NFT_NOT_SET: felt252 = 'NFT collection not set';
        pub const L1_BRIDGE_NOT_SET: felt252 = 'L1 bridge address not set';
    }

    #[constructor]
    fn constructor(ref self: ContractState, governor: ContractAddress) {
        assert(governor.is_non_zero(), Errors::INVALID_ADDRESS);
        self.governor.write(governor);
    }

    #[abi(embed_v0)]
    impl NFTBridge of super::INFTBridge<ContractState> {
        fn bridge_to_l1(ref self: ContractState, l1_recipient: EthAddress, token_id: u256) {
            assert(l1_recipient.is_non_zero(), Errors::INVALID_ADDRESS);
            assert(token_id.is_non_zero(), Errors::INVALID_TOKEN_ID);
            self._assert_l1_bridge_set();
            self._assert_nft_collection_set();

            let caller_address = get_caller_address();
            let nft_dispatcher = IMintableNFTDispatcher { contract_address: self.l2_nft_collection.read() };
            
            let owner = nft_dispatcher.owner_of(token_id);
            assert(owner == caller_address, Errors::NOT_TOKEN_OWNER);

            nft_dispatcher.burn(token_id);

            let mut payload: Array<felt252> = array![
                l1_recipient.into(), 
                token_id.low.into(),token_id.high.into(),
            ];
            syscalls::send_message_to_l1_syscall(self.l1_bridge.read(), payload.span())
                .unwrap_syscall();

            self.emit(WithdrawInitiated { l1_recipient, token_id, caller_address });
        }

        fn set_l1_bridge(ref self: ContractState, l1_bridge_address: EthAddress) {
            self._assert_only_governor();
            assert(l1_bridge_address.is_non_zero(), Errors::INVALID_ADDRESS);

            self.l1_bridge.write(l1_bridge_address.into());
            self.emit(L1BridgeSet { l1_bridge_address });
        }

        fn set_nft_collection(ref self: ContractState, l2_nft_address: ContractAddress) {
            self._assert_only_governor();
            assert(l2_nft_address.is_non_zero(), Errors::INVALID_ADDRESS);

            self.l2_nft_collection.write(l2_nft_address);
            self.emit(L2NFTCollectionSet { l2_nft_address });
        }

        fn governor(self: @ContractState) -> ContractAddress {
            self.governor.read()
        }

        fn l1_bridge(self: @ContractState) -> felt252 {
            self.l1_bridge.read()
        }

        fn l2_nft_collection(self: @ContractState) -> ContractAddress {
            self.l2_nft_collection.read()
        }
    }

    #[generate_trait]
    impl Internal of InternalTrait {
        fn _assert_only_governor(self: @ContractState) {
            assert(get_caller_address() == self.governor.read(), Errors::UNAUTHORIZED);
        }

        fn _assert_nft_collection_set(self: @ContractState) {
            assert(self.l2_nft_collection.read().is_non_zero(), Errors::NFT_NOT_SET);
        }

        fn _assert_l1_bridge_set(self: @ContractState) {
            assert(self.l1_bridge.read().is_non_zero(), Errors::L1_BRIDGE_NOT_SET);
        }
    }

    #[l1_handler]
    pub fn handle_deposit(
        ref self: ContractState, 
        from_address: felt252, 
        account: ContractAddress, 
        token_id: u256,
    ) {
        assert(from_address == self.l1_bridge.read(), Errors::EXPECTED_FROM_BRIDGE_ONLY);
        assert(account.is_non_zero(), Errors::INVALID_ADDRESS);
        assert(token_id.is_non_zero(), Errors::INVALID_TOKEN_ID);
        self._assert_nft_collection_set();

        IMintableNFTDispatcher { contract_address: self.l2_nft_collection.read() }
            .mint(account, token_id);

        self.emit(Event::DepositHandled(DepositHandled { account, token_id }));
    }
}