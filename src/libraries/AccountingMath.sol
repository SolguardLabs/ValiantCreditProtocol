// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PercentageMath} from "./PercentageMath.sol";
import {WadMath} from "./WadMath.sol";

library AccountingMath {
    using PercentageMath for uint256;
    using WadMath for uint256;

    struct BalanceSheet {
        uint256 cash;
        uint256 collateral;
        uint256 debt;
        uint256 reserves;
        uint256 pendingFees;
    }

    struct Flow {
        uint256 inflow;
        uint256 outflow;
        uint256 fees;
        uint256 reserves;
    }

    function assets(BalanceSheet memory sheet) internal pure returns (uint256) {
        return sheet.cash + sheet.collateral + sheet.pendingFees;
    }

    function liabilities(BalanceSheet memory sheet) internal pure returns (uint256) {
        return sheet.debt + sheet.reserves;
    }

    function equity(BalanceSheet memory sheet) internal pure returns (uint256) {
        uint256 a = assets(sheet);
        uint256 l = liabilities(sheet);
        return a > l ? a - l : 0;
    }

    function utilization(BalanceSheet memory sheet) internal pure returns (uint256) {
        uint256 denominator = sheet.cash + sheet.debt;
        if (denominator == 0) return 0;
        return sheet.debt.divWad(denominator);
    }

    function reserveCoverage(BalanceSheet memory sheet) internal pure returns (uint256) {
        if (sheet.reserves == 0) return type(uint256).max;
        return sheet.cash.divWad(sheet.reserves);
    }

    function applyFlow(BalanceSheet memory sheet, Flow memory flow) internal pure returns (BalanceSheet memory) {
        sheet.cash += flow.inflow;
        require(sheet.cash >= flow.outflow, "CASH");
        sheet.cash -= flow.outflow;
        sheet.pendingFees += flow.fees;
        sheet.reserves += flow.reserves;
        return sheet;
    }

    function accrueFees(BalanceSheet memory sheet, uint256 feeBps) internal pure returns (BalanceSheet memory) {
        uint256 fee = sheet.debt.percentMul(feeBps);
        sheet.pendingFees += fee;
        return sheet;
    }

    function realizeFees(BalanceSheet memory sheet, uint256 reserveFactorBps)
        internal
        pure
        returns (BalanceSheet memory, uint256 reservesAdded, uint256 surplus)
    {
        reservesAdded = sheet.pendingFees.percentMul(reserveFactorBps);
        surplus = sheet.pendingFees - reservesAdded;
        sheet.reserves += reservesAdded;
        sheet.cash += surplus;
        sheet.pendingFees = 0;
        return (sheet, reservesAdded, surplus);
    }

    function maxSolventOutflow(BalanceSheet memory sheet, uint256 minCoverageWad) internal pure returns (uint256) {
        if (sheet.reserves == 0) return sheet.cash;
        uint256 requiredCash = sheet.reserves.mulWad(minCoverageWad);
        if (sheet.cash <= requiredCash) return 0;
        return sheet.cash - requiredCash;
    }
}
