// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IValiantProtocol} from "../interfaces/IValiantProtocol.sol";
import {ValiantTypes} from "../libraries/ValiantTypes.sol";

contract ValiantCreditLens {
    struct DelegateView {
        ValiantTypes.LineSnapshot directLine;
        ValiantTypes.AccountSnapshot sponsor;
        ValiantTypes.AccountSnapshot delegateAccount;
    }

    struct ManagedView {
        ValiantTypes.ManagedLineSnapshot line;
        ValiantTypes.AccountSnapshot sponsor;
        ValiantTypes.AccountSnapshot manager;
        uint256 borrowerDebt;
    }

    function account(IValiantProtocol protocol, address account_)
        external
        view
        returns (ValiantTypes.AccountSnapshot memory)
    {
        return protocol.accountSnapshot(account_);
    }

    function delegateView(IValiantProtocol protocol, address sponsor, address delegate)
        external
        view
        returns (DelegateView memory view_)
    {
        view_.directLine = protocol.creditLine(sponsor, delegate);
        view_.sponsor = protocol.accountSnapshot(sponsor);
        view_.delegateAccount = protocol.accountSnapshot(delegate);
    }

    function managedView(IValiantProtocol protocol, address sponsor, address manager, address borrower)
        external
        view
        returns (ManagedView memory view_)
    {
        view_.line = protocol.managedLine(sponsor, manager, borrower);
        view_.sponsor = protocol.accountSnapshot(sponsor);
        view_.manager = protocol.accountSnapshot(manager);
        view_.borrowerDebt = protocol.borrowerDebt(borrower);
    }

    function batchAccounts(IValiantProtocol protocol, address[] calldata accounts)
        external
        view
        returns (ValiantTypes.AccountSnapshot[] memory snapshots)
    {
        snapshots = new ValiantTypes.AccountSnapshot[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            snapshots[i] = protocol.accountSnapshot(accounts[i]);
        }
    }

    function batchDirectLines(IValiantProtocol protocol, address sponsor, address[] calldata delegates)
        external
        view
        returns (ValiantTypes.LineSnapshot[] memory snapshots)
    {
        snapshots = new ValiantTypes.LineSnapshot[](delegates.length);
        for (uint256 i = 0; i < delegates.length; i++) {
            snapshots[i] = protocol.creditLine(sponsor, delegates[i]);
        }
    }

    function batchManagedLines(
        IValiantProtocol protocol,
        address sponsor,
        address manager,
        address[] calldata borrowers
    ) external view returns (ValiantTypes.ManagedLineSnapshot[] memory snapshots) {
        snapshots = new ValiantTypes.ManagedLineSnapshot[](borrowers.length);
        for (uint256 i = 0; i < borrowers.length; i++) {
            snapshots[i] = protocol.managedLine(sponsor, manager, borrowers[i]);
        }
    }
}
