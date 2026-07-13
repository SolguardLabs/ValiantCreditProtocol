// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ValiantAccess} from "../access/ValiantAccess.sol";
import {ValiantTypes} from "../libraries/ValiantTypes.sol";

contract ValiantConfigurator is ValiantAccess {
    event ParameterUpdateQueued(bytes32 indexed id, uint256 executableAt);
    event ParameterUpdateCancelled(bytes32 indexed id);
    event ParameterUpdateExecuted(bytes32 indexed id);

    struct PendingUpdate {
        ValiantTypes.MarketConfig config;
        uint64 executableAt;
        bool active;
    }

    uint256 public minDelay;
    mapping(bytes32 => PendingUpdate) public updates;

    constructor(address initialOwner, uint256 delay) ValiantAccess(initialOwner) {
        minDelay = delay;
    }

    function setMinDelay(uint256 delay) external onlyOwner {
        require(delay <= 14 days, "DELAY_HIGH");
        minDelay = delay;
    }

    function queue(ValiantTypes.MarketConfig calldata config, bytes32 salt) external onlyRiskAdmin returns (bytes32 id) {
        id = keccak256(abi.encode(config, salt));
        require(!updates[id].active, "ACTIVE");
        updates[id] = PendingUpdate({config: config, executableAt: uint64(block.timestamp + minDelay), active: true});
        emit ParameterUpdateQueued(id, block.timestamp + minDelay);
    }

    function cancel(bytes32 id) external onlyRiskAdmin {
        require(updates[id].active, "NOT_ACTIVE");
        delete updates[id];
        emit ParameterUpdateCancelled(id);
    }

    function consume(bytes32 id) external onlyRiskAdmin returns (ValiantTypes.MarketConfig memory config) {
        PendingUpdate memory update = updates[id];
        require(update.active, "NOT_ACTIVE");
        require(block.timestamp >= update.executableAt, "TIMELOCK");
        delete updates[id];
        emit ParameterUpdateExecuted(id);
        return update.config;
    }
}
