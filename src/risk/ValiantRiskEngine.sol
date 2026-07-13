// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HealthMath} from "../libraries/HealthMath.sol";
import {LiquidationMath} from "../libraries/LiquidationMath.sol";
import {PercentageMath} from "../libraries/PercentageMath.sol";
import {ValiantTypes} from "../libraries/ValiantTypes.sol";

contract ValiantRiskEngine {
    using HealthMath for uint256;
    using PercentageMath for uint256;

    uint256 public constant MIN_LIQUIDATION_THRESHOLD = 5_000;
    uint256 public constant MAX_LIQUIDATION_BONUS = 2_500;

    function validateConfig(ValiantTypes.MarketConfig memory config) external pure returns (bool) {
        require(config.collateralFactorBps <= config.liquidationThresholdBps, "FACTOR_GT_THRESHOLD");
        require(config.liquidationThresholdBps <= PercentageMath.BPS, "THRESHOLD");
        require(config.liquidationThresholdBps >= MIN_LIQUIDATION_THRESHOLD, "THRESHOLD_LOW");
        require(config.closeFactorBps > 0 && config.closeFactorBps <= PercentageMath.BPS, "CLOSE_FACTOR");
        require(config.reserveFactorBps <= PercentageMath.BPS, "RESERVE_FACTOR");
        require(config.liquidationBonusBps <= MAX_LIQUIDATION_BONUS, "BONUS");
        if (config.maxDelegation != 0) require(config.minDelegation <= config.maxDelegation, "DELEGATION_RANGE");
        return true;
    }

    function borrowCapacity(
        uint256 collateral,
        uint256 price,
        uint8 priceDecimals,
        ValiantTypes.MarketConfig memory config
    ) public pure returns (uint256) {
        return HealthMath.borrowCapacity(collateral, price, priceDecimals, config.collateralFactorBps);
    }

    function liquidationCapacity(
        uint256 collateral,
        uint256 price,
        uint8 priceDecimals,
        ValiantTypes.MarketConfig memory config
    ) public pure returns (uint256) {
        return HealthMath.liquidationCapacity(collateral, price, priceDecimals, config.liquidationThresholdBps);
    }

    function healthFactor(
        uint256 collateral,
        uint256 debt,
        uint256 price,
        uint8 priceDecimals,
        ValiantTypes.MarketConfig memory config
    ) public pure returns (uint256) {
        return HealthMath.healthFactor(collateral, debt, price, priceDecimals, config.liquidationThresholdBps);
    }

    function availableCredit(
        uint256 collateral,
        uint256 debt,
        uint256 price,
        uint8 priceDecimals,
        ValiantTypes.MarketConfig memory config
    ) external pure returns (uint256) {
        return HealthMath.availableCredit(collateral, debt, price, priceDecimals, config.collateralFactorBps);
    }

    function canWithdraw(
        uint256 collateral,
        uint256 debt,
        uint256 withdrawal,
        uint256 price,
        uint8 priceDecimals,
        ValiantTypes.MarketConfig memory config
    ) external pure returns (bool) {
        if (withdrawal > collateral) return false;
        uint256 remaining = collateral - withdrawal;
        return borrowCapacity(remaining, price, priceDecimals, config) >= debt;
    }

    function isLiquidatable(
        uint256 collateral,
        uint256 debt,
        uint256 price,
        uint8 priceDecimals,
        ValiantTypes.MarketConfig memory config
    ) external pure returns (bool) {
        return HealthMath.isLiquidatable(collateral, debt, price, priceDecimals, config.liquidationThresholdBps);
    }

    function quoteLiquidation(
        uint256 collateral,
        uint256 accountDebt,
        uint256 routeDebt,
        uint256 requestedRepay,
        uint256 price,
        uint8 priceDecimals,
        ValiantTypes.MarketConfig memory config
    ) external pure returns (ValiantTypes.LiquidationQuote memory quote) {
        uint256 healthBefore = healthFactor(collateral, accountDebt, price, priceDecimals, config);
        (uint256 repayAmount, bool closeApplied) =
            LiquidationMath.boundedRepay(requestedRepay, routeDebt, accountDebt, config.closeFactorBps);
        uint256 seize = LiquidationMath.seizeForRepay(repayAmount, price, priceDecimals, config.liquidationBonusBps);
        if (seize > collateral) seize = collateral;
        uint256 finalDebt = accountDebt > repayAmount ? accountDebt - repayAmount : 0;
        uint256 finalCollateral = collateral > seize ? collateral - seize : 0;
        uint256 healthAfter = healthFactor(finalCollateral, finalDebt, price, priceDecimals, config);
        return ValiantTypes.LiquidationQuote({
            repayAmount: repayAmount,
            debtBefore: accountDebt,
            collateralBefore: collateral,
            seizeAmount: seize,
            healthBefore: healthBefore,
            healthAfter: healthAfter,
            closeFactorApplied: closeApplied
        });
    }
}
