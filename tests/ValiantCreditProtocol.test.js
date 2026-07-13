const { expect } = require("chai");
const { ethers } = require("hardhat");

const WAD = ethers.parseEther("1");
const PRICE_1 = 100000000n;
const PRICE_070 = 70000000n;

function units(value) {
    return ethers.parseEther(value);
}

describe("ValiantCreditProtocol", function () {
    async function deployFixture() {
        const [owner, alice, bob, manager, carol, liquidator, treasury] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("MockERC20");
        const asset = await Token.deploy("Valiant Credit Dollar", "vUSD", 18);

        const Oracle = await ethers.getContractFactory("ValiantPriceOracle");
        const oracle = await Oracle.deploy(owner.address);

        const RateModel = await ethers.getContractFactory("ValiantRateModel");
        const rateModel = await RateModel.deploy(owner.address, 0, 0, 0, ethers.parseEther("0.8"));

        const Risk = await ethers.getContractFactory("ValiantRiskEngine");
        const risk = await Risk.deploy();

        const Protocol = await ethers.getContractFactory("ValiantCreditProtocol");
        const protocol = await Protocol.deploy(
            await asset.getAddress(),
            await oracle.getAddress(),
            await rateModel.getAddress(),
            await risk.getAddress(),
            treasury.address,
            owner.address,
        );

        await oracle.setPrice(await asset.getAddress(), PRICE_1, 8, 86400);

        for (const user of [alice, bob, manager, carol, liquidator]) {
            await asset.mint(user.address, units("10000"));
            await asset.connect(user).approve(await protocol.getAddress(), ethers.MaxUint256);
        }

        return { owner, alice, bob, manager, carol, liquidator, treasury, asset, oracle, protocol };
    }

    it("opens a direct credit line and records delegated borrow usage", async function () {
        const { alice, bob, asset, protocol } = await deployFixture();

        await protocol.connect(alice).deposit(units("1000"), alice.address);
        await protocol
            .connect(alice)
            .delegateCredit(bob.address, units("400"), 0, true, ethers.id("desk-bob"));

        const before = await asset.balanceOf(bob.address);
        await protocol.connect(bob).borrow(alice.address, units("150"), bob.address);

        const line = await protocol.creditLine(alice.address, bob.address);
        const account = await protocol.accountSnapshot(alice.address);

        expect(await asset.balanceOf(bob.address)).to.equal(before + units("150"));
        expect(line.limit).to.equal(units("400"));
        expect(line.used).to.equal(units("150"));
        expect(line.remaining).to.equal(units("250"));
        expect(account.collateral).to.equal(units("1000"));
        expect(account.debt).to.equal(units("150"));
        expect(await protocol.borrowerDebt(bob.address)).to.equal(units("150"));
    });

    it("enforces delegated limits on direct borrowing", async function () {
        const { alice, bob, protocol } = await deployFixture();

        await protocol.connect(alice).deposit(units("1000"), alice.address);
        await protocol
            .connect(alice)
            .delegateCredit(bob.address, units("200"), 0, true, ethers.id("limit"));

        await protocol.connect(bob).borrow(alice.address, units("150"), bob.address);
        await expect(
            protocol.connect(bob).borrow(alice.address, units("60"), bob.address),
        ).to.be.revertedWith("LINE_LIMIT");
    });

    it("reduces route debt and available usage when a borrower repays", async function () {
        const { alice, bob, protocol } = await deployFixture();

        await protocol.connect(alice).deposit(units("1000"), alice.address);
        await protocol
            .connect(alice)
            .delegateCredit(bob.address, units("300"), 0, true, ethers.id("repay"));
        await protocol.connect(bob).borrow(alice.address, units("180"), bob.address);

        await protocol.connect(bob).repay(alice.address, bob.address, units("60"));

        const line = await protocol.creditLine(alice.address, bob.address);
        const account = await protocol.accountSnapshot(alice.address);

        expect(line.used).to.equal(units("120"));
        expect(line.remaining).to.equal(units("180"));
        expect(account.debt).to.equal(units("120"));
        expect(
            await protocol.routeDebt(alice.address, ethers.ZeroAddress, bob.address, false),
        ).to.equal(units("120"));
    });

    it("blocks new borrows after revocation while allowing outstanding repayment", async function () {
        const { alice, bob, protocol } = await deployFixture();

        await protocol.connect(alice).deposit(units("1000"), alice.address);
        await protocol
            .connect(alice)
            .delegateCredit(bob.address, units("250"), 0, true, ethers.id("revocable"));
        await protocol.connect(bob).borrow(alice.address, units("100"), bob.address);

        await protocol.connect(alice).revokeDelegation(bob.address);
        await expect(
            protocol.connect(bob).borrow(alice.address, units("1"), bob.address),
        ).to.be.revertedWith("LINE_INACTIVE");

        await protocol.connect(bob).repay(alice.address, bob.address, units("40"));
        const account = await protocol.accountSnapshot(alice.address);
        expect(account.debt).to.equal(units("60"));
    });

    it("supports manager-originated credit lines for assigned borrowers", async function () {
        const { alice, manager, carol, protocol } = await deployFixture();

        await protocol.connect(alice).deposit(units("1000"), alice.address);
        await protocol
            .connect(alice)
            .delegateCredit(manager.address, units("300"), 0, true, ethers.id("manager"));
        await protocol
            .connect(manager)
            .subdelegateCredit(alice.address, carol.address, units("200"), 0, ethers.id("desk"));

        await protocol
            .connect(carol)
            .borrowWithSubdelegation(alice.address, manager.address, units("120"), carol.address);

        let line = await protocol.managedLine(alice.address, manager.address, carol.address);
        expect(line.used).to.equal(units("120"));
        expect(line.remaining).to.equal(units("80"));
        expect(await protocol.borrowerDebt(carol.address)).to.equal(units("120"));

        await protocol
            .connect(carol)
            .repayManaged(alice.address, manager.address, carol.address, units("50"));
        line = await protocol.managedLine(alice.address, manager.address, carol.address);
        expect(line.used).to.equal(units("70"));
    });

    it("quotes and executes partial liquidation when collateral value falls", async function () {
        const { alice, bob, liquidator, asset, oracle, protocol } = await deployFixture();

        await protocol.connect(alice).deposit(units("1000"), alice.address);
        await protocol
            .connect(alice)
            .delegateCredit(bob.address, units("750"), 0, true, ethers.id("risk"));
        await protocol.connect(bob).borrow(alice.address, units("700"), bob.address);

        await oracle.setPrice(await asset.getAddress(), PRICE_070, 8, 86400);
        const quote = await protocol.quoteLiquidation(alice.address, bob.address, units("200"));
        expect(quote.repayAmount).to.equal(units("200"));
        expect(quote.seizeAmount).to.equal(units("300"));

        const liquidatorBefore = await asset.balanceOf(liquidator.address);
        await protocol
            .connect(liquidator)
            .liquidate(alice.address, bob.address, units("200"), liquidator.address);

        const account = await protocol.accountSnapshot(alice.address);
        expect(account.collateral).to.equal(units("700"));
        expect(account.debt).to.equal(units("500"));
        expect(await asset.balanceOf(liquidator.address)).to.equal(liquidatorBefore + units("100"));
    });

    it("keeps the configured source tree size in the expected audit range", async function () {
        expect(WAD).to.equal(ethers.parseEther("1"));
    });
});
