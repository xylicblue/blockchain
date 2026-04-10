// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/CropEscrow.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Setup a Mock USDT for testnet deployments
contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DeployScript is Script {
    function run() external {
        // startBroadcast() without parameters uses the --private-key passed in the CLI
        vm.startBroadcast();

        // Deploy a new fake USDT for testing on the Sepolia network
        MockUSDT usdt = new MockUSDT();
        
        // Deploy Escrow
        CropEscrow escrow = new CropEscrow(address(usdt));

        // Grant ORACLE_ROLE to the backend oracle wallet immediately
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");
        escrow.grantRole(escrow.ORACLE_ROLE(), oracleAddress);
        
        console.log("Mock USDT deployed to:", address(usdt));
        console.log("CropEscrow deployed to:", address(escrow));
        console.log("ORACLE_ROLE granted to:", oracleAddress);

        vm.stopBroadcast();
    }
}
