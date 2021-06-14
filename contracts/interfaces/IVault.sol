// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IVault {
    function owner() external view returns (address);

    function wantAddress() external view returns (address);

    function balanceInFarm() external view returns (uint256);

    function pending() external view returns (uint256);

    function abandoned() external view returns (bool);

    function initialize(address _owner, uint256 _vaultTemplateId) external;

    function compound() external;

    function abandon() external;

    function claimRewards() external;

    function deposit(uint256 _wantAmt) external returns (uint256);

    function withdraw(uint256 _wantAmt) external returns (uint256);

    function withdrawAll() external returns (uint256);

    function updateSlippage(uint256 _slippage) external;

    function rescueFund(address _token, uint256 _amount) external;

    function canAbandon() external returns (bool);

    function info()
        external
        view
        returns (
            uint256 _templateId,
            uint256 _balanceInFarm,
            uint256 _pendingRewards,
            bool _abandoned,
            bool _canDeposit,
            bool _canAbandon
        );
}
