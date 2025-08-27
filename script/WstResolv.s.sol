// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../src/WstResolv.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployWstResolv is Script {
	address public STRESOLV = 0xFE4BCE4b3949c35fB17691D8b03c3caDBE2E5E23;
	address public RESOLV = 0x259338656198eC7A76c729514D3CB45Dfbf768A1;

	function run() external {
		string memory NAME = "Wrapped Staked RESOLV";
		string memory SYMBOL = "wstRESOLV";
		address OWNER = vm.envAddress("OWNER");

		vm.startBroadcast();

		WstResolv vault = new WstResolv(STRESOLV, RESOLV, NAME, SYMBOL, OWNER);

		vm.stopBroadcast();
	}
}
