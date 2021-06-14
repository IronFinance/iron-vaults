// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IVaultPolicy.sol";

contract VaultPolicy is IVaultPolicy, Ownable {
    function canDeposit(address, address) external pure override returns (bool) {
        return true;
    }
}
