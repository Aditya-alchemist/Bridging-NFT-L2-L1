//class hash 0x03df5db626d3a0bb53c87b2f9a80cf66e458a95ff07d15e6d46c20d727658c61
//deployed at 0x03495dee0f5f99d62a924e57b1f7be3db48c962e0486e662bb20f3a65ab9de1b

use starknet::{ContractAddress};

#[starknet::interface]
pub trait IMintableNFT<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn burn(ref self: TContractState, token_id: u256);
   
}

#[starknet::contract]
pub mod MintableNFTMock {
    use core::num::traits::Zero;
    use starknet::event::EventEmitter;
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin::introspection::src5::SRC5Component;

  component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {

        bridge: ContractAddress,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Minted: Minted,
        Burned: Burned,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Minted {
        pub to: ContractAddress,
        pub token_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Burned {
        pub token_id: u256,
    }

    pub mod Errors {
        pub const INVALID_ADDRESS: felt252 = 'Invalid address';
        pub const UNAUTHORIZED: felt252 = 'Unauthorized';
        pub const TOKEN_NOT_EXISTS: felt252 = 'Token does not exist';
    }

    #[constructor]
    fn constructor(ref self: ContractState, bridge: ContractAddress) {
        let name = "Bridge NFT";
        let symbol = "BNFT";
        self.erc721.initializer(name, symbol,"");
        
        assert(bridge.is_non_zero(), Errors::INVALID_ADDRESS);
        self.bridge.write(bridge);
    }

    #[abi(embed_v0)]
    impl MintableNFTMock of super::IMintableNFT<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            self._assert_only_bridge();
            self.erc721.mint(to, token_id);
            self.emit(Minted { to, token_id });
        }

        fn burn(ref self: ContractState, token_id: u256) {
            self._assert_only_bridge();
            self.erc721.burn(token_id);
            self.emit(Burned { token_id });
        }

    

       

    

       

       

       
    }

    #[generate_trait]
    impl Internal of ITrait {
        fn _assert_only_bridge(self: @ContractState) {
            assert(get_caller_address() == self.bridge.read(), Errors::UNAUTHORIZED);
        }
    }
}