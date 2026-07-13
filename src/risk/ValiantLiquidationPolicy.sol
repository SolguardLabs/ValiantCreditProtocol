// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HealthMath} from "../libraries/HealthMath.sol";
import {LiquidationMath} from "../libraries/LiquidationMath.sol";
import {PercentageMath} from "../libraries/PercentageMath.sol";

contract ValiantLiquidationPolicy {
    using PercentageMath for uint256;

    struct Bounds {
        uint256 minRepay;
        uint256 maxRepay;
        uint256 maxSeize;
        uint256 targetHealth;
    }

    struct Plan {
        uint256 repay;
        uint256 seize;
        uint256 healthAfter;
        bool fullClose;
        bool valid;
    }

    function plan(
        uint256 collateral,
        uint256 debt,
        uint256 requestedRepay,
        uint256 price,
        uint8 priceDecimals,
        uint256 liquidationThresholdBps,
        uint256 liquidationBonusBps,
        Bounds calldata bounds
    ) external pure returns (Plan memory out) {
        out.repay = requestedRepay;
        if (out.repay < bounds.minRepay) out.repay = bounds.minRepay;
        if (bounds.maxRepay != 0 && out.repay > bounds.maxRepay) out.repay = bounds.maxRepay;
        if (out.repay > debt) out.repay = debt;
        out.seize = LiquidationMath.seizeForRepay(out.repay, price, priceDecimals, liquidationBonusBps);
        if (bounds.maxSeize != 0 && out.seize > bounds.maxSeize) out.seize = bounds.maxSeize;
        if (out.seize > collateral) out.seize = collateral;
        uint256 finalDebt = debt > out.repay ? debt - out.repay : 0;
        uint256 finalCollateral = collateral > out.seize ? collateral - out.seize : 0;
        out.healthAfter = HealthMath.healthFactor(finalCollateral, finalDebt, price, priceDecimals, liquidationThresholdBps);
        out.fullClose = finalDebt == 0;
        out.valid = out.repay != 0 && (bounds.targetHealth == 0 || out.healthAfter >= bounds.targetHealth || out.fullClose);
    }

    function closeFactorForHealth(uint256 healthFactor, uint256 minCloseBps, uint256 maxCloseBps)
        external
        pure
        returns (uint256)
    {
        require(minCloseBps <= maxCloseBps, "CLOSE_RANGE");
        require(maxCloseBps <= PercentageMath.BPS, "CLOSE_HIGH");
        if (healthFactor >= 1e18) return 0;
        if (healthFactor <= 0.7e18) return maxCloseBps;
        uint256 deficit = 1e18 - healthFactor;
        uint256 span = maxCloseBps - minCloseBps;
        return minCloseBps + ((span * deficit) / 0.3e18);
    }

    function bonusForUtilization(uint256 utilizationBps, uint256 baseBonusBps, uint256 maxBonusBps)
        external
        pure
        returns (uint256)
    {
        require(baseBonusBps <= maxBonusBps, "BONUS_RANGE");
        if (utilizationBps <= 5_000) return baseBonusBps;
        if (utilizationBps >= 9_000) return maxBonusBps;
        uint256 span = maxBonusBps - baseBonusBps;
        uint256 scaled = ((utilizationBps - 5_000) * span) / 4_000;
        return baseBonusBps + scaled;
    }

    function repayToTarget(
        uint256 collateral,
        uint256 debt,
        uint256 price,
        uint8 priceDecimals,
        uint256 liquidationThresholdBps,
        uint256 targetHealth
    ) external pure returns (uint256) {
        if (debt == 0) return 0;
        uint256 liquidationCapacity =
            HealthMath.liquidationCapacity(collateral, price, priceDecimals, liquidationThresholdBps);
        uint256 targetDebt = (liquidationCapacity * 1e18) / targetHealth;
        if (targetDebt >= debt) return 0;
        return debt - targetDebt;
    }
}
