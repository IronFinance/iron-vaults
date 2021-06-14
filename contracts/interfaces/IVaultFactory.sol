// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IVaultFactory {
    function policy() external view returns (address);

    function router() external view returns (address);
}
