// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IValiantKeeper {
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

    event CandidateChecked(address indexed sponsor, address indexed borrower, bool liquidatable, uint256 repay);
    event LiquidationForwarded(address indexed protocol, address indexed sponsor, address indexed borrower, uint256 repay);

    function owner() external view returns (address);

    function executors(address account) external view returns (bool);

    function setExecutor(address executor, bool enabled) external;

    function check(address protocol, Candidate calldata candidate) external view returns (CheckResult memory);

    function checkBatch(address protocol, Candidate[] calldata candidates)
        external
        view
        returns (CheckResult[] memory results);

    function emitChecks(address protocol, Candidate[] calldata candidates) external;

    function forwardLiquidation(
        address protocol,
        address sponsor,
        address borrower,
        uint256 repayAmount,
        address receiver,
        bytes calldata callData
    ) external returns (bytes memory result);
}
