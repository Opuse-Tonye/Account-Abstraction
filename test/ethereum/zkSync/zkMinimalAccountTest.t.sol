// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {zkMinimalAccount} from "src/ethereum/zksync/ZkMinimalAccount.sol"; 
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {
    Transaction, 
    MemoryTransactionHelper} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ZkMinimalAccountTest is Test{
    using MessageHashUtils for bytes32;
    zkMinimalAccount minimalAccount;
    ERC20Mock usdc;

    uint256 constant AMOUNT = 1e18;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address constant ANVIL_DEFAULT_ACCOUNT = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    function setUp() public {
        minimalAccount = new zkMinimalAccount();
        minimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdc = new ERC20Mock();
        vm.deal(address(minimalAccount), AMOUNT);
    }

    function testZkOwnerCanExecuteCommands() public {

        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), 
        AMOUNT);

        Transaction memory transaction = _createUnsignedtransaction(minimalAccount.owner(), 113, dest, value, functionData);

        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT, "USDC minting failed");
    }

    function testZkValidateTransaction() public {
        
        // Arrange 
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), 
        AMOUNT);

            Transaction memory transaction = _createUnsignedtransaction(minimalAccount.owner(), 113, dest, value, functionData);
        transaction = _signTransaction(transaction);

        // Debug logging
    // console.log("Returned magic:");
    // console.log("Expected magic:");
    // console.logBytes4(ACCOUNT_VALIDATION_SUCCESS_MAGIC);
        
        // Act 
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = minimalAccount.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
        // console.logBytes4(magic);
        
        // Assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    /*////////////////////////////////////////////////////
    |   |   |   |   |   HELPERS
    /////////////////////////////////////////////////////*/

    function _signTransaction(Transaction memory transaction) internal view returns(Transaction memory) {
            bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(transaction);
            // bytes32 digest = unsignedTransactionHash.toEthSignedMessageHash();
            uint8 v;
            bytes32 r;
            bytes32 s;
            uint256 ANVIL_DEFAULT_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, unsignedTransactionHash);
            Transaction memory signedTransaction = transaction;
            signedTransaction.signature = abi.encodePacked(r, s, v);
            return signedTransaction;
    }

    function _createUnsignedtransaction(
            address from,
            uint8 transactionType,
            address to,
            uint256 value,
            bytes memory data
        ) internal view returns(Transaction memory) {
            uint256 nonce = vm.getNonce(address(minimalAccount));
            bytes32[] memory factoryDeps = new bytes32[](0);
            return(Transaction({
                txType: transactionType, // Type 113 (0x71)
                from: uint256(uint160(from)),
                to: uint256(uint160(to)),
                gasLimit: 16777216,
                gasPerPubdataByteLimit: 16777216,
                maxFeePerGas: 16777216,
                maxPriorityFeePerGas: 16777216,
                paymaster: 0,
                nonce: nonce,
                value: value,
                reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
                data: data,
                signature: hex"",
                factoryDeps: factoryDeps,
                paymasterInput: hex"",
                reservedDynamic: hex""
            }));
        } 

}