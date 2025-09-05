//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";

contract SendPackedUserOp is Script{
    using MessageHashUtils for bytes32;
    function run() external {
        // HelperConfig helperConfig = new HelperConfig();
        // address dest = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        // uint256 value = 0;
        // bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, 0x9EA9b0cc1919def1A3CfAEF4F7A66eE3c36F86fC,  1e18);
        // bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);

        // PackedUserOperation memory userOp = generateSignedUserOperation(executeCallData, helperConfig.getConfig(), 0x03Ad95a54f02A40180D45D76789C448024145aaF);

        // PackedUserOperation[] memory ops = new PackedUserOperation[](1);

        // vm.startBroadcast();
        // IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, helperConfig.getConfig());
    }

    function generateSignedUserOperation(bytes memory callData, HelperConfig.NetworkConfig memory config, uint256 account, address minimalAccount) 
    public
    view
    returns(PackedUserOperation memory){
        // 1. Generate the signed Data
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, minimalAccount, nonce);
        // 2. Get the user OpHash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(account, digest); // .account here needs to have a private key encoded in your forge terminal
        userOp.signature = abi.encodePacked(r, s, v); // Note the order 
        return userOp;

        // 3. Sign it and return
    }

    function _generateUnsignedUserOperation(bytes memory callData, address sender, 
    uint256 nonce) 
    internal 
    pure 
    returns (PackedUserOperation memory) {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | uint256(callGasLimit)),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | uint256(maxFeePerGas)),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}