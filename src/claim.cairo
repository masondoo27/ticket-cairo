use starknet::ContractAddress;

#[starknet::interface]
pub trait IClaim<TContractState> {
    fn claim(
        ref self: TContractState,
        user: ContractAddress,
        allocation: u256,
        merkleProof: Span<felt252>,
    );

    fn updateTokenAddress(ref self: TContractState, newTokenAddress: ContractAddress);
    fn updateTreasury(ref self: TContractState, newTreasury: ContractAddress);
    fn updateMerkleRoot(ref self: TContractState, newMerkleroot: felt252);
    fn updateStartAt(ref self: TContractState, newStartAt: u256);
    fn updateEndAt(ref self: TContractState, newEndAt: u256);

    fn withdraw(ref self: TContractState, amount: u256);

    fn getTokenAddress(self: @TContractState) -> ContractAddress;
    fn getTreasury(self: @TContractState) -> ContractAddress;
    fn getMerkleRoot(self: @TContractState) -> felt252;
    fn getStartAt(self: @TContractState) -> u256;
    fn getEndAt(self: @TContractState) -> u256;
    fn isClaimed(self: @TContractState, address: ContractAddress) -> bool;
    fn getTotalClaim(self: @TContractState) -> u256;
    fn getUserCount(self: @TContractState) -> u256;

    fn isValidClaim(
        self: @TContractState, user: ContractAddress, allocation: u256, merkleProof: Span<felt252>,
    ) -> bool;
}


#[starknet::contract]
mod ClaimStarknet {
    use core::hash::HashStateTrait;
    use core::hash::HashStateExTrait;
    use starknet::{ContractAddress, ClassHash, get_block_timestamp, get_contract_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::merkle_tree::hashes::{PedersenCHasher, PoseidonCHasher};
    use core::pedersen::{PedersenTrait, pedersen};
    use openzeppelin::merkle_tree::merkle_proof::{verify};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map};
    // use starknet::{
    //     get_caller_address, get_contract_address, get_tx_info, ContractAddress,
    //     get_block_timestamp,
    // };
    /// Ownable
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    /// Reentrancy
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent,
    );
    /// Upgradeable
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    /// Ownable
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    /// Reentrancy
    impl ReentrancyInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;
    /// Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        treasury: ContractAddress,
        rootWhitelist: felt252,
        token_address: ContractAddress,
        userClaimed: Map<ContractAddress, bool>,
        startAt: u256,
        endAt: u256,
        totalClaim: u256,
        userCount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.treasury.write(owner);
        self.startAt.write(0);
        self.endAt.write(0);
        self.totalClaim.write(0);
        self.userCount.write(0);
    }

    #[generate_trait]
    pub impl InternalImpl of InternalImplTrait {
        fn _payment_transfer_from(
            ref self: ContractState,
            target: ContractAddress,
            sender: ContractAddress,
            receiver: ContractAddress,
            amount: u256,
        ) {
            let token_dispatcher = IERC20Dispatcher { contract_address: target };
            token_dispatcher.transfer_from(sender, receiver, amount);
        }
    }

    fn verify_merkle_proof(
        merkleRoot: felt252, merkleProof: Span<felt252>, minter: ContractAddress, amount: u256,
    ) -> bool {
        let hash_state = PedersenTrait::new(0);
        let leaf_hash = pedersen(0, hash_state.update_with(minter).update_with(amount).finalize());
        return verify::<PedersenCHasher>(merkleProof, merkleRoot, leaf_hash);
    }

    #[abi(embed_v0)]
    impl ClaimStarknetImpl of super::IClaim<ContractState> {
        fn isValidClaim(
            self: @ContractState,
            user: ContractAddress,
            allocation: u256,
            merkleProof: Span<felt252>,
        ) -> bool {
            let merkleRoot = self.rootWhitelist.read();
            return verify_merkle_proof(merkleRoot, merkleProof, user, allocation);
        }

        fn withdraw(ref self: ContractState, amount: u256) {
            self.ownable.assert_only_owner();
            self
                ._payment_transfer_from(
                    self.token_address.read(), get_contract_address(), self.treasury.read(), amount,
                );
        }

        fn updateTokenAddress(ref self: ContractState, newTokenAddress: ContractAddress) {
            self.ownable.assert_only_owner();
            self.token_address.write(newTokenAddress);
        }
        fn getTokenAddress(self: @ContractState) -> ContractAddress {
            return self.token_address.read();
        }

        fn claim(
            ref self: ContractState,
            user: ContractAddress,
            allocation: u256,
            merkleProof: Span<felt252>,
        ) {
            // verifid startat
            let startAt = self.startAt.read();
            assert!(startAt != 0);
            assert!(startAt <= get_block_timestamp().into());

            // verify endat
            let endAt = self.endAt.read();
            assert!(endAt != 0);
            assert!(endAt >= get_block_timestamp().into());

            let merkleRoot = self.rootWhitelist.read();
            assert!(verify_merkle_proof(merkleRoot, merkleProof, user, allocation));

            let claimed = self.userClaimed.read(user);
            assert!(!claimed);
            self.userClaimed.write(user, true);

            self
                ._payment_transfer_from(
                    self.token_address.read(), self.treasury.read(), user, allocation,
                );

            self.totalClaim.write(self.totalClaim.read() + allocation);
            self.userCount.write(self.userCount.read() + 1);
        }

        fn updateStartAt(ref self: ContractState, newStartAt: u256) {
            self.ownable.assert_only_owner();
            self.startAt.write(newStartAt);
        }
        fn getStartAt(self: @ContractState) -> u256 {
            return self.startAt.read();
        }

        fn updateEndAt(ref self: ContractState, newEndAt: u256) {
            self.ownable.assert_only_owner();
            self.endAt.write(newEndAt);
        }
        fn getEndAt(self: @ContractState) -> u256 {
            return self.endAt.read();
        }

        fn updateMerkleRoot(ref self: ContractState, newMerkleroot: felt252) {
            self.ownable.assert_only_owner();
            self.rootWhitelist.write(newMerkleroot);
        }
        fn getMerkleRoot(self: @ContractState) -> felt252 {
            return self.rootWhitelist.read();
        }

        fn isClaimed(self: @ContractState, address: ContractAddress) -> bool {
            return self.userClaimed.read(address);
        }

        fn getTotalClaim(self: @ContractState) -> u256 {
            return self.totalClaim.read();
        }

        fn getUserCount(self: @ContractState) -> u256 {
            return self.userCount.read();
        }

        fn updateTreasury(ref self: ContractState, newTreasury: ContractAddress) {
            self.ownable.assert_only_owner();
            self.treasury.write(newTreasury);
        }
        fn getTreasury(self: @ContractState) -> ContractAddress {
            return self.treasury.read();
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            // Replace the class hash upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
