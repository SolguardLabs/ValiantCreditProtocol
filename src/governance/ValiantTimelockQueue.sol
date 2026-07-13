// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ValiantAccess} from "../access/ValiantAccess.sol";

contract ValiantTimelockQueue is ValiantAccess {
    event OperationQueued(bytes32 indexed id, address indexed target, uint256 value, uint256 executeAfter);
    event OperationCancelled(bytes32 indexed id);
    event OperationExecuted(bytes32 indexed id, address indexed target, uint256 value);

    struct Operation {
        address target;
        uint256 value;
        bytes data;
        uint64 executeAfter;
        bool active;
        bool executed;
    }

    uint256 public minDelay;
    uint256 public maxDelay;
    mapping(bytes32 => Operation) public operations;

    constructor(address initialOwner, uint256 minDelay_, uint256 maxDelay_) ValiantAccess(initialOwner) {
        require(minDelay_ <= maxDelay_, "DELAY_RANGE");
        minDelay = minDelay_;
        maxDelay = maxDelay_;
    }

    receive() external payable {}

    function setDelays(uint256 minDelay_, uint256 maxDelay_) external onlyOwner {
        require(minDelay_ <= maxDelay_, "DELAY_RANGE");
        require(maxDelay_ <= 30 days, "MAX_DELAY");
        minDelay = minDelay_;
        maxDelay = maxDelay_;
    }

    function hashOperation(address target, uint256 value, bytes calldata data, bytes32 salt)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(target, value, keccak256(data), salt));
    }

    function queue(address target, uint256 value, bytes calldata data, bytes32 salt, uint256 delay)
        external
        onlyRiskAdmin
        returns (bytes32 id)
    {
        require(target != address(0), "TARGET_ZERO");
        require(delay >= minDelay && delay <= maxDelay, "DELAY");
        id = hashOperation(target, value, data, salt);
        require(!operations[id].active, "ACTIVE");
        operations[id] = Operation({
            target: target,
            value: value,
            data: data,
            executeAfter: uint64(block.timestamp + delay),
            active: true,
            executed: false
        });
        emit OperationQueued(id, target, value, block.timestamp + delay);
    }

    function cancel(bytes32 id) external onlyRiskAdmin {
        Operation storage op = operations[id];
        require(op.active && !op.executed, "NOT_PENDING");
        delete operations[id];
        emit OperationCancelled(id);
    }

    function execute(bytes32 id) external payable onlyKeeper returns (bytes memory result) {
        Operation storage op = operations[id];
        require(op.active && !op.executed, "NOT_PENDING");
        require(block.timestamp >= op.executeAfter, "TIMELOCK");
        op.executed = true;
        op.active = false;
        (bool success, bytes memory data) = op.target.call{value: op.value}(op.data);
        require(success, "CALL_FAILED");
        emit OperationExecuted(id, op.target, op.value);
        return data;
    }

    function ready(bytes32 id) external view returns (bool) {
        Operation memory op = operations[id];
        return op.active && !op.executed && block.timestamp >= op.executeAfter;
    }

    function eta(bytes32 id) external view returns (uint256) {
        return operations[id].executeAfter;
    }
}
