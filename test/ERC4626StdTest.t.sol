// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "erc4626-tests/ERC4626.test.sol";
import {WstResolv} from "../src/WstResolv.sol";

contract ERC4626StdTest is ERC4626Test {
    address public owner = makeAddr("owner");
    address _reward_ = address(new ERC20Mock());

    function setUp() public override {
        _underlying_ = address(new ERC20Mock());
        _vault_ = address(new WstResolv(_underlying_, _reward_, "Mock ERC4626", "MERC4626", owner));
        _delta_ = 0;
        _vaultMayBeEmpty = false;
        _unlimitedAmount = false;
    }
}
