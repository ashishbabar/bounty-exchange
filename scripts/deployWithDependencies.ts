// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // Deploy token contracts
  const TokenFactory = await ethers.getContractFactory("MyToken");
  const bountyToken = await TokenFactory.deploy(
    "Tether USD",
    "USDT",
    "1000000000000000000000"
  );
  const stolenToken = await TokenFactory.deploy(
    "W Token",
    "WTOK",
    "1000000000000000000000"
  );
  console.log("bountyToken :>> ", bountyToken.address);
  console.log("stolenToken :>> ", stolenToken.address);
  // We get the contract to deploy
  const BountyExchangeFactory = await ethers.getContractFactory(
    "BountyExchange"
  );
  const bountyExchange = await BountyExchangeFactory.deploy();

  await bountyExchange.deployed();

  console.log("BountyExchange deployed to:", bountyExchange.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
