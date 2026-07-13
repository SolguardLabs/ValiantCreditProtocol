// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IValiantProtocol} from "../interfaces/IValiantProtocol.sol";
import {PercentageMath} from "../libraries/PercentageMath.sol";
import {ValiantTypes} from "../libraries/ValiantTypes.sol";

contract ValiantScenarioLens {
    using PercentageMath for uint256;

    struct PortfolioSummary {
        uint256 totalCollateral;
        uint256 totalDebt;
        uint256 minHealth;
        uint256 liquidatableAccounts;
        uint256 averageUtilizationBps;
    }

    struct RouteSummary {
        address sponsor;
        address manager;
        address borrower;
        bool managed;
        uint256 debt;
    }

    function summarize(IValiantProtocol protocol, address[] calldata accounts)
        external
        view
        returns (PortfolioSummary memory summary)
    {
        summary.minHealth = type(uint256).max;
        for (uint256 i = 0; i < accounts.length; i++) {
            ValiantTypes.AccountSnapshot memory account = protocol.accountSnapshot(accounts[i]);
            summary.totalCollateral += account.collateral;
            summary.totalDebt += account.debt;
            if (account.healthFactor < summary.minHealth) summary.minHealth = account.healthFactor;
            if (account.liquidatable) summary.liquidatableAccounts++;
            if (account.borrowCapacity != 0) {
                summary.averageUtilizationBps += account.debt.percentDiv(account.borrowCapacity);
            }
        }
        if (accounts.length != 0) summary.averageUtilizationBps = summary.averageUtilizationBps / accounts.length;
    }

    function routeSummaries(IValiantProtocol protocol, RouteSummary[] calldata routes)
        external
        view
        returns (RouteSummary[] memory out)
    {
        out = new RouteSummary[](routes.length);
        for (uint256 i = 0; i < routes.length; i++) {
            out[i] = routes[i];
            out[i].debt =
                protocol.routeDebt(routes[i].sponsor, routes[i].manager, routes[i].borrower, routes[i].managed);
        }
    }

    function accountsAtRisk(IValiantProtocol protocol, address[] calldata accounts, uint256 minHealth)
        external
        view
        returns (address[] memory atRisk)
    {
        address[] memory buffer = new address[](accounts.length);
        uint256 count;
        for (uint256 i = 0; i < accounts.length; i++) {
            ValiantTypes.AccountSnapshot memory account = protocol.accountSnapshot(accounts[i]);
            if (account.healthFactor < minHealth) {
                buffer[count] = accounts[i];
                count++;
            }
        }
        atRisk = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            atRisk[i] = buffer[i];
        }
    }

    function lineUtilizations(IValiantProtocol protocol, address sponsor, address[] calldata delegates)
        external
        view
        returns (uint256[] memory utilizations)
    {
        utilizations = new uint256[](delegates.length);
        for (uint256 i = 0; i < delegates.length; i++) {
            ValiantTypes.LineSnapshot memory line = protocol.creditLine(sponsor, delegates[i]);
            utilizations[i] = line.limit == 0 ? 0 : line.used.percentDiv(line.limit);
        }
    }
}
