// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IValiantProtocol} from "../interfaces/IValiantProtocol.sol";
import {ValiantTypes} from "../libraries/ValiantTypes.sol";

contract ValiantKeeperRouter {
    event CandidateChecked(address indexed sponsor, address indexed borrower, bool liquidatable, uint256 repay);
    event LiquidationForwarded(address indexed protocol, address indexed sponsor, address indexed borrower, uint256 repay);

    struct Candidate {
        address sponsor;
        address borrower;
        uint256 desiredRepay;
    }

    struct CheckResult {
        address sponsor;
        address borrower;
        bool liquidatable;
        uint256 repayAmount;
        uint256 healthFactor;
        uint256 seizeAmount;
    }

    address public owner;
    mapping(address => bool) public executors;

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    modifier onlyExecutor() {
        require(msg.sender == owner || executors[msg.sender], "ONLY_EXECUTOR");
        _;
    }

    constructor(address owner_) {
        require(owner_ != address(0), "OWNER_ZERO");
        owner = owner_;
    }

    function setExecutor(address executor, bool enabled) external onlyOwner {
        require(executor != address(0), "EXECUTOR_ZERO");
        executors[executor] = enabled;
    }

    function check(IValiantProtocol protocol, Candidate calldata candidate) public view returns (CheckResult memory out) {
        ValiantTypes.AccountSnapshot memory account = protocol.accountSnapshot(candidate.sponsor);
        ValiantTypes.LiquidationQuote memory quote =
            protocol.quoteLiquidation(candidate.sponsor, candidate.borrower, candidate.desiredRepay);
        out = CheckResult({
            sponsor: candidate.sponsor,
            borrower: candidate.borrower,
            liquidatable: account.liquidatable && quote.repayAmount != 0,
            repayAmount: quote.repayAmount,
            healthFactor: account.healthFactor,
            seizeAmount: quote.seizeAmount
        });
    }

    function checkBatch(IValiantProtocol protocol, Candidate[] calldata candidates)
        external
        view
        returns (CheckResult[] memory results)
    {
        results = new CheckResult[](candidates.length);
        for (uint256 i = 0; i < candidates.length; i++) {
            results[i] = check(protocol, candidates[i]);
        }
    }

    function emitChecks(IValiantProtocol protocol, Candidate[] calldata candidates) external onlyExecutor {
        for (uint256 i = 0; i < candidates.length; i++) {
            CheckResult memory result = check(protocol, candidates[i]);
            emit CandidateChecked(result.sponsor, result.borrower, result.liquidatable, result.repayAmount);
        }
    }

    function forwardLiquidation(
        address protocol,
        address sponsor,
        address borrower,
        uint256 repayAmount,
        address receiver,
        bytes calldata callData
    ) external onlyExecutor returns (bytes memory result) {
        require(protocol != address(0), "PROTOCOL_ZERO");
        require(receiver != address(0), "RECEIVER_ZERO");
        (bool success, bytes memory data) = protocol.call(callData);
        require(success, "LIQUIDATION_CALL");
        emit LiquidationForwarded(protocol, sponsor, borrower, repayAmount);
        return data;
    }
}
