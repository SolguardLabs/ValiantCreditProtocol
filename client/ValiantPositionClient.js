function min(a, b) {
    return a < b ? a : b;
}

/** Read-only direct-line view for transaction preparation. */
class ValiantPositionClient {
    constructor(protocol) {
        this.protocol = protocol;
    }

    async inspectDirect(sponsor, delegate) {
        const [account, line, liquidity] = await Promise.all([
            this.protocol.accountSnapshot(sponsor),
            this.protocol.creditLine(sponsor, delegate),
            this.protocol.availableLiquidity(),
        ]);
        const routeCapacity = min(min(account.availableCredit, line.remaining), liquidity);
        return {
            sponsor,
            delegate,
            collateral: account.collateral,
            debt: account.debt,
            borrowCapacity: account.borrowCapacity,
            availableCredit: account.availableCredit,
            lineLimit: line.limit,
            lineUsed: line.used,
            lineRemaining: line.remaining,
            marketLiquidity: liquidity,
            lineActive: line.active,
            executableNow: line.active && account.collateralEnabled ? routeCapacity : 0n,
        };
    }
}

module.exports = { ValiantPositionClient };
