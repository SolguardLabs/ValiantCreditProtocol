// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library ValiantTypes {
    struct MarketConfig {
        uint256 collateralFactorBps;
        uint256 liquidationThresholdBps;
        uint256 liquidationBonusBps;
        uint256 closeFactorBps;
        uint256 reserveFactorBps;
        uint256 minDelegation;
        uint256 maxDelegation;
        uint256 supplyCap;
        uint256 borrowCap;
        uint256 maxPriceAge;
    }

    struct MarketState {
        uint256 totalCollateral;
        uint256 totalScaledDebt;
        uint256 totalPrincipal;
        uint256 totalReserves;
        uint256 borrowIndex;
        uint256 lastAccrual;
        uint256 activeDelegations;
        uint256 activeManagedLines;
        uint256 totalLiquidated;
        uint256 totalSeized;
    }

    struct AccountPosition {
        uint256 collateral;
        uint256 scaledDebt;
        uint256 principalDebt;
        uint256 seizedCollateral;
        uint256 nonce;
        uint64 lastAction;
        bool collateralEnabled;
    }

    struct CreditLine {
        address sponsor;
        address delegate;
        uint256 limit;
        uint256 used;
        uint64 expiresAt;
        uint64 openedAt;
        uint64 closedAt;
        bool active;
        bool revocable;
        bytes32 label;
    }

    struct ManagedLine {
        address sponsor;
        address manager;
        address borrower;
        uint256 limit;
        uint256 used;
        uint64 expiresAt;
        uint64 openedAt;
        uint64 closedAt;
        bool active;
        bytes32 label;
    }

    struct LoanRoute {
        address sponsor;
        address manager;
        address borrower;
        address exposureAccount;
        uint256 scaledDebt;
        uint256 principal;
        uint256 openedAt;
        uint256 lastUpdate;
        bool managed;
    }

    struct AccountSnapshot {
        address account;
        uint256 collateral;
        uint256 debt;
        uint256 principalDebt;
        uint256 borrowCapacity;
        uint256 availableCredit;
        uint256 healthFactor;
        bool liquidatable;
        bool collateralEnabled;
    }

    struct LineSnapshot {
        bytes32 key;
        address sponsor;
        address delegate;
        uint256 limit;
        uint256 used;
        uint256 remaining;
        uint64 expiresAt;
        bool active;
        bool revocable;
        bytes32 label;
    }

    struct ManagedLineSnapshot {
        bytes32 key;
        address sponsor;
        address manager;
        address borrower;
        uint256 limit;
        uint256 used;
        uint256 remaining;
        uint64 expiresAt;
        bool active;
        bytes32 label;
    }

    struct LiquidationQuote {
        uint256 repayAmount;
        uint256 debtBefore;
        uint256 collateralBefore;
        uint256 seizeAmount;
        uint256 healthBefore;
        uint256 healthAfter;
        bool closeFactorApplied;
    }
}
