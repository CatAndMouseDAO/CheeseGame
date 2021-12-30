// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  [owner, user1] = await ethers.getSigners();
  const initialIndex = '1000000000'

  NFT = await ethers.getContractFactory("NFT");
  nft = await NFT.deploy();

  CHEEZ = await ethers.getContractFactory("CHEEZ");
  cheez = await CHEEZ.deploy(0);

  Rebaser = await ethers.getContractFactory("contracts/Rebase.sol:Rebaser");
  miceRebaser = await Rebaser.deploy();
  catRebaser = await Rebaser.deploy()
  await miceRebaser.setIndex(initialIndex);
  await catRebaser.setIndex(initialIndex);

  CG = await ethers.getContractFactory("CheeseGame");
  cg = await upgrades.deployProxy(CG, [nft.address, cheez.address, miceRebaser.address, catRebaser.address], { kind: 'uups' });

  console.log("cg deployed to: ", cg.address)

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
