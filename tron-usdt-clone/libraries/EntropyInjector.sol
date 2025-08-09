// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title EntropyInjector
 * @dev Library for injecting entropy into calculations and state
 */
library EntropyInjector {
    /**
     * @dev Add entropy to a value based on block data
     */
    function addEntropy(uint256 value, uint256 seed) internal view returns (uint256) {
        uint256 entropy = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            block.number,
            tx.origin,
            gasleft(),
            seed
        )));
        
        return value ^ (entropy % (value + 1));
    }
    
    /**
     * @dev Generate entropic hash
     */
    function entropicHash(bytes memory data, uint256 nonce) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(
            data,
            block.timestamp,
            block.difficulty,
            blockhash(block.number - 1),
            nonce,
            gasleft()
        ));
    }
    
    /**
     * @dev Apply time-based entropy
     */
    function timeEntropy(uint256 value) internal view returns (uint256) {
        uint256 timeFactor = block.timestamp % 3600; // Hour-based entropy
        uint256 blockFactor = block.number % 100;
        
        return value + (timeFactor * blockFactor);
    }
    
    /**
     * @dev Generate pseudo-random number with entropy
     */
    function randomWithEntropy(uint256 max, uint256 seed) internal view returns (uint256) {
        uint256 random = uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            msg.sender,
            seed,
            block.timestamp,
            block.difficulty
        )));
        
        return random % max;
    }
    
    /**
     * @dev Inject entropy into address calculation
     */
    function entropicAddress(address base, uint256 nonce) internal pure returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(base, nonce));
        return address(uint160(uint256(hash)));
    }
    
    /**
     * @dev Create entropic signature
     */
    function entropicSignature(bytes32 message, uint256 entropy) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(message, entropy));
    }
}