// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {FRC20} from "src/FRC20/FRC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ExampleFRCToken is FRC20, Ownable {

    /// FID Contract Address on HAM L3
    address public fidStorageAddress = 0xCca2e3e860079998622868843c9A00dEbb591D30;

    /// Token Details
    uint256 public immutable MAX_SUPPLY = 777777777 ether;

    constructor() Ownable(msg.sender) FRC20("Example FRC Token", "FRC20", fidStorageAddress) {
        _setAllowlist(msg.sender, true); // Whitelist the deployer
        _mint(msg.sender, MAX_SUPPLY);
    }

    function setAllowlist(address _address, bool _allowed) public onlyOwner {
        _setAllowlist(_address, _allowed);
    }

}
