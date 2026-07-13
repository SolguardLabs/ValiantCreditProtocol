// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {WadMath} from "./WadMath.sol";

library DebtMath {
    using WadMath for uint256;

    uint256 internal constant WAD = 1e18;

    function scaledFromAmount(uint256 amount, uint256 index) internal pure returns (uint256) {
        require(index != 0, "INDEX_ZERO");
        if (amount == 0) return 0;
        return amount.divWadUp(index);
    }

    function amountFromScaled(uint256 scaled, uint256 index) internal pure returns (uint256) {
        if (scaled == 0) return 0;
        return scaled.mulWad(index);
    }

    function amountFromScaledUp(uint256 scaled, uint256 index) internal pure returns (uint256) {
        if (scaled == 0) return 0;
        return scaled.mulWadUp(index);
    }

    function accrueIndex(uint256 index, uint256 ratePerSecond, uint256 elapsed)
        internal
        pure
        returns (uint256)
    {
        if (elapsed == 0 || ratePerSecond == 0) return index;
        uint256 growth = ratePerSecond * elapsed;
        return index + index.mulWad(growth);
    }

    function interestFromIndexMove(uint256 scaledDebt, uint256 oldIndex, uint256 newIndex)
        internal
        pure
        returns (uint256)
    {
        if (scaledDebt == 0 || newIndex <= oldIndex) return 0;
        uint256 beforeDebt = amountFromScaled(scaledDebt, oldIndex);
        uint256 afterDebt = amountFromScaled(scaledDebt, newIndex);
        return afterDebt - beforeDebt;
    }

    function repayScaled(uint256 routeScaledDebt, uint256 amount, uint256 index)
        internal
        pure
        returns (uint256 scaledPaid, uint256 amountPaid)
    {
        if (routeScaledDebt == 0 || amount == 0) return (0, 0);
        uint256 fullDebt = amountFromScaledUp(routeScaledDebt, index);
        if (amount >= fullDebt) return (routeScaledDebt, fullDebt);
        scaledPaid = scaledFromAmount(amount, index);
        if (scaledPaid > routeScaledDebt) scaledPaid = routeScaledDebt;
        amountPaid = amountFromScaledUp(scaledPaid, index);
    }
}
