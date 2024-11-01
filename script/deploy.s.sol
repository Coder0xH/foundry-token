// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Saluki.sol";

contract DeployScript is Script {

    function run() external {
        // 开始广播交易
        vm.startBroadcast();

        // 部署 SalukiToken 合约
        SalukiToken salukiToken = new SalukiToken();

        // 打印合约地址
        console.log("SalukiToken deployed to:", address(salukiToken));

        // 停止广播
        vm.stopBroadcast();
    }
}