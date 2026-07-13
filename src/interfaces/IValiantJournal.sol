// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IValiantJournal {
    enum EntryKind {
        Deposit,
        Withdrawal,
        Borrow,
        Repay,
        LiquidationRepay,
        LiquidationSeize,
        ReserveAccrual,
        ReserveSweep
    }

    struct Entry {
        address account;
        address counterparty;
        uint256 amount;
        uint64 postedAt;
        EntryKind kind;
        bool active;
    }

    event EntryPosted(bytes32 indexed id, address indexed account, uint8 kind, uint256 amount);
    event EntryVoided(bytes32 indexed id, address indexed account);
    event AccountClosed(address indexed account, uint256 closingBalance);

    function market() external view returns (address);

    function entries(bytes32 id) external view returns (Entry memory);

    function debitBalance(address account) external view returns (uint256);

    function creditBalance(address account) external view returns (uint256);

    function post(address account, address counterparty, uint256 amount, EntryKind kind, bytes32 salt)
        external
        returns (bytes32 id);

    function voidEntry(bytes32 id) external;

    function netBalance(address account) external view returns (int256);

    function accountEntries(address account) external view returns (bytes32[] memory);
}
