// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ValiantPausable} from "./core/ValiantPausable.sol";
import {ReentrancyGuard} from "./core/ReentrancyGuard.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IValiantOracle} from "./interfaces/IValiantOracle.sol";
import {IValiantRateModel} from "./interfaces/IValiantRateModel.sol";
import {ValiantCreditToken} from "./tokens/ValiantCreditToken.sol";
import {ValiantRiskEngine} from "./risk/ValiantRiskEngine.sol";
import {DebtMath} from "./libraries/DebtMath.sol";
import {DelegationKeys} from "./libraries/DelegationKeys.sol";
import {HealthMath} from "./libraries/HealthMath.sol";
import {SafeTransferLib} from "./libraries/SafeTransferLib.sol";
import {ValiantTypes} from "./libraries/ValiantTypes.sol";

contract ValiantCreditProtocol is ValiantPausable, ReentrancyGuard {
    using SafeTransferLib for IERC20;
    using DebtMath for uint256;

    event Deposited(address indexed account, address indexed receiver, uint256 amount);
    event Withdrawn(address indexed account, address indexed receiver, uint256 amount);
    event CreditDelegated(address indexed sponsor, address indexed delegate, uint256 limit, uint64 expiresAt);
    event CreditRevoked(address indexed sponsor, address indexed delegate);
    event ManagedCreditDelegated(
        address indexed sponsor, address indexed manager, address indexed borrower, uint256 limit, uint64 expiresAt
    );
    event ManagedCreditRevoked(address indexed sponsor, address indexed manager, address indexed borrower);
    event Borrowed(
        bytes32 indexed route,
        address indexed sponsor,
        address indexed borrower,
        address receiver,
        uint256 amount,
        bool managed
    );
    event Repaid(bytes32 indexed route, address indexed payer, address indexed borrower, uint256 amount);
    event Liquidated(
        address indexed sponsor,
        address indexed borrower,
        address indexed liquidator,
        uint256 repaid,
        uint256 seized
    );
    event Accrued(uint256 borrowIndex, uint256 interestAccrued, uint256 reservesAccrued);
    event MarketConfigUpdated(ValiantTypes.MarketConfig config);
    event IntegrationsUpdated(address oracle, address rateModel, address riskEngine, address treasury);

    IERC20 public immutable asset;
    ValiantCreditToken public immutable receiptToken;

    IValiantOracle public oracle;
    IValiantRateModel public rateModel;
    ValiantRiskEngine public riskEngine;
    address public treasury;

    ValiantTypes.MarketConfig internal _config;
    ValiantTypes.MarketState internal _market;

    mapping(address => ValiantTypes.AccountPosition) internal _accounts;
    mapping(bytes32 => ValiantTypes.CreditLine) internal _creditLines;
    mapping(bytes32 => ValiantTypes.ManagedLine) internal _managedLines;
    mapping(bytes32 => ValiantTypes.LoanRoute) internal _routes;
    mapping(address => uint256) internal _borrowerScaledDebt;
    mapping(address => bytes32[]) internal _sponsorRoutes;
    mapping(address => bytes32[]) internal _borrowerRoutes;

    constructor(
        IERC20 asset_,
        IValiantOracle oracle_,
        IValiantRateModel rateModel_,
        ValiantRiskEngine riskEngine_,
        address treasury_,
        address initialOwner
    ) ValiantPausable(initialOwner) {
        require(address(asset_) != address(0), "ASSET_ZERO");
        require(address(oracle_) != address(0), "ORACLE_ZERO");
        require(address(rateModel_) != address(0), "RATE_ZERO");
        require(address(riskEngine_) != address(0), "RISK_ZERO");
        asset = asset_;
        oracle = oracle_;
        rateModel = rateModel_;
        riskEngine = riskEngine_;
        treasury = treasury_;
        receiptToken = new ValiantCreditToken("Valiant Credit Receipt", "vCREDIT", asset_.decimals(), address(this));
        _market.borrowIndex = 1e18;
        _market.lastAccrual = block.timestamp;
        _config = ValiantTypes.MarketConfig({
            collateralFactorBps: 7_500,
            liquidationThresholdBps: 8_500,
            liquidationBonusBps: 500,
            closeFactorBps: 5_000,
            reserveFactorBps: 1_000,
            minDelegation: 1e18,
            maxDelegation: 0,
            supplyCap: 0,
            borrowCap: 0,
            maxPriceAge: 1 days
        });
        riskEngine_.validateConfig(_config);
        emit IntegrationsUpdated(address(oracle_), address(rateModel_), address(riskEngine_), treasury_);
        emit MarketConfigUpdated(_config);
    }

    function setMarketConfig(ValiantTypes.MarketConfig calldata nextConfig) external onlyRiskAdmin {
        riskEngine.validateConfig(nextConfig);
        _config = nextConfig;
        emit MarketConfigUpdated(nextConfig);
    }

    function setIntegrations(
        IValiantOracle nextOracle,
        IValiantRateModel nextRateModel,
        ValiantRiskEngine nextRiskEngine,
        address nextTreasury
    ) external onlyOwner {
        require(address(nextOracle) != address(0), "ORACLE_ZERO");
        require(address(nextRateModel) != address(0), "RATE_ZERO");
        require(address(nextRiskEngine) != address(0), "RISK_ZERO");
        nextRiskEngine.validateConfig(_config);
        oracle = nextOracle;
        rateModel = nextRateModel;
        riskEngine = nextRiskEngine;
        treasury = nextTreasury;
        emit IntegrationsUpdated(address(nextOracle), address(nextRateModel), address(nextRiskEngine), nextTreasury);
    }

    function deposit(uint256 amount, address receiver)
        external
        nonReentrant
        whenActionNotPaused(ACTION_SUPPLY)
        returns (uint256)
    {
        require(amount != 0, "AMOUNT_ZERO");
        if (receiver == address(0)) receiver = msg.sender;
        _accrue();
        if (_config.supplyCap != 0) require(_market.totalCollateral + amount <= _config.supplyCap, "SUPPLY_CAP");
        asset.safeTransferFrom(msg.sender, address(this), amount);
        ValiantTypes.AccountPosition storage account = _accounts[receiver];
        account.collateral += amount;
        account.collateralEnabled = true;
        account.lastAction = uint64(block.timestamp);
        account.nonce++;
        _market.totalCollateral += amount;
        receiptToken.mint(receiver, amount);
        emit Deposited(msg.sender, receiver, amount);
        return amount;
    }

    function withdraw(uint256 amount, address receiver)
        external
        nonReentrant
        whenActionNotPaused(ACTION_SUPPLY)
        returns (uint256)
    {
        require(amount != 0, "AMOUNT_ZERO");
        if (receiver == address(0)) receiver = msg.sender;
        _accrue();
        require(amount <= availableLiquidity(), "LIQUIDITY");
        ValiantTypes.AccountPosition storage account = _accounts[msg.sender];
        require(account.collateral >= amount, "COLLATERAL");
        account.collateral -= amount;
        _market.totalCollateral -= amount;
        require(_canStand(msg.sender, _market.borrowIndex), "ACCOUNT_HEALTH");
        account.lastAction = uint64(block.timestamp);
        account.nonce++;
        receiptToken.burn(msg.sender, amount);
        asset.safeTransfer(receiver, amount);
        emit Withdrawn(msg.sender, receiver, amount);
        return amount;
    }

    function delegateCredit(address delegate, uint256 limit, uint64 expiresAt, bool revocable, bytes32 label)
        external
        whenActionNotPaused(ACTION_DELEGATE)
        returns (bytes32 key)
    {
        require(delegate != address(0) && delegate != msg.sender, "DELEGATE");
        require(limit == 0 || limit >= _config.minDelegation, "DELEGATION_LOW");
        if (_config.maxDelegation != 0) require(limit <= _config.maxDelegation, "DELEGATION_HIGH");
        require(limit <= _borrowCapacity(msg.sender), "CAPACITY");
        key = DelegationKeys.directLine(msg.sender, delegate);
        ValiantTypes.CreditLine storage line = _creditLines[key];
        bool wasActive = line.active;
        require(line.used <= limit, "USED_GT_LIMIT");
        line.sponsor = msg.sender;
        line.delegate = delegate;
        line.limit = limit;
        line.expiresAt = expiresAt;
        line.openedAt = line.openedAt == 0 ? uint64(block.timestamp) : line.openedAt;
        line.closedAt = 0;
        line.active = true;
        line.revocable = revocable;
        line.label = label;
        if (!wasActive) _market.activeDelegations++;
        emit CreditDelegated(msg.sender, delegate, limit, expiresAt);
    }

    function revokeDelegation(address delegate) external returns (bytes32 key) {
        key = DelegationKeys.directLine(msg.sender, delegate);
        ValiantTypes.CreditLine storage line = _creditLines[key];
        require(line.sponsor == msg.sender, "LINE");
        require(line.active, "INACTIVE");
        require(line.revocable || line.used == 0, "NOT_REVOCABLE");
        line.active = false;
        line.closedAt = uint64(block.timestamp);
        _market.activeDelegations--;
        emit CreditRevoked(msg.sender, delegate);
    }

    function subdelegateCredit(address sponsor, address borrower, uint256 limit, uint64 expiresAt, bytes32 label)
        external
        whenActionNotPaused(ACTION_DELEGATE)
        returns (bytes32 key)
    {
        require(sponsor != address(0) && borrower != address(0), "ADDRESS_ZERO");
        require(borrower != sponsor && borrower != msg.sender, "BORROWER");
        require(limit == 0 || limit >= _config.minDelegation, "DELEGATION_LOW");
        bytes32 parentKey = DelegationKeys.directLine(sponsor, msg.sender);
        ValiantTypes.CreditLine storage parent = _creditLines[parentKey];
        require(_lineLive(parent), "PARENT_LINE");
        require(limit <= _lineRemaining(parent), "PARENT_LIMIT");
        key = DelegationKeys.managedLine(sponsor, msg.sender, borrower);
        ValiantTypes.ManagedLine storage line = _managedLines[key];
        bool wasActive = line.active;
        require(line.used <= limit, "USED_GT_LIMIT");
        line.sponsor = sponsor;
        line.manager = msg.sender;
        line.borrower = borrower;
        line.limit = limit;
        line.expiresAt = expiresAt;
        line.openedAt = line.openedAt == 0 ? uint64(block.timestamp) : line.openedAt;
        line.closedAt = 0;
        line.active = true;
        line.label = label;
        if (!wasActive) _market.activeManagedLines++;
        emit ManagedCreditDelegated(sponsor, msg.sender, borrower, limit, expiresAt);
    }

    function revokeSubdelegation(address sponsor, address manager, address borrower) external returns (bytes32 key) {
        require(msg.sender == sponsor || msg.sender == manager, "AUTH");
        key = DelegationKeys.managedLine(sponsor, manager, borrower);
        ValiantTypes.ManagedLine storage line = _managedLines[key];
        require(line.active, "INACTIVE");
        line.active = false;
        line.closedAt = uint64(block.timestamp);
        _market.activeManagedLines--;
        emit ManagedCreditRevoked(sponsor, manager, borrower);
    }

    function borrow(address sponsor, uint256 amount, address receiver)
        external
        nonReentrant
        whenActionNotPaused(ACTION_BORROW)
        returns (bytes32 route)
    {
        require(sponsor != address(0), "SPONSOR_ZERO");
        require(amount != 0, "AMOUNT_ZERO");
        if (receiver == address(0)) receiver = msg.sender;
        _accrue();
        bytes32 key = DelegationKeys.directLine(sponsor, msg.sender);
        ValiantTypes.CreditLine storage line = _creditLines[key];
        require(_lineLive(line), "LINE_INACTIVE");
        require(_lineRemaining(line) >= amount, "LINE_LIMIT");
        _assertBorrowAdmission(sponsor, amount);
        line.used += amount;
        route = DelegationKeys.directRoute(sponsor, msg.sender);
        _increaseRoute(route, sponsor, address(0), msg.sender, sponsor, amount, false);
        asset.safeTransfer(receiver, amount);
        emit Borrowed(route, sponsor, msg.sender, receiver, amount, false);
    }

    function borrowWithSubdelegation(address sponsor, address manager, uint256 amount, address receiver)
        external
        nonReentrant
        whenActionNotPaused(ACTION_BORROW)
        returns (bytes32 route)
    {
        require(sponsor != address(0) && manager != address(0), "ADDRESS_ZERO");
        require(amount != 0, "AMOUNT_ZERO");
        if (receiver == address(0)) receiver = msg.sender;
        _accrue();
        bytes32 key = DelegationKeys.managedLine(sponsor, manager, msg.sender);
        ValiantTypes.ManagedLine storage line = _managedLines[key];
        require(_managedLineLive(line), "MANAGED_INACTIVE");
        require(_managedLineRemaining(line) >= amount, "MANAGED_LIMIT");
        _assertBorrowAdmission(sponsor, amount);
        line.used += amount;
        route = DelegationKeys.managedRoute(sponsor, manager, msg.sender);
        _increaseRoute(route, sponsor, manager, msg.sender, manager, amount, true);
        asset.safeTransfer(receiver, amount);
        emit Borrowed(route, sponsor, msg.sender, receiver, amount, true);
    }

    function repay(address sponsor, address borrower, uint256 amount)
        external
        nonReentrant
        whenActionNotPaused(ACTION_REPAY)
        returns (uint256 paid)
    {
        bytes32 route = DelegationKeys.directRoute(sponsor, borrower);
        paid = _repayRoute(msg.sender, route, amount);
    }

    function repayManaged(address sponsor, address manager, address borrower, uint256 amount)
        external
        nonReentrant
        whenActionNotPaused(ACTION_REPAY)
        returns (uint256 paid)
    {
        bytes32 route = DelegationKeys.managedRoute(sponsor, manager, borrower);
        paid = _repayRoute(msg.sender, route, amount);
    }

    function liquidate(address sponsor, address borrower, uint256 requestedRepay, address receiver)
        external
        nonReentrant
        whenActionNotPaused(ACTION_LIQUIDATE)
        returns (uint256 repaid, uint256 seized)
    {
        require(receiver != address(0), "RECEIVER_ZERO");
        _accrue();
        require(_isLiquidatable(sponsor, _market.borrowIndex), "ACCOUNT_HEALTHY");
        ValiantTypes.LiquidationQuote memory quote = _quoteDirectLiquidation(sponsor, borrower, requestedRepay);
        require(quote.repayAmount != 0, "NO_REPAY");
        bytes32 route = DelegationKeys.directRoute(sponsor, borrower);
        repaid = _repayRoute(msg.sender, route, quote.repayAmount);
        seized = quote.seizeAmount;
        ValiantTypes.AccountPosition storage account = _accounts[sponsor];
        if (seized > account.collateral) seized = account.collateral;
        account.collateral -= seized;
        account.seizedCollateral += seized;
        _market.totalCollateral -= seized;
        _market.totalLiquidated += repaid;
        _market.totalSeized += seized;
        receiptToken.burn(sponsor, seized);
        asset.safeTransfer(receiver, seized);
        emit Liquidated(sponsor, borrower, msg.sender, repaid, seized);
    }

    function accrue() external returns (uint256) {
        return _accrue();
    }

    function collectReserves(uint256 amount) external onlyKeeper nonReentrant {
        require(treasury != address(0), "TREASURY_ZERO");
        _accrue();
        require(amount <= _market.totalReserves, "RESERVES");
        require(amount <= asset.balanceOf(address(this)), "BALANCE");
        _market.totalReserves -= amount;
        asset.safeTransfer(treasury, amount);
    }

    function configuration() external view returns (ValiantTypes.MarketConfig memory) {
        return _config;
    }

    function marketState() external view returns (ValiantTypes.MarketState memory state) {
        state = _market;
        state.borrowIndex = currentBorrowIndex();
    }

    function accountSnapshot(address account) public view returns (ValiantTypes.AccountSnapshot memory snapshot) {
        uint256 index = currentBorrowIndex();
        (uint256 price, uint8 decimals_) = _loadPrice();
        uint256 debt = _accountDebtAt(account, index);
        uint256 capacity = HealthMath.borrowCapacity(_accounts[account].collateral, price, decimals_, _config.collateralFactorBps);
        uint256 health =
            HealthMath.healthFactor(_accounts[account].collateral, debt, price, decimals_, _config.liquidationThresholdBps);
        return ValiantTypes.AccountSnapshot({
            account: account,
            collateral: _accounts[account].collateral,
            debt: debt,
            principalDebt: _accounts[account].principalDebt,
            borrowCapacity: capacity,
            availableCredit: capacity > debt ? capacity - debt : 0,
            healthFactor: health,
            liquidatable: health < 1e18,
            collateralEnabled: _accounts[account].collateralEnabled
        });
    }

    function creditLine(address sponsor, address delegate) public view returns (ValiantTypes.LineSnapshot memory) {
        bytes32 key = DelegationKeys.directLine(sponsor, delegate);
        ValiantTypes.CreditLine memory line = _creditLines[key];
        return ValiantTypes.LineSnapshot({
            key: key,
            sponsor: line.sponsor,
            delegate: line.delegate,
            limit: line.limit,
            used: line.used,
            remaining: _lineRemaining(line),
            expiresAt: line.expiresAt,
            active: _lineLive(line),
            revocable: line.revocable,
            label: line.label
        });
    }

    function managedLine(address sponsor, address manager, address borrower)
        public
        view
        returns (ValiantTypes.ManagedLineSnapshot memory)
    {
        bytes32 key = DelegationKeys.managedLine(sponsor, manager, borrower);
        ValiantTypes.ManagedLine memory line = _managedLines[key];
        return ValiantTypes.ManagedLineSnapshot({
            key: key,
            sponsor: line.sponsor,
            manager: line.manager,
            borrower: line.borrower,
            limit: line.limit,
            used: line.used,
            remaining: _managedLineRemaining(line),
            expiresAt: line.expiresAt,
            active: _managedLineLive(line),
            label: line.label
        });
    }

    function routeDebt(address sponsor, address manager, address borrower, bool managed) public view returns (uint256) {
        bytes32 key = DelegationKeys.routeFromFlag(sponsor, manager, borrower, managed);
        return _routes[key].scaledDebt.amountFromScaledUp(currentBorrowIndex());
    }

    function borrowerDebt(address borrower) public view returns (uint256) {
        return _borrowerScaledDebt[borrower].amountFromScaledUp(currentBorrowIndex());
    }

    function totalDebt() public view returns (uint256) {
        return _market.totalScaledDebt.amountFromScaledUp(currentBorrowIndex());
    }

    function availableLiquidity() public view returns (uint256) {
        uint256 balance = asset.balanceOf(address(this));
        return balance > _market.totalReserves ? balance - _market.totalReserves : 0;
    }

    function currentBorrowIndex() public view returns (uint256) {
        if (_market.totalScaledDebt == 0 || block.timestamp == _market.lastAccrual) return _market.borrowIndex;
        uint256 debt = _market.totalScaledDebt.amountFromScaled(_market.borrowIndex);
        uint256 rate = rateModel.getBorrowRate(asset.balanceOf(address(this)), debt, _market.totalReserves);
        return DebtMath.accrueIndex(_market.borrowIndex, rate, block.timestamp - _market.lastAccrual);
    }

    function quoteLiquidation(address sponsor, address borrower, uint256 requestedRepay)
        public
        view
        returns (ValiantTypes.LiquidationQuote memory)
    {
        return _quoteDirectLiquidation(sponsor, borrower, requestedRepay);
    }

    function sponsorRoutes(address sponsor) external view returns (bytes32[] memory) {
        return _sponsorRoutes[sponsor];
    }

    function borrowerRoutes(address borrower) external view returns (bytes32[] memory) {
        return _borrowerRoutes[borrower];
    }

    function _increaseRoute(
        bytes32 routeKey,
        address sponsor,
        address manager,
        address borrower,
        address exposureAccount,
        uint256 amount,
        bool managed
    ) internal {
        uint256 scaled = amount.scaledFromAmount(_market.borrowIndex);
        ValiantTypes.LoanRoute storage route = _routes[routeKey];
        if (route.openedAt == 0) {
            route.sponsor = sponsor;
            route.manager = manager;
            route.borrower = borrower;
            route.exposureAccount = exposureAccount;
            route.openedAt = block.timestamp;
            route.managed = managed;
            _sponsorRoutes[sponsor].push(routeKey);
            _borrowerRoutes[borrower].push(routeKey);
        }
        route.scaledDebt += scaled;
        route.principal += amount;
        route.lastUpdate = block.timestamp;
        ValiantTypes.AccountPosition storage exposure = _accounts[exposureAccount];
        exposure.scaledDebt += scaled;
        exposure.principalDebt += amount;
        exposure.lastAction = uint64(block.timestamp);
        exposure.nonce++;
        _borrowerScaledDebt[borrower] += scaled;
        _market.totalScaledDebt += scaled;
        _market.totalPrincipal += amount;
    }

    function _repayRoute(address payer, bytes32 routeKey, uint256 amount) internal returns (uint256 paid) {
        require(amount != 0, "AMOUNT_ZERO");
        _accrue();
        ValiantTypes.LoanRoute storage route = _routes[routeKey];
        require(route.borrower != address(0), "ROUTE");
        (uint256 scaledPaid, uint256 amountPaid) = DebtMath.repayScaled(route.scaledDebt, amount, _market.borrowIndex);
        require(amountPaid != 0, "NO_DEBT");
        asset.safeTransferFrom(payer, address(this), amountPaid);
        route.scaledDebt -= scaledPaid;
        route.lastUpdate = block.timestamp;
        ValiantTypes.AccountPosition storage exposure = _accounts[route.exposureAccount];
        exposure.scaledDebt = scaledPaid >= exposure.scaledDebt ? 0 : exposure.scaledDebt - scaledPaid;
        _borrowerScaledDebt[route.borrower] =
            scaledPaid >= _borrowerScaledDebt[route.borrower] ? 0 : _borrowerScaledDebt[route.borrower] - scaledPaid;
        _market.totalScaledDebt = scaledPaid >= _market.totalScaledDebt ? 0 : _market.totalScaledDebt - scaledPaid;
        uint256 principalReduction = amountPaid > route.principal ? route.principal : amountPaid;
        route.principal -= principalReduction;
        exposure.principalDebt =
            principalReduction >= exposure.principalDebt ? 0 : exposure.principalDebt - principalReduction;
        _market.totalPrincipal =
            principalReduction >= _market.totalPrincipal ? 0 : _market.totalPrincipal - principalReduction;
        _decreaseLineUsage(route, principalReduction);
        exposure.lastAction = uint64(block.timestamp);
        exposure.nonce++;
        emit Repaid(routeKey, payer, route.borrower, amountPaid);
        return amountPaid;
    }

    function _decreaseLineUsage(ValiantTypes.LoanRoute storage route, uint256 amount) internal {
        if (amount == 0) return;
        if (route.managed) {
            bytes32 key = DelegationKeys.managedLine(route.sponsor, route.manager, route.borrower);
            ValiantTypes.ManagedLine storage line = _managedLines[key];
            line.used = amount >= line.used ? 0 : line.used - amount;
        } else {
            bytes32 key = DelegationKeys.directLine(route.sponsor, route.borrower);
            ValiantTypes.CreditLine storage line = _creditLines[key];
            line.used = amount >= line.used ? 0 : line.used - amount;
        }
    }

    function _assertBorrowAdmission(address sponsor, uint256 amount) internal view {
        require(amount <= availableLiquidity(), "LIQUIDITY");
        uint256 debt = _accountDebtAt(sponsor, _market.borrowIndex);
        uint256 projected = debt + amount;
        require(projected <= _borrowCapacity(sponsor), "CREDIT_CAPACITY");
        if (_config.borrowCap != 0) require(totalDebt() + amount <= _config.borrowCap, "BORROW_CAP");
    }

    function _borrowCapacity(address account) internal view returns (uint256) {
        (uint256 price, uint8 decimals_) = _loadPrice();
        return HealthMath.borrowCapacity(_accounts[account].collateral, price, decimals_, _config.collateralFactorBps);
    }

    function _canStand(address account, uint256 index) internal view returns (bool) {
        (uint256 price, uint8 decimals_) = _loadPrice();
        uint256 debt = _accountDebtAt(account, index);
        return HealthMath.borrowCapacity(_accounts[account].collateral, price, decimals_, _config.collateralFactorBps)
            >= debt;
    }

    function _isLiquidatable(address account, uint256 index) internal view returns (bool) {
        (uint256 price, uint8 decimals_) = _loadPrice();
        uint256 debt = _accountDebtAt(account, index);
        return HealthMath.isLiquidatable(_accounts[account].collateral, debt, price, decimals_, _config.liquidationThresholdBps);
    }

    function _accountDebtAt(address account, uint256 index) internal view returns (uint256) {
        return _accounts[account].scaledDebt.amountFromScaledUp(index);
    }

    function _quoteDirectLiquidation(address sponsor, address borrower, uint256 requestedRepay)
        internal
        view
        returns (ValiantTypes.LiquidationQuote memory)
    {
        (uint256 price, uint8 decimals_) = _loadPrice();
        uint256 index = currentBorrowIndex();
        uint256 accountDebt = _accountDebtAt(sponsor, index);
        bytes32 route = DelegationKeys.directRoute(sponsor, borrower);
        uint256 directRouteDebt = _routes[route].scaledDebt.amountFromScaledUp(index);
        return riskEngine.quoteLiquidation(
            _accounts[sponsor].collateral, accountDebt, directRouteDebt, requestedRepay, price, decimals_, _config
        );
    }

    function _accrue() internal returns (uint256 newIndex) {
        newIndex = currentBorrowIndex();
        if (newIndex == _market.borrowIndex) {
            _market.lastAccrual = block.timestamp;
            return newIndex;
        }
        uint256 interest = DebtMath.interestFromIndexMove(_market.totalScaledDebt, _market.borrowIndex, newIndex);
        uint256 reserves = (interest * _config.reserveFactorBps) / 10_000;
        _market.borrowIndex = newIndex;
        _market.lastAccrual = block.timestamp;
        _market.totalReserves += reserves;
        emit Accrued(newIndex, interest, reserves);
    }

    function _loadPrice() internal view returns (uint256 price, uint8 decimals_) {
        IValiantOracle.Price memory p = oracle.getPrice(address(asset));
        require(p.valid, "PRICE_INVALID");
        require(p.value != 0, "PRICE_ZERO");
        require(_config.maxPriceAge == 0 || block.timestamp <= p.updatedAt + _config.maxPriceAge, "PRICE_STALE");
        return (p.value, p.decimals);
    }

    function _lineLive(ValiantTypes.CreditLine memory line) internal view returns (bool) {
        if (!line.active) return false;
        if (line.expiresAt != 0 && block.timestamp > line.expiresAt) return false;
        return true;
    }

    function _managedLineLive(ValiantTypes.ManagedLine memory line) internal view returns (bool) {
        if (!line.active) return false;
        if (line.expiresAt != 0 && block.timestamp > line.expiresAt) return false;
        return true;
    }

    function _lineRemaining(ValiantTypes.CreditLine memory line) internal view returns (uint256) {
        if (!_lineLive(line) || line.limit <= line.used) return 0;
        return line.limit - line.used;
    }

    function _managedLineRemaining(ValiantTypes.ManagedLine memory line) internal view returns (uint256) {
        if (!_managedLineLive(line) || line.limit <= line.used) return 0;
        return line.limit - line.used;
    }
}
