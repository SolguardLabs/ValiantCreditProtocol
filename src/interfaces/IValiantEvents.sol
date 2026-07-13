// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IValiantEvents {
    event Deposited(address indexed account, address indexed receiver, uint256 amount);
    event Withdrawn(address indexed account, address indexed receiver, uint256 amount);
    event CreditDelegated(address indexed sponsor, address indexed delegate, uint256 limit, uint64 expiresAt);
    event CreditRevoked(address indexed sponsor, address indexed delegate);
    event ManagedCreditDelegated(
        address indexed sponsor, address indexed manager, address indexed borrower, uint256 limit, uint64 expiresAt
    );
    event ManagedCreditRevoked(address indexed sponsor, address indexed manager, address indexed borrower);
    event Borrowed(
        bytes32 indexed route,
        address indexed sponsor,
        address indexed borrower,
        address receiver,
        uint256 amount,
        bool managed
    );
    event Repaid(bytes32 indexed route, address indexed payer, address indexed borrower, uint256 amount);
    event Liquidated(
        address indexed sponsor,
        address indexed borrower,
        address indexed liquidator,
        uint256 repaid,
        uint256 seized
    );
    event Accrued(uint256 borrowIndex, uint256 interestAccrued, uint256 reservesAccrued);
}
