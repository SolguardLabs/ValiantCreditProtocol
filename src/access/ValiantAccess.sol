// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ValiantAccess {
    event OwnershipTransferStarted(address indexed previousOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RiskAdminUpdated(address indexed account, bool enabled);
    event KeeperUpdated(address indexed account, bool enabled);

    address public owner;
    address public pendingOwner;

    mapping(address => bool) public riskAdmins;
    mapping(address => bool) public keepers;

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    modifier onlyRiskAdmin() {
        require(msg.sender == owner || riskAdmins[msg.sender], "ONLY_RISK_ADMIN");
        _;
    }

    modifier onlyKeeper() {
        require(msg.sender == owner || keepers[msg.sender], "ONLY_KEEPER");
        _;
    }

    constructor(address initialOwner) {
        require(initialOwner != address(0), "OWNER_ZERO");
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "OWNER_ZERO");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "ONLY_PENDING_OWNER");
        address previous = owner;
        owner = msg.sender;
        pendingOwner = address(0);
        emit OwnershipTransferred(previous, msg.sender);
    }

    function setRiskAdmin(address account, bool enabled) external onlyOwner {
        require(account != address(0), "ACCOUNT_ZERO");
        riskAdmins[account] = enabled;
        emit RiskAdminUpdated(account, enabled);
    }

    function setKeeper(address account, bool enabled) external onlyOwner {
        require(account != address(0), "ACCOUNT_ZERO");
        keepers[account] = enabled;
        emit KeeperUpdated(account, enabled);
    }
}
