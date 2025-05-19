// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract HEUR is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable
{
    uint256 public constant VERSION = 1;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BLACKLISTER_ROLE = keccak256("BLACKLISTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    mapping(address => bool) private _blacklist;

    event Blacklisted(address indexed account);
    event UnBlacklisted(address indexed account);
    event ContractUpgraded(address indexed implementation);
    event BlackFundsDestroyed(address indexed account, uint256 amount);

    error AccountBlacklisted(address account);

    uint8 private _decimals;

    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        address defaultAdmin,
        address pauser,
        address minter,
        address blacklister,
        address upgrader
    ) public initializer {
        require(decimals_ <= 18, "Invalid decimals");
        require(defaultAdmin != address(0), "Invalid admin address");
        require(pauser != address(0), "Invalid pauser address");
        require(minter != address(0), "Invalid minter address");
        require(blacklister != address(0), "Invalid blacklister address");
        require(upgrader != address(0), "Invalid upgrader address");

        __ERC20_init(name, symbol);
        _decimals = decimals_;
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init(name);
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(BLACKLISTER_ROLE, blacklister);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be positive");
        _mint(to, amount);
    }

    function blacklist(address account) external onlyRole(BLACKLISTER_ROLE) {
        require(account != address(0), "Invalid account address");
        require(account != msg.sender, "Cannot blacklist self");
        require(!_blacklist[account], "Account already blacklisted");
        _blacklist[account] = true;
        emit Blacklisted(account);
    }

    function unBlacklist(address account) external onlyRole(BLACKLISTER_ROLE) {
        require(account != address(0), "Invalid account address");
        require(_blacklist[account], "Account not blacklisted");
        _blacklist[account] = false;
        emit UnBlacklisted(account);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklist[account];
    }

    function destroyBlacklistedFunds(
        address account
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_blacklist[account], "Account not blacklisted");
        uint256 dirtyFunds = balanceOf(account);
        require(dirtyFunds > 0, "Account has zero balance");
        _burn(account, dirtyFunds);
        emit BlackFundsDestroyed(account, dirtyFunds);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        if (_blacklist[from] || _blacklist[to]) {
            revert AccountBlacklisted(_blacklist[from] ? from : to);
        }
        super._update(from, to, value);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {
        require(
            newImplementation != address(0),
            "Invalid implementation address"
        );
        emit ContractUpgraded(newImplementation);
    }
}
