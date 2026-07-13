// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PercentageMath} from "./PercentageMath.sol";

library LiquidationMath {
    using PercentageMath for uint256;

    function maxClose(uint256 debt, uint256 closeFactorBps) internal pure returns (uint256) {
        return debt.percentMul(closeFactorBps);
    }

    function seizeForRepay(uint256 repayAmount, uint256 price, uint8 priceDecimals, uint256 bonusBps)
        internal
        pure
        returns (uint256)
    {
        if (repayAmount == 0) return 0;
        require(price != 0, "PRICE_ZERO");
        uint256 gross = repayAmount.percentMul(PercentageMath.BPS + bonusBps);
        return (gross * (10 ** priceDecimals)) / price;
    }

    function boundedRepay(uint256 requested, uint256 routeDebt, uint256 accountDebt, uint256 closeFactorBps)
        internal
        pure
        returns (uint256 repayAmount, bool closeFactorApplied)
    {
        uint256 closeAmount = maxClose(accountDebt, closeFactorBps);
        if (closeAmount == 0 || closeAmount > routeDebt) closeAmount = routeDebt;
        repayAmount = requested;
        if (repayAmount > routeDebt) repayAmount = routeDebt;
        if (repayAmount > closeAmount) {
            repayAmount = closeAmount;
            closeFactorApplied = true;
        }
    }
}
