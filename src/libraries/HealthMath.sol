// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PercentageMath} from "./PercentageMath.sol";

library HealthMath {
    using PercentageMath for uint256;

    uint256 internal constant WAD = 1e18;

    function collateralValue(uint256 collateral, uint256 price, uint8 priceDecimals) internal pure returns (uint256) {
        if (collateral == 0 || price == 0) return 0;
        return (collateral * price) / (10 ** priceDecimals);
    }

    function borrowCapacity(uint256 collateral, uint256 price, uint8 priceDecimals, uint256 collateralFactorBps)
        internal
        pure
        returns (uint256)
    {
        return collateralValue(collateral, price, priceDecimals).percentMul(collateralFactorBps);
    }

    function liquidationCapacity(
        uint256 collateral,
        uint256 price,
        uint8 priceDecimals,
        uint256 liquidationThresholdBps
    ) internal pure returns (uint256) {
        return collateralValue(collateral, price, priceDecimals).percentMul(liquidationThresholdBps);
    }

    function healthFactor(
        uint256 collateral,
        uint256 debt,
        uint256 price,
        uint8 priceDecimals,
        uint256 liquidationThresholdBps
    ) internal pure returns (uint256) {
        if (debt == 0) return type(uint256).max;
        uint256 capacity = liquidationCapacity(collateral, price, priceDecimals, liquidationThresholdBps);
        return (capacity * WAD) / debt;
    }

    function availableCredit(
        uint256 collateral,
        uint256 debt,
        uint256 price,
        uint8 priceDecimals,
        uint256 collateralFactorBps
    ) internal pure returns (uint256) {
        uint256 capacity = borrowCapacity(collateral, price, priceDecimals, collateralFactorBps);
        if (capacity <= debt) return 0;
        return capacity - debt;
    }

    function isLiquidatable(
        uint256 collateral,
        uint256 debt,
        uint256 price,
        uint8 priceDecimals,
        uint256 liquidationThresholdBps
    ) internal pure returns (bool) {
        return healthFactor(collateral, debt, price, priceDecimals, liquidationThresholdBps) < WAD;
    }
}
