// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {
    IAccount, 
    ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {
    Transaction, 
    MemoryTransactionHelper} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {INonceHolder} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import {Utils} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract zkMinimalAccount is Ownable{
    using MemoryTransactionHelper for Transaction;

    /*////////////////////////////////////////////////////
    |   |   |   |   |   ERRORS
    /////////////////////////////////////////////////////*/

    error zkMinimalAccount__NotEnoughBalance();
    error zkMinimalAccount__NotFromBootLoader();
    error ZKMinimalAccount__ExecutionFailed();
    error zkMinimalAccount__NotFromBootLoaderOrOwner();
    error ZKMinimalAccount__FailedToPay();
    error ZkMinimalAccount__InvalidSignature();

    /*////////////////////////////////////////////////////
    |   |   |   |   |   MODIFIERS
    /////////////////////////////////////////////////////*/

    modifier requireFromBootLoader {
        if(msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert zkMinimalAccount__NotFromBootLoader();
        }
        _;
    }

    modifier requireFromBootLoaderOrOwner {
        if(msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert zkMinimalAccount__NotFromBootLoaderOrOwner();
        }
        _;
    }

    constructor() Ownable(msg.sender){}

    receive() external payable {}

    /*////////////////////////////////////////////////////
    |   |   |   |   |   EXTERNAL FUNCTIONS
    /////////////////////////////////////////////////////*/

    /**
     * @notice Must increase the nonce 
     * @notice Must validate the transaction (Check the owner signed the transaction) 
     * @notice Also check to see if we have enough money in our account.
     */

    function validateTransaction(bytes32, /*_txHash,*/ bytes32 /*_suggestedSignedHash*/, Transaction memory _transaction)
        external
        payable
        requireFromBootLoader
        returns (bytes4 magic)
        {
            return _validateTransaction(_transaction);
        }

    function executeTransaction(bytes32 /*_txHash*/, bytes32 /*_suggestedSignedHash*/, Transaction memory _transaction)
        external
        payable
        requireFromBootLoaderOrOwner
        {
            _executeTransaction(_transaction);   
        }

    
    function executeTransactionFromOutside(Transaction memory _transaction) external payable
    {
        bytes4 magic = _validateTransaction(_transaction);
        if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC){
            revert ZkMinimalAccount__InvalidSignature();
        }
        _executeTransaction(_transaction);
    }

    function payForTransaction(bytes32 /*_txHash*/, bytes32 /*_suggestedSignedHash*/, Transaction memory _transaction)
        external
        payable
        {
            bool success = _transaction.payToTheBootloader();
            if (!success){
                revert ZKMinimalAccount__FailedToPay();
            }
        }

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
        external
        payable
        {}

    /*////////////////////////////////////////////////////
    |   |   |   |   |   INTERNAL FUNCTIONS
    /////////////////////////////////////////////////////*/

    function _validateTransaction(Transaction memory _transaction) internal returns(bytes4 magic) {
        // PHASE 1 SYSTEM CONTRACT TRANSACTION SIMULATOR
            // Call nonce holder
            // increment nonce
            // call(x, y, z) -> system contract call
            SystemContractsCaller.systemCallWithPropagatedRevert(
                uint32(gasleft()),
                address(NONCE_HOLDER_SYSTEM_CONTRACT),
                0,
                abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
            );

            // PHASE 2 VALIDATE TRANSACTION
            // Check for fee to pay
            uint256 totalRequireBalance = _transaction.totalRequiredBalance();
            if(totalRequireBalance > address(this).balance){
                revert zkMinimalAccount__NotEnoughBalance();
            }

            // Check the signature
            bytes32 txHash = _transaction.encodeHash();
            // bytes32 digest = MessageHashUtils.toEthSignedMessageHash(txHash);
            address signer = ECDSA.recover(txHash, _transaction.signature);
            bool isValidSigner = signer == owner();
            if (isValidSigner){
                magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
            } else {
                magic = bytes4(0);
            }
            // Return the magic number 
            return magic;
    }

    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to));
            uint128 value = Utils.safeCastToU128(_transaction.value);
            bytes memory data = _transaction.data;

            if(to == address(DEPLOYER_SYSTEM_CONTRACT)) {
                 uint32 gas = Utils.safeCastToU32(gasleft());
                 SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
            } else {
                bool success;
                assembly {
                    success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
                }
                if(!success){
                    revert ZKMinimalAccount__ExecutionFailed();
                }
            }
    }

}