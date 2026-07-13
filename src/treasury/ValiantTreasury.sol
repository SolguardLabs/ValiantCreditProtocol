// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "../interfaces/IERC20.sol";
import {SafeTransferLib} from "../libraries/SafeTransferLib.sol";

contract ValiantTreasury {
    using SafeTransferLib for IERC20;

    event CollectorUpdated(address indexed collector);
    event MarketUpdated(address indexed market);
    event ReserveSwept(address indexed asset, address indexed receiver, uint256 amount);

    address public owner;
    address public market;
    address public collector;

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    modifier onlyMarket() {
        require(msg.sender == market, "ONLY_MARKET");
        _;
    }

    constructor(address initialOwner, address initialMarket, address initialCollector) {
        require(initialOwner != address(0), "OWNER_ZERO");
        require(initialCollector != address(0), "COLLECTOR_ZERO");
        owner = initialOwner;
        market = initialMarket;
        collector = initialCollector;
    }

    function setCollector(address newCollector) external onlyOwner {
        require(newCollector != address(0), "COLLECTOR_ZERO");
        collector = newCollector;
        emit CollectorUpdated(newCollector);
    }

    function setMarket(address newMarket) external onlyOwner {
        market = newMarket;
        emit MarketUpdated(newMarket);
    }

    function sweep(IERC20 asset, uint256 amount) external onlyMarket {
        asset.safeTransfer(collector, amount);
        emit ReserveSwept(address(asset), collector, amount);
    }
}
