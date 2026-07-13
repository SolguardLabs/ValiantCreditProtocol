// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "../interfaces/IERC20.sol";
import {IValiantProtocol} from "../interfaces/IValiantProtocol.sol";
import {PercentageMath} from "../libraries/PercentageMath.sol";
import {ValiantTypes} from "../libraries/ValiantTypes.sol";

contract ValiantMarketReporter {
    using PercentageMath for uint256;

    struct MarketReport {
        uint256 cash;
        uint256 totalDebt;
        uint256 availableLiquidity;
        uint256 utilizationBps;
        uint256 accountCount;
        uint256 liquidatableCount;
        uint256 minHealthFactor;
        uint256 maxHealthFactor;
    }

    struct DelegateReport {
        address delegate;
        uint256 limit;
        uint256 used;
        uint256 remaining;
        uint256 utilizationBps;
        bool active;
    }

    function report(IValiantProtocol protocol, IERC20 asset, address[] calldata accounts)
        external
        view
        returns (MarketReport memory out)
    {
        out.cash = asset.balanceOf(address(protocol));
        out.totalDebt = protocol.totalDebt();
        out.availableLiquidity = protocol.availableLiquidity();
        out.accountCount = accounts.length;
        out.minHealthFactor = type(uint256).max;
        for (uint256 i = 0; i < accounts.length; i++) {
            ValiantTypes.AccountSnapshot memory snapshot = protocol.accountSnapshot(accounts[i]);
            if (snapshot.liquidatable) out.liquidatableCount++;
            if (snapshot.healthFactor < out.minHealthFactor) out.minHealthFactor = snapshot.healthFactor;
            if (snapshot.healthFactor > out.maxHealthFactor && snapshot.healthFactor != type(uint256).max) {
                out.maxHealthFactor = snapshot.healthFactor;
            }
        }
        uint256 denominator = out.availableLiquidity + out.totalDebt;
        out.utilizationBps = denominator == 0 ? 0 : out.totalDebt.percentDiv(denominator);
    }

    function delegateReports(IValiantProtocol protocol, address sponsor, address[] calldata delegates)
        external
        view
        returns (DelegateReport[] memory reports)
    {
        reports = new DelegateReport[](delegates.length);
        for (uint256 i = 0; i < delegates.length; i++) {
            ValiantTypes.LineSnapshot memory line = protocol.creditLine(sponsor, delegates[i]);
            reports[i] = DelegateReport({
                delegate: delegates[i],
                limit: line.limit,
                used: line.used,
                remaining: line.remaining,
                utilizationBps: line.limit == 0 ? 0 : line.used.percentDiv(line.limit),
                active: line.active
            });
        }
    }

    function liquidationQuotes(
        IValiantProtocol protocol,
        address[] calldata sponsors,
        address[] calldata borrowers,
        uint256 requestedRepay
    ) external view returns (ValiantTypes.LiquidationQuote[] memory quotes) {
        require(sponsors.length == borrowers.length, "LENGTH");
        quotes = new ValiantTypes.LiquidationQuote[](sponsors.length);
        for (uint256 i = 0; i < sponsors.length; i++) {
            quotes[i] = protocol.quoteLiquidation(sponsors[i], borrowers[i], requestedRepay);
        }
    }
}
