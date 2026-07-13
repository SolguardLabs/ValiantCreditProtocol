// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IValiantOracle {
    struct Price {
        uint256 value;
        uint8 decimals;
        uint256 updatedAt;
        bool valid;
    }

    function getPrice(address asset) external view returns (Price memory);
}
