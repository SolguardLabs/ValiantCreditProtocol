// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IValiantRateModel {
    function utilization(uint256 cash, uint256 borrows, uint256 reserves) external pure returns (uint256);

    function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) external view returns (uint256);

    function getSupplyRate(uint256 cash, uint256 borrows, uint256 reserves, uint256 reserveFactorBps)
        external
        view
        returns (uint256);
}
