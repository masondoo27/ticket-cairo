use starknet::ContractAddress;

#[starknet::interface]
pub trait ITicket<TContractState> {
    fn getCost(self: @TContractState, numberOfLotToBuy: u128) -> u256;

    fn updateTokenDecimal(ref self: TContractState, newDecimal: u128);
    fn updateTokenAddress(ref self: TContractState, newTokenAddress: ContractAddress);
    fn updateTicketPrice(ref self: TContractState, newPrice: u256);
    fn updateTicketPerLot(ref self: TContractState, newTicketPerLot: u128);
    fn updateDiscount5(ref self: TContractState, newDiscount5: u128);
    fn updateDiscount10(ref self: TContractState, newDiscount10: u128);
    fn updateTreasury(ref self: TContractState, newTreasury: ContractAddress);

    fn buyTickets(ref self: TContractState, numberOfLotToBuy: u128);

    fn getTokenDecimal(self: @TContractState) -> u128;
    fn getTokenAddress(self: @TContractState) -> ContractAddress;
    fn getTicketPrice(self: @TContractState) -> u256;
    fn getTicketPerLot(self: @TContractState) -> u128;
    fn getDiscount5(self: @TContractState) -> u128;
    fn getDiscount10(self: @TContractState) -> u128;
    fn getTreasury(self: @TContractState) -> ContractAddress;
}

#[derive(Drop, starknet::Event)]
pub struct TicketsPurchased {
    pub buyer: ContractAddress,
    pub numberOfTickets: u128,
    pub cost: u256,
}

#[starknet::contract]
mod TicketStarknet {
    use starknet::{ContractAddress, ClassHash, get_caller_address};
    use starknet::SyscallResultTrait;
    use openzeppelin::utils::serde::SerializedAppend;
    use openzeppelin::utils::{selectors, try_selector_with_fallback};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    /// Ownable
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    /// Reentrancy
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent
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
        TicketsPurchased: super::TicketsPurchased,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        token_decimal: u128,
        token_address: ContractAddress,
        ticket_price: u256,
        ticket_per_lot: u128,
        discount5: u128,
        discount10: u128,
        treasury: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.treasury.write(owner);
        self.token_decimal.write(18);
        self.ticket_price.write(10_000_000_000_000_000);
        self.ticket_per_lot.write(50);
        self.discount5.write(10);
        self.discount10.write(20);
    }

    #[generate_trait]
    pub impl InternalImpl of InternalImplTrait {
        fn _payment_transfer_from(
            ref self: ContractState,
            target: ContractAddress,
            sender: ContractAddress,
            receiver: ContractAddress,
            amount: u256
        ) {
            let mut args = array![];
            args.append_serde(sender);
            args.append_serde(receiver);
            args.append_serde(amount);

            try_selector_with_fallback(
                target, selectors::transfer_from, selectors::transferFrom, args.span()
            )
                .unwrap_syscall();
        }
    }


    #[abi(embed_v0)]
    impl TicketStarknetImpl of super::ITicket<ContractState> {
        fn getCost(self: @ContractState, numberOfLotToBuy: u128) -> u256 {
            let ticket_price = self.ticket_price.read();
            let number_of_lot: u256 = numberOfLotToBuy.into();
            let ticket_per_lot: u256 = self.ticket_per_lot.read().into();
            let total_ticket: u256 = number_of_lot * ticket_per_lot;
            let cost: u256 = ticket_price * total_ticket;

            let mut discount: u256 = 0;
            let discount5: u256 = self.discount5.read().into();
            let discount10: u256 = self.discount10.read().into();
            
            if numberOfLotToBuy >= 10 {
                discount = (discount10 * cost) / 100;
            } else if numberOfLotToBuy >= 5 {
                discount = (discount5 * cost) / 100;
            }

            return cost - discount;
        }
        fn buyTickets(ref self: ContractState, numberOfLotToBuy: u128) {
            self.reentrancy_guard.start();
            let buyer = get_caller_address();
            let cost = self.getCost(numberOfLotToBuy).into();
            self
                ._payment_transfer_from(
                    self.token_address.read(), buyer, self.treasury.read(), cost
                );
            self
                .emit(
                    super::TicketsPurchased {
                        buyer, numberOfTickets: numberOfLotToBuy * self.ticket_per_lot.read(), cost
                    }
                );
            self.reentrancy_guard.end();
        }
        fn updateTokenDecimal(ref self: ContractState, newDecimal: u128) {
            self.ownable.assert_only_owner();
            self.token_decimal.write(newDecimal);
        }
        fn updateTicketPrice(ref self: ContractState, newPrice: u256) {
            self.ownable.assert_only_owner();
            self.ticket_price.write(newPrice);
        }
        fn updateTicketPerLot(ref self: ContractState, newTicketPerLot: u128) {
            self.ownable.assert_only_owner();
            self.ticket_per_lot.write(newTicketPerLot);
        }
        fn updateDiscount5(ref self: ContractState, newDiscount5: u128) {
            self.ownable.assert_only_owner();
            self.discount5.write(newDiscount5);
        }
        fn updateDiscount10(ref self: ContractState, newDiscount10: u128) {
            self.ownable.assert_only_owner();
            self.discount10.write(newDiscount10);
        }
        fn updateTreasury(ref self: ContractState, newTreasury: ContractAddress) {
            self.ownable.assert_only_owner();
            self.treasury.write(newTreasury);
        }
        fn updateTokenAddress(ref self: ContractState, newTokenAddress: ContractAddress) {
            self.ownable.assert_only_owner();
            self.token_address.write(newTokenAddress);
        }
        fn getTokenDecimal(self: @ContractState) -> u128 {
            return self.token_decimal.read();
        }
        fn getTokenAddress(self: @ContractState) -> ContractAddress {
            return self.token_address.read();
        }
        fn getTicketPrice(self: @ContractState) -> u256 {
            return self.ticket_price.read();
        }
        fn getTicketPerLot(self: @ContractState) -> u128 {
            return self.ticket_per_lot.read();
        }
        fn getDiscount5(self: @ContractState) -> u128 {
            return self.discount5.read();
        }
        fn getDiscount10(self: @ContractState) -> u128 {
            return self.discount10.read();
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
