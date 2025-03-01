use snforge_std::DeclareResultTrait;
use snforge_std::{declare, ContractClassTrait};
use ticket1::claim::IClaimDispatcherTrait;
use ticket1::claim::IClaimDispatcher;

#[test]
fn test_valid_merkle_proof() {
    let contract_class = declare("ClaimStarknet").unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@array![]).unwrap();
    let dispatcher = IClaimDispatcher { contract_address };

    let merkleroot = 0x013acf21af3104a9c586a2fe3fab13e0dd8de43400adc068ce0894e558419923;
    // Set a known merkleRoot (e.g., from your test tree)
    dispatcher.updateMerkleRoot(merkleroot);
    let root = dispatcher.getMerkleRoot();
    assert_eq!(root, merkleroot, "Merkle root should be set");
    // Test with a valid proof for a user and allocation
    let proof = array![
        0x01a8b0aaf4f3f38bad53007ed4be1f72878aafd22ca9d989cc4b4d754065811a,
        0x058e50b7ed0cc4e9929b3dc1318e0fe24c7ea05d889007f98a8e2ff389f08e97,
    ]
        .span();
    let user = 0x07a53e16d8E8D7d4F8981AAE00F65dDC220f9deA62918c2e63E4670C89f60ED4;
    let is_valid = dispatcher.isValidClaim(user.try_into().unwrap(), 0x16345785d8a0000, proof);
    assert!(is_valid, "Valid proof should return true");
}
// #[test]
// fn test_invalid_merkle_proof() {
//     let contract_class = declare("ClaimStarknet").unwrap();
//     let (contract_address, _) = contract_class.deploy(@array![]).unwrap();
//     let dispatcher = IClaimDispatcher { contract_address };

//     // Set a known merkleRoot
//     dispatcher.updateMerkleRoot(/* known root */);

//     // Test with an invalid proof
//     let proof = array![/* invalid proof nodes as felt252 */].span();
//     let is_valid = dispatcher.isValidClaim(/* user, allocation, proof */);
//     assert!(!is_valid, "Invalid proof should return false");
// }


