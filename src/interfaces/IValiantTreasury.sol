// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "./IERC20.sol";

interface IValiantTreasury {
    event CollectorUpdated(address indexed collector);
    event MarketUpdated(address indexed market);
    event ReserveSwept(address indexed asset, address indexed receiver, uint256 amount);

    function owner() external view returns (address);

    function market() external view returns (address);

    function collector() external view returns (address);

    function setCollector(address newCollector) external;

    function setMarket(address newMarket) external;

    function sweep(IERC20 asset, uint256 amount) external;
}
