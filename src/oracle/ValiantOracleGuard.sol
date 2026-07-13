// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IValiantOracle} from "../interfaces/IValiantOracle.sol";
import {PriceMath} from "../libraries/PriceMath.sol";

contract ValiantOracleGuard {
    using PriceMath for uint256;

    event ReferencePriceUpdated(address indexed asset, uint256 price, uint8 decimals);
    event GuardConfigUpdated(address indexed asset, uint256 maxDeviationBps, uint256 maxAge);

    struct Reference {
        uint256 price;
        uint8 decimals;
        uint64 updatedAt;
        bool active;
    }

    struct GuardConfig {
        uint256 maxDeviationBps;
        uint256 maxAge;
        bool required;
    }

    address public owner;
    IValiantOracle public oracle;

    mapping(address => Reference) public references;
    mapping(address => GuardConfig) public configs;

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    constructor(address owner_, IValiantOracle oracle_) {
        require(owner_ != address(0), "OWNER_ZERO");
        require(address(oracle_) != address(0), "ORACLE_ZERO");
        owner = owner_;
        oracle = oracle_;
    }

    function setOracle(IValiantOracle nextOracle) external onlyOwner {
        require(address(nextOracle) != address(0), "ORACLE_ZERO");
        oracle = nextOracle;
    }

    function setReference(address asset, uint256 price, uint8 decimals_) external onlyOwner {
        require(asset != address(0), "ASSET_ZERO");
        require(price != 0, "PRICE_ZERO");
        references[asset] = Reference({price: price, decimals: decimals_, updatedAt: uint64(block.timestamp), active: true});
        emit ReferencePriceUpdated(asset, price, decimals_);
    }

    function setConfig(address asset, uint256 maxDeviationBps, uint256 maxAge, bool required) external onlyOwner {
        require(maxDeviationBps <= 10_000, "DEVIATION");
        configs[asset] = GuardConfig({maxDeviationBps: maxDeviationBps, maxAge: maxAge, required: required});
        emit GuardConfigUpdated(asset, maxDeviationBps, maxAge);
    }

    function guardedPrice(address asset) external view returns (IValiantOracle.Price memory price, bool isAccepted) {
        price = oracle.getPrice(asset);
        isAccepted = _accepted(asset, price);
    }

    function accepted(address asset) external view returns (bool) {
        return _accepted(asset, oracle.getPrice(asset));
    }

    function deviation(address asset) external view returns (uint256) {
        IValiantOracle.Price memory price = oracle.getPrice(asset);
        Reference memory refRecord = references[asset];
        if (!refRecord.active || refRecord.price == 0 || !price.valid) return type(uint256).max;
        uint256 normalized = PriceMath.normalizePrice(price.value, price.decimals, refRecord.decimals);
        return PriceMath.deviationBps(normalized, refRecord.price);
    }

    function _accepted(address asset, IValiantOracle.Price memory price) internal view returns (bool) {
        GuardConfig memory config = configs[asset];
        if (!config.required) return price.valid && price.value != 0;
        if (!price.valid || price.value == 0) return false;
        Reference memory refRecord = references[asset];
        if (!refRecord.active || refRecord.price == 0) return false;
        if (config.maxAge != 0 && block.timestamp > uint256(refRecord.updatedAt) + config.maxAge) return false;
        uint256 normalized = PriceMath.normalizePrice(price.value, price.decimals, refRecord.decimals);
        return PriceMath.deviationBps(normalized, refRecord.price) <= config.maxDeviationBps;
    }
}
