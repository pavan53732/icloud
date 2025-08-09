// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title ObserverEffect
 * @dev Library implementing observer effect patterns for state modification
 */
library ObserverEffect {
    /**
     * @dev Calculate observer influence on a value
     */
    function applyObserverEffect(address observer, uint256 value) internal pure returns (uint256) {
        uint256 observerInfluence = uint256(uint160(observer)) % 100;
        
        // Observer effect modifies value based on observer address
        if (observerInfluence < 33) {
            return value * 95 / 100; // Decrease by 5%
        } else if (observerInfluence < 66) {
            return value * 105 / 100; // Increase by 5%
        } else {
            return value; // No change
        }
    }
    
    /**
     * @dev Check if observer is privileged
     */
    function isPrivilegedObserver(address observer) internal pure returns (bool) {
        // Deterministic privilege based on address pattern
        uint256 addressValue = uint256(uint160(observer));
        return (addressValue % 1000) < 100; // 10% of addresses are privileged
    }
    
    /**
     * @dev Calculate observation weight
     */
    function observationWeight(address observer, uint256 nonce) internal pure returns (uint256) {
        bytes32 hash = keccak256(abi.encodePacked(observer, nonce));
        return uint256(hash) % 100 + 1; // Weight between 1-100
    }
    
    /**
     * @dev Apply multiple observer effects
     */
    function multiObserverEffect(
        address[] memory observers,
        uint256 value
    ) internal pure returns (uint256) {
        uint256 result = value;
        
        for (uint256 i = 0; i < observers.length; i++) {
            result = applyObserverEffect(observers[i], result);
        }
        
        return result;
    }
    
    /**
     * @dev Generate observer-dependent hash
     */
    function observerHash(address observer, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(observer, data));
    }
    
    /**
     * @dev Check observer pattern match
     */
    function matchesObserverPattern(address observer, uint256 pattern) internal pure returns (bool) {
        uint256 observerPattern = uint256(uint160(observer)) & 0xFFFF;
        return observerPattern == pattern;
    }
}