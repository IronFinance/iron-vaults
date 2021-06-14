// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IVault.sol";

contract VaultFactory is Ownable, Initializable {
    struct VaultTemplate {
        bytes code;
        bytes arguments;
    }

    VaultTemplate[] public vaultTemplates;
    mapping(address => address[]) public userVaults;
    address public policy;
    address public router;

    // EVENTS

    event PolicySet(address _policy);
    event RouterSet(address _policy);
    event VaultAdded(address indexed _owner, address _vault);

    // CONSTRUCTORS

    function initialize(address _policy, address _router) external onlyOwner initializer {
        policy = _policy;
        router = _router;
    }

    // PUBLIC FUNCTIONS

    function getUserVaults(address _user) external view returns (address[] memory) {
        return userVaults[_user];
    }

    function createVault(uint256 _templateId) external returns (address _vault) {
        VaultTemplate storage _template = vaultTemplates[_templateId];
        bytes memory bytecode = _template.code;
        require(bytecode.length != 0, "vault is not supported");
        bytes memory arguments = _template.arguments;
        require(arguments.length != 0, "invalid vault arguments");

        bytecode = abi.encodePacked(bytecode, arguments);
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, arguments, block.number));

        // solhint-disable no-inline-assembly
        assembly {
            _vault := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(_vault)) {
                revert(0, 0)
            }
        }

        IVault(_vault).initialize(msg.sender, _templateId);
        userVaults[msg.sender].push(_vault);
        emit VaultAdded(msg.sender, _vault);
    }

    // RESTRICTER FUNCTION

    function setPolicy(address _policy) external onlyOwner {
        require(_policy != address(0x0), "emptyAddress");
        require(_policy != policy, "unchanged");
        policy = _policy;
        emit PolicySet(_policy);
    }

    function setRouter(address _router) external onlyOwner {
        require(_router != address(0x0), "emptyAddress");
        require(_router != router, "unchanged");
        router = _router;
        emit RouterSet(_router);
    }

    function addTemplate(bytes calldata _code, bytes calldata _initArguments) external onlyOwner {
        VaultTemplate memory _template = VaultTemplate(_code, _initArguments);
        vaultTemplates.push(_template);
    }

    function removeTemplate(uint256 tid) external onlyOwner {
        vaultTemplates[tid] = VaultTemplate("", "");
    }
}
