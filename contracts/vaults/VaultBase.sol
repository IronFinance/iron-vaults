// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IVaultPolicy.sol";
import "../interfaces/IVaultFactory.sol";
import "../interfaces/IUniswapV2Router.sol";
import "../interfaces/IRouter.sol";
import "../interfaces/IWETH.sol";

abstract contract VaultBase is IVault, ReentrancyGuard {
    using SafeERC20 for IERC20;
    struct RouteInfo {
        address router;
        address[] path;
    }

    uint256 internal constant RATIO_PRECISION = 1000000; // 6 decimals
    address internal constant weth = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // matic

    // =========== state variables ================================

    bool public initialized;
    IVaultFactory public factory;

    address public override owner; // the only address can deposit, withdraw
    address public harvestor; // this address can call earn method
    uint256 public lastEarnBlock;
    address public override wantAddress;
    bool public override abandoned;
    uint256 public slippage = 50000; // 0.5%
    uint256 public templateId;

    // =========== events ================================

    event Earned(address indexed _earnedToken, uint256 _amount);
    event Deposited(uint256 _amount);
    event Withdraw(uint256 _amount);
    event Exit(uint256 _lpAmount);

    // =========== constructor ===========================

    constructor() {
        factory = IVaultFactory(msg.sender);
    }

    function initialize(address _owner, uint256 _vaultTemplateId) external virtual override {
        require(!initialized, "already init");
        require(msg.sender == address(factory), "!factory");
        harvestor = _owner;
        owner = _owner;
        templateId = _vaultTemplateId;
        _syncSwapRoutes();
        initialized = true;
    }

    // =========== views ===============================

    function canAbandon() public view virtual override returns (bool);

    function info()
        external
        view
        virtual
        override
        returns (
            uint256 _templateId,
            uint256 _balanceInFarm,
            uint256 _pendingRewards,
            bool _abandoned,
            bool _canDeposit,
            bool _canAbandon
        );

    function getPolicy() public view virtual returns (IVaultPolicy) {
        address _policy = factory.policy();
        return IVaultPolicy(_policy);
    }

    function getRouter() public view virtual returns (IRouter) {
        address _router = factory.router();
        return IRouter(_router);
    }

    // =========== modifiers ===========================

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier onlyHarvestor() {
        require(msg.sender == harvestor || msg.sender == owner, "!owner && !harvestor");
        _;
    }

    modifier canHarvest() {
        require(initialized, "!init");
        _;
    }

    modifier canDeposit() {
        require(initialized, "!init");
        IVaultPolicy policy = getPolicy();
        require(policy.canDeposit(address(this), owner), "!canDeposit");
        _;
    }

    // =========== restricted functions =================

    function updateSlippage(uint256 _slippage) public virtual override onlyOwner {
        slippage = _slippage;
    }

    function setHarvestor(address _harvestor) external onlyOwner {
        require(_harvestor != address(0x0), "cannot address set to zero");
        harvestor = _harvestor;
    }

    function abandon() external virtual override;

    function claimRewards() external virtual override;

    // =========== internal functions ==================

    function _safeSwap(
        address _swapRouterAddress,
        uint256 _amountIn,
        uint256 _slippage,
        address[] memory _path,
        address _to,
        uint256 _deadline
    ) internal {
        IUniswapV2Router _swapRouter = IUniswapV2Router(_swapRouterAddress);
        require(_path.length > 0, "invalidSwapPath");
        uint256[] memory amounts = _swapRouter.getAmountsOut(_amountIn, _path);
        uint256 _minAmountOut = (amounts[amounts.length - 1] * (RATIO_PRECISION - _slippage)) / RATIO_PRECISION;

        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amountIn, _minAmountOut, _path, _to, _deadline);
    }

    function _unwrapETH() internal {
        // WETH -> ETH
        uint256 wethBalance = IERC20(weth).balanceOf(address(this));
        if (wethBalance > 0) {
            IWETH(weth).withdraw(wethBalance);
        }
    }

    function _wrapETH() internal {
        // ETH -> WETH
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            IWETH(weth).deposit{value: ethBalance}();
        }
    }

    function _isWETH(address _token) internal pure returns (bool) {
        return _token == weth;
    }

    function _syncSwapRoutes() internal virtual;

    // =========== emergency functions =================

    function rescueFund(address _token, uint256 _amount) public virtual override onlyOwner {
        IERC20(_token).safeTransfer(owner, _amount);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data
    ) public onlyOwner returns (bytes memory) {
        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, string("DevFund::executeTransaction: Transaction execution reverted."));
        return returnData;
    }

    receive() external payable {}
}
