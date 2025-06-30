// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract ASM20 {
    string public constant name = "ASM20";
    string public constant symbol = "ASM20";
    uint8 public constant decimals = 18;
    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;
    uint256 totalSupply_ = 1000000 * (10 ** decimals);
    address public admin;
    mapping(address => bool) private feeExempt;
    uint256 private buyTaxInit = 23;
    uint256 private buyTaxFinal = 0;
    uint256 private buyTaxReduceAt = 20;
    uint256 private buyCounter = 0;
    uint256 public maxWallet;
    bool public tradingEnabled;

    constructor() {
        assembly {
            let sender := caller()
            sstore(admin.slot, sender)
            mstore(0x0, sender)
            mstore(0x20, balances.slot)
            let balSlot := keccak256(0x0, 0x40)
            sstore(balSlot, sload(totalSupply_.slot))
            mstore(0x0, sender)
            mstore(0x20, feeExempt.slot)
            let feeSlot1 := keccak256(0x0, 0x40)
            sstore(feeSlot1, 1)
            mstore(0x0, address())
            mstore(0x20, feeExempt.slot)
            let feeSlot2 := keccak256(0x0, 0x40)
            sstore(feeSlot2, 1)
            let ts := sload(totalSupply_.slot)
            sstore(maxWallet.slot, div(ts, 50))
        }
    }

    function totalSupply() public view returns (uint256 result) {
        assembly {
            result := sload(totalSupply_.slot)
        }
    }

    function balanceOf(address tokenOwner) public view returns (uint256 result) {
        assembly {
            mstore(0x0, tokenOwner)
            mstore(0x20, balances.slot)
            let slot := keccak256(0x0, 0x40)
            result := sload(slot)
        }
    }

    function openTrading() public {
        assembly {
            if iszero(eq(caller(), sload(admin.slot))) { revert(0, 0) }
            sstore(tradingEnabled.slot, 1)
        }
    }

    function transfer(address recipient, uint256 amount) public returns (bool ret) {
        assembly {
            let sender := caller()
            let adminAddr := sload(admin.slot)
            if iszero(sload(tradingEnabled.slot)) {
                if iszero(or(eq(sender, adminAddr), eq(recipient, adminAddr))) { revert(0, 0) }
            }
            mstore(0x0, sender)
            mstore(0x20, feeExempt.slot)
            let senderEx := sload(keccak256(0x0, 0x40))
            mstore(0x0, recipient)
            mstore(0x20, feeExempt.slot)
            let recipientEx := sload(keccak256(0x0, 0x40))
            mstore(0x0, sender)
            mstore(0x20, balances.slot)
            let senderSlot := keccak256(0x0, 0x40)
            let senderBal := sload(senderSlot)
            if lt(senderBal, amount) { revert(0, 0) }
            if iszero(or(senderEx, recipientEx)) {
                mstore(0x0, recipient)
                mstore(0x20, balances.slot)
                let recipientSlot := keccak256(0x0, 0x40)
                let recipientBal := sload(recipientSlot)
                let newBal := add(recipientBal, amount)
                let maxWalletVal := sload(maxWallet.slot)
                if gt(newBal, maxWalletVal) { revert(0, 0) }
            }
            let taxAmt := 0
            let netAmt := amount
            if iszero(or(senderEx, recipientEx)) {
                let buyTax := sload(buyTaxInit.slot)
                let buyCnt := sload(buyCounter.slot)
                let reduceAt := sload(buyTaxReduceAt.slot)
                let finalTax := sload(buyTaxFinal.slot)
                if gt(buyCnt, reduceAt) {
                    buyTax := finalTax
                }
                taxAmt := div(mul(amount, buyTax), 100)
                netAmt := sub(amount, taxAmt)
                sstore(buyCounter.slot, add(buyCnt, 1))
            }
            sstore(senderSlot, sub(senderBal, amount))
            mstore(0x0, recipient)
            mstore(0x20, balances.slot)
            let recipientSlot2 := keccak256(0x0, 0x40)
            let recipientBal2 := sload(recipientSlot2)
            sstore(recipientSlot2, add(recipientBal2, netAmt))
            if gt(taxAmt, 0) {
                mstore(0x0, adminAddr)
                mstore(0x20, balances.slot)
                let adminSlot := keccak256(0x0, 0x40)
                let adminBal := sload(adminSlot)
                sstore(adminSlot, add(adminBal, taxAmt))
                mstore(0x0, taxAmt)
                log3(0x0, 0x20, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, sender, adminAddr)
            }
            mstore(0x0, netAmt)
            log3(0x0, 0x20, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, sender, recipient)
            ret := 1
        }
    }

    function approve(address delegate, uint256 numTokens) public returns (bool success) {
        assembly {
            mstore(0x0, caller())
            mstore(0x20, delegate)
            mstore(0x40, allowed.slot)
            let slot := keccak256(0x0, 0x60)
            sstore(slot, numTokens)
            mstore(0x0, numTokens)
            log3(0x0, 0x20, 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925, caller(), delegate)
            success := 1
        }
    }

    function allowance(address owner, address delegate) public view returns (uint result) {
        assembly {
            mstore(0x0, owner)
            mstore(0x20, delegate)
            mstore(0x40, allowed.slot)
            let slot := keccak256(0x0, 0x60)
            result := sload(slot)
        }
    }

    function transferFrom(address src, address dst, uint256 amount) public returns (bool ret) {
        assembly {
            let spender := caller()
            let adminAddr := sload(admin.slot)
            if iszero(sload(tradingEnabled.slot)) {
                if iszero(or(eq(src, adminAddr), eq(dst, adminAddr))) { revert(0, 0) }
            }
            mstore(0x0, src)
            mstore(0x20, feeExempt.slot)
            let srcEx := sload(keccak256(0x0, 0x40))
            mstore(0x0, dst)
            mstore(0x20, feeExempt.slot)
            let dstEx := sload(keccak256(0x0, 0x40))
            mstore(0x0, src)
            mstore(0x20, balances.slot)
            let srcSlot := keccak256(0x0, 0x40)
            let srcBal := sload(srcSlot)
            if lt(srcBal, amount) { revert(0, 0) }
            mstore(0x0, src)
            mstore(0x20, spender)
            mstore(0x40, allowed.slot)
            let allowSlot := keccak256(0x0, 0x60)
            let allowBal := sload(allowSlot)
            if lt(allowBal, amount) { revert(0, 0) }
            let taxAmt := 0
            let netAmt := amount
            if iszero(or(srcEx, dstEx)) {
                let buyTax := sload(buyTaxInit.slot)
                let buyCnt := sload(buyCounter.slot)
                let reduceAt := sload(buyTaxReduceAt.slot)
                let finalTax := sload(buyTaxFinal.slot)
                if gt(buyCnt, reduceAt) {
                    buyTax := finalTax
                }
                taxAmt := div(mul(amount, buyTax), 100)
                netAmt := sub(amount, taxAmt)
                sstore(buyCounter.slot, add(buyCnt, 1))
            }
            sstore(srcSlot, sub(srcBal, amount))
            sstore(allowSlot, sub(allowBal, amount))
            mstore(0x0, dst)
            mstore(0x20, balances.slot)
            let dstSlot := keccak256(0x0, 0x40)
            let dstBal := sload(dstSlot)
            sstore(dstSlot, add(dstBal, netAmt))
            if gt(taxAmt, 0) {
                mstore(0x0, adminAddr)
                mstore(0x20, balances.slot)
                let adminSlot := keccak256(0x0, 0x40)
                let adminBal := sload(adminSlot)
                sstore(adminSlot, add(adminBal, taxAmt))
                mstore(0x0, taxAmt)
                log3(0x0, 0x20, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, src, adminAddr)
            }
            mstore(0x0, netAmt)
            log3(0x0, 0x20, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, src, dst)
            ret := 1
        }
    }

    function renounceOwnership() public {
        assembly {
            if iszero(eq(caller(), sload(admin.slot))) { revert(0, 0) }
            sstore(admin.slot, 0)
        }
    }

    function removeLimits() public {
        assembly {
            if iszero(eq(caller(), sload(admin.slot))) { revert(0, 0) }
            sstore(maxWallet.slot, sload(totalSupply_.slot))
        }
    }
}