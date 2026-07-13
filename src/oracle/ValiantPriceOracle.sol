// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ValiantAccess} from "../access/ValiantAccess.sol";
import {IValiantOracle} from "../interfaces/IValiantOracle.sol";

contract ValiantPriceOracle is ValiantAccess, IValiantOracle {
    event PriceUpdated(address indexed asset, uint256 price, uint8 decimals, uint256 heartbeat);
    event PriceInvalidated(address indexed asset);

    struct PriceRecord {
        uint256 value;
        uint8 decimals;
        uint64 updatedAt;
        uint64 heartbeat;
        bool valid;
    }

    mapping(address => PriceRecord) public records;

    constructor(address initialOwner) ValiantAccess(initialOwner) {}

    function setPrice(address asset, uint256 value, uint8 decimals_, uint64 heartbeat) external onlyRiskAdmin {
        require(asset != address(0), "ASSET_ZERO");
        require(value != 0, "PRICE_ZERO");
        require(decimals_ <= 18, "DECIMALS");
        records[asset] = PriceRecord({
            value: value,
            decimals: decimals_,
            updatedAt: uint64(block.timestamp),
            heartbeat: heartbeat,
            valid: true
        });
        emit PriceUpdated(asset, value, decimals_, heartbeat);
    }

    function setPrices(address[] calldata assets, uint256[] calldata values, uint8[] calldata decimals_, uint64 heartbeat)
        external
        onlyRiskAdmin
    {
        require(assets.length == values.length && values.length == decimals_.length, "LENGTH");
        for (uint256 i = 0; i < assets.length; i++) {
            require(assets[i] != address(0), "ASSET_ZERO");
            require(values[i] != 0, "PRICE_ZERO");
            require(decimals_[i] <= 18, "DECIMALS");
            records[assets[i]] = PriceRecord({
                value: values[i],
                decimals: decimals_[i],
                updatedAt: uint64(block.timestamp),
                heartbeat: heartbeat,
                valid: true
            });
            emit PriceUpdated(assets[i], values[i], decimals_[i], heartbeat);
        }
    }

    function invalidate(address asset) external onlyRiskAdmin {
        records[asset].valid = false;
        emit PriceInvalidated(asset);
    }

    function getPrice(address asset) external view returns (Price memory) {
        PriceRecord memory record = records[asset];
        bool fresh = record.valid;
        if (record.heartbeat != 0 && block.timestamp > uint256(record.updatedAt) + record.heartbeat) {
            fresh = false;
        }
        return Price({value: record.value, decimals: record.decimals, updatedAt: record.updatedAt, valid: fresh});
    }
}
