// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "../interfaces/IERC20.sol";
import {SafeTransferLib} from "../libraries/SafeTransferLib.sol";

contract ValiantReserveEscrow {
    using SafeTransferLib for IERC20;

    event DepositRecorded(address indexed asset, address indexed source, uint256 amount);
    event WithdrawalQueued(bytes32 indexed id, address indexed asset, address indexed receiver, uint256 amount);
    event WithdrawalCancelled(bytes32 indexed id);
    event WithdrawalExecuted(bytes32 indexed id, address indexed receiver, uint256 amount);

    struct Withdrawal {
        IERC20 asset;
        address receiver;
        uint256 amount;
        uint64 executableAt;
        bool active;
    }

    address public owner;
    uint256 public delay;
    mapping(bytes32 => Withdrawal) public withdrawals;

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    constructor(address owner_, uint256 delay_) {
        require(owner_ != address(0), "OWNER_ZERO");
        owner = owner_;
        delay = delay_;
    }

    function recordDeposit(IERC20 asset, uint256 amount) external {
        asset.safeTransferFrom(msg.sender, address(this), amount);
        emit DepositRecorded(address(asset), msg.sender, amount);
    }

    function queueWithdrawal(IERC20 asset, address receiver, uint256 amount, bytes32 salt)
        external
        onlyOwner
        returns (bytes32 id)
    {
        require(receiver != address(0), "RECEIVER_ZERO");
        id = keccak256(abi.encode(asset, receiver, amount, salt));
        require(!withdrawals[id].active, "ACTIVE");
        withdrawals[id] = Withdrawal({
            asset: asset,
            receiver: receiver,
            amount: amount,
            executableAt: uint64(block.timestamp + delay),
            active: true
        });
        emit WithdrawalQueued(id, address(asset), receiver, amount);
    }

    function cancelWithdrawal(bytes32 id) external onlyOwner {
        require(withdrawals[id].active, "NOT_ACTIVE");
        delete withdrawals[id];
        emit WithdrawalCancelled(id);
    }

    function executeWithdrawal(bytes32 id) external {
        Withdrawal memory withdrawal = withdrawals[id];
        require(withdrawal.active, "NOT_ACTIVE");
        require(block.timestamp >= withdrawal.executableAt, "TIMELOCK");
        delete withdrawals[id];
        withdrawal.asset.safeTransfer(withdrawal.receiver, withdrawal.amount);
        emit WithdrawalExecuted(id, withdrawal.receiver, withdrawal.amount);
    }
}
