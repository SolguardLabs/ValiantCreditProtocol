// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HealthMath} from "../libraries/HealthMath.sol";
import {PercentageMath} from "../libraries/PercentageMath.sol";
import {PriceMath} from "../libraries/PriceMath.sol";
import {ValiantTypes} from "../libraries/ValiantTypes.sol";

contract ValiantScenarioEngine {
    using PercentageMath for uint256;

    struct Shock {
        uint256 priceMoveBps;
        bool priceDown;
        uint256 debtIncreaseBps;
        uint256 collateralOutflowBps;
    }

    struct ScenarioResult {
        uint256 shockedPrice;
        uint256 shockedCollateral;
        uint256 shockedDebt;
        uint256 borrowCapacity;
        uint256 liquidationCapacity;
        uint256 healthFactor;
        bool liquidatable;
    }

    function stressAccount(
        ValiantTypes.AccountSnapshot calldata account,
        uint256 price,
        uint8 priceDecimals,
        ValiantTypes.MarketConfig calldata config,
        Shock calldata shock
    ) external pure returns (ScenarioResult memory result) {
        result.shockedPrice = _shockPrice(price, shock);
        result.shockedCollateral = _shockCollateral(account.collateral, shock);
        result.shockedDebt = _shockDebt(account.debt, shock);
        result.borrowCapacity =
            HealthMath.borrowCapacity(result.shockedCollateral, result.shockedPrice, priceDecimals, config.collateralFactorBps);
        result.liquidationCapacity = HealthMath.liquidationCapacity(
            result.shockedCollateral, result.shockedPrice, priceDecimals, config.liquidationThresholdBps
        );
        result.healthFactor = HealthMath.healthFactor(
            result.shockedCollateral, result.shockedDebt, result.shockedPrice, priceDecimals, config.liquidationThresholdBps
        );
        result.liquidatable = result.healthFactor < 1e18;
    }

    function stressBatch(
        ValiantTypes.AccountSnapshot[] calldata accounts,
        uint256 price,
        uint8 priceDecimals,
        ValiantTypes.MarketConfig calldata config,
        Shock calldata shock
    ) external pure returns (ScenarioResult[] memory results) {
        results = new ScenarioResult[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            results[i] = _stress(accounts[i], price, priceDecimals, config, shock);
        }
    }

    function aggregateShortfall(ScenarioResult[] calldata results) external pure returns (uint256 shortfall) {
        for (uint256 i = 0; i < results.length; i++) {
            if (results[i].shockedDebt > results[i].liquidationCapacity) {
                shortfall += results[i].shockedDebt - results[i].liquidationCapacity;
            }
        }
    }

    function requiredCollateralForHealth(
        uint256 targetHealth,
        uint256 debt,
        uint256 price,
        uint8 priceDecimals,
        uint256 liquidationThresholdBps
    ) external pure returns (uint256) {
        if (debt == 0) return 0;
        require(targetHealth >= 1e18, "TARGET");
        uint256 requiredValue = (debt * targetHealth) / 1e18;
        uint256 grossCollateralValue = requiredValue.percentDiv(liquidationThresholdBps);
        return PriceMath.amountForValueUp(grossCollateralValue, price, priceDecimals);
    }

    function maxDebtForHealth(
        uint256 targetHealth,
        uint256 collateral,
        uint256 price,
        uint8 priceDecimals,
        uint256 liquidationThresholdBps
    ) external pure returns (uint256) {
        require(targetHealth != 0, "TARGET_ZERO");
        uint256 liquidationCapacity = HealthMath.liquidationCapacity(collateral, price, priceDecimals, liquidationThresholdBps);
        return (liquidationCapacity * 1e18) / targetHealth;
    }

    function _stress(
        ValiantTypes.AccountSnapshot calldata account,
        uint256 price,
        uint8 priceDecimals,
        ValiantTypes.MarketConfig calldata config,
        Shock calldata shock
    ) internal pure returns (ScenarioResult memory result) {
        result.shockedPrice = _shockPrice(price, shock);
        result.shockedCollateral = _shockCollateral(account.collateral, shock);
        result.shockedDebt = _shockDebt(account.debt, shock);
        result.borrowCapacity =
            HealthMath.borrowCapacity(result.shockedCollateral, result.shockedPrice, priceDecimals, config.collateralFactorBps);
        result.liquidationCapacity = HealthMath.liquidationCapacity(
            result.shockedCollateral, result.shockedPrice, priceDecimals, config.liquidationThresholdBps
        );
        result.healthFactor = HealthMath.healthFactor(
            result.shockedCollateral, result.shockedDebt, result.shockedPrice, priceDecimals, config.liquidationThresholdBps
        );
        result.liquidatable = result.healthFactor < 1e18;
    }

    function _shockPrice(uint256 price, Shock calldata shock) internal pure returns (uint256) {
        if (shock.priceMoveBps == 0) return price;
        if (shock.priceDown) {
            uint256 move = shock.priceMoveBps > PercentageMath.BPS ? PercentageMath.BPS : shock.priceMoveBps;
            return price.percentMul(PercentageMath.BPS - move);
        }
        return price.percentMul(PercentageMath.BPS + shock.priceMoveBps);
    }

    function _shockCollateral(uint256 collateral, Shock calldata shock) internal pure returns (uint256) {
        if (shock.collateralOutflowBps == 0) return collateral;
        uint256 outflow =
            shock.collateralOutflowBps > PercentageMath.BPS ? PercentageMath.BPS : shock.collateralOutflowBps;
        return collateral.percentMul(PercentageMath.BPS - outflow);
    }

    function _shockDebt(uint256 debt, Shock calldata shock) internal pure returns (uint256) {
        if (shock.debtIncreaseBps == 0) return debt;
        return debt.percentMul(PercentageMath.BPS + shock.debtIncreaseBps);
    }
}
