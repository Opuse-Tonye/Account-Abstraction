//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfig is Script{
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPoint;
        address account;
        uint256 privateKey;
    }

    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337;
    address constant BURNER_WALLET = 0xb8d18B3395C2eAEE141d3B85900d6efDb1E8B240;
    address constant FOUNDRY_DEFAULT_WALLET = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;//0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    NetworkConfig public localNetworkConfig;
    mapping (uint256 chainId => NetworkConfig) public networkConfigs;
    // Official Sepolia EntryPoint address: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789

    constructor(){
        networkConfigs [ETH_SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    function getConfig() public returns (NetworkConfig memory){
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns(NetworkConfig memory){
        if(chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainId].account != address(0)){
            return networkConfigs[chainId];
        }  else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaConfig() public view returns(NetworkConfig memory) {
        uint256 privateKey = vm.envUint("ACCOUNT_PRIVATE_KEY");
        return NetworkConfig({entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, account: BURNER_WALLET, privateKey: privateKey});
    }

    function getZksyncSepoliaConfig() public view returns(NetworkConfig memory) {
        uint256 privateKey = vm.envUint("ACCOUNT_PRIVATE_KEY");
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET, privateKey: privateKey});
    }

    function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory) {
        if(localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(privateKey); // ✅ Use private key, not address
        console2.log("Deploying Mocks...");
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entryPoint: address(entryPoint), 
            account: FOUNDRY_DEFAULT_WALLET,
            privateKey: privateKey // Add the private key field
        });

    return localNetworkConfig;

        // deploy mocks
        // vm.startBroadcast(FOUNDRY_DEFAULT_WALLET);
        // console2.log("Deploying Mocks...");
        // EntryPoint entryPoint = new EntryPoint();
        // vm.stopBroadcast();


    // return NetworkConfig({entryPoint: address(entryPoint), account: FOUNDRY_DEFAULT_WALLET});
    }
}