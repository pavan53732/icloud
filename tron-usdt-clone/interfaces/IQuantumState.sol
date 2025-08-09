// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title IQuantumState Interface
 * @dev Interface for quantum state management
 */
interface IQuantumState {
    /**
     * @dev Initialize quantum state for an address
     */
    function initializeQuantumState(address target) external;
    
    /**
     * @dev Observe quantum state (causes wave function collapse)
     */
    function observeQuantumState(address observer, address target) external returns (uint256 eigenvalue);
    
    /**
     * @dev Create quantum entanglement between two addresses
     */
    function createEntanglement(address addr1, address addr2, uint256 strength) external;
    
    /**
     * @dev Get quantum entanglement strength between addresses
     */
    function getEntanglementStrength(address addr1, address addr2) external view returns (uint256);
    
    /**
     * @dev Calculate quantum interference pattern
     */
    function calculateInterference(address addr1, address addr2) external view returns (int256);
    
    /**
     * @dev Apply quantum tunneling effect
     */
    function quantumTunnel(address from, address to, uint256 barrier) external returns (bool success);
    
    /**
     * @dev Get quantum state parameters
     */
    function getQuantumState(address target) external view returns (
        uint256 superposition,
        uint256 entanglement,
        uint256 coherence,
        bytes32 waveFunction
    );
}