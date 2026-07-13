// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ValiantAccess} from "../access/ValiantAccess.sol";

contract ValiantPausable is ValiantAccess {
    event PauseStatusUpdated(bytes32 indexed action, bool paused);

    bytes32 public constant ACTION_GLOBAL = keccak256("GLOBAL");
    bytes32 public constant ACTION_SUPPLY = keccak256("SUPPLY");
    bytes32 public constant ACTION_BORROW = keccak256("BORROW");
    bytes32 public constant ACTION_REPAY = keccak256("REPAY");
    bytes32 public constant ACTION_LIQUIDATE = keccak256("LIQUIDATE");
    bytes32 public constant ACTION_DELEGATE = keccak256("DELEGATE");

    mapping(bytes32 => bool) public actionPaused;

    constructor(address initialOwner) ValiantAccess(initialOwner) {}

    modifier whenActionNotPaused(bytes32 action) {
        require(!actionPaused[ACTION_GLOBAL] && !actionPaused[action], "ACTION_PAUSED");
        _;
    }

    function setPaused(bytes32 action, bool paused) external onlyRiskAdmin {
        actionPaused[action] = paused;
        emit PauseStatusUpdated(action, paused);
    }
}
