// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ValiantSettlementJournal {
    event EntryPosted(bytes32 indexed id, address indexed account, uint8 kind, uint256 amount);
    event EntryVoided(bytes32 indexed id, address indexed account);
    event AccountClosed(address indexed account, uint256 closingBalance);

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

    address public immutable market;

    mapping(bytes32 => Entry) public entries;
    mapping(address => uint256) public debitBalance;
    mapping(address => uint256) public creditBalance;
    mapping(address => bytes32[]) internal _accountEntries;

    modifier onlyMarket() {
        require(msg.sender == market, "ONLY_MARKET");
        _;
    }

    constructor(address market_) {
        require(market_ != address(0), "MARKET_ZERO");
        market = market_;
    }

    function post(
        address account,
        address counterparty,
        uint256 amount,
        EntryKind kind,
        bytes32 salt
    ) external onlyMarket returns (bytes32 id) {
        require(account != address(0), "ACCOUNT_ZERO");
        require(amount != 0, "AMOUNT_ZERO");
        id = keccak256(abi.encode(account, counterparty, amount, kind, salt, block.number));
        require(!entries[id].active, "ENTRY_ACTIVE");
        entries[id] = Entry({
            account: account,
            counterparty: counterparty,
            amount: amount,
            postedAt: uint64(block.timestamp),
            kind: kind,
            active: true
        });
        _accountEntries[account].push(id);
        if (_isDebit(kind)) debitBalance[account] += amount;
        else creditBalance[account] += amount;
        emit EntryPosted(id, account, uint8(kind), amount);
    }

    function voidEntry(bytes32 id) external onlyMarket {
        Entry storage entry = entries[id];
        require(entry.active, "ENTRY");
        entry.active = false;
        if (_isDebit(entry.kind)) {
            debitBalance[entry.account] = entry.amount >= debitBalance[entry.account]
                ? 0
                : debitBalance[entry.account] - entry.amount;
        } else {
            creditBalance[entry.account] = entry.amount >= creditBalance[entry.account]
                ? 0
                : creditBalance[entry.account] - entry.amount;
        }
        emit EntryVoided(id, entry.account);
    }

    function netBalance(address account) external view returns (int256) {
        uint256 credit = creditBalance[account];
        uint256 debit = debitBalance[account];
        if (credit >= debit) return int256(credit - debit);
        return -int256(debit - credit);
    }

    function accountEntries(address account) external view returns (bytes32[] memory out) {
        bytes32[] storage stored = _accountEntries[account];
        out = new bytes32[](stored.length);
        for (uint256 i = 0; i < stored.length; i++) {
            out[i] = stored[i];
        }
    }

    function accountEntriesSlice(address account, uint256 start, uint256 count) external view returns (bytes32[] memory out) {
        bytes32[] storage stored = _accountEntries[account];
        if (start >= stored.length) return new bytes32[](0);
        uint256 end = start + count;
        if (end > stored.length) end = stored.length;
        out = new bytes32[](end - start);
        for (uint256 i = start; i < end; i++) {
            out[i - start] = stored[i];
        }
    }

    function _isDebit(EntryKind kind) internal pure returns (bool) {
        return kind == EntryKind.Withdrawal || kind == EntryKind.Borrow || kind == EntryKind.LiquidationSeize
            || kind == EntryKind.ReserveSweep;
    }
}
