// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ValiantTypes} from "../libraries/ValiantTypes.sol";

interface IValiantProtocol {
    function accountSnapshot(address account) external view returns (ValiantTypes.AccountSnapshot memory);

    function creditLine(address sponsor, address delegate) external view returns (ValiantTypes.LineSnapshot memory);

    function managedLine(address sponsor, address manager, address borrower)
        external
        view
        returns (ValiantTypes.ManagedLineSnapshot memory);

    function routeDebt(address sponsor, address manager, address borrower, bool managed) external view returns (uint256);

    function borrowerDebt(address borrower) external view returns (uint256);

    function totalDebt() external view returns (uint256);

    function availableLiquidity() external view returns (uint256);

    function quoteLiquidation(address sponsor, address borrower, uint256 requestedRepay)
        external
        view
        returns (ValiantTypes.LiquidationQuote memory);
}
