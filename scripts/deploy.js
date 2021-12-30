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
  nft = await NFT.attach("0x4e9c30CbD786549878049f808fb359741BF721ea");

  CHEEZ = await ethers.getContractFactory("CHEEZ");
  cheez = await CHEEZ.attach("0xBbD83eF0c9D347C85e60F1b5D2c58796dBE1bA0d");

  Treasury = await ethers.getContractFactory("Treasury");
  treasury = await Treasury.attach("0xf8c08c5aD8270424Ad914d379e85aC03a44fF996");

  Rebaser = await ethers.getContractFactory("contracts/Rebase.sol:Rebaser");
  miceRebaser = await Rebaser.deploy();
  catRebaser = await Rebaser.deploy()
  await miceRebaser.setIndex(initialIndex);
  await catRebaser.setIndex(initialIndex);

  CG = await ethers.getContractFactory("CheeseGame");
  cg = await upgrades.deployProxy(CG, [nft.address, cheez.address, miceRebaser.address, catRebaser.address], { kind: 'uups' });

  await miceRebaser.initialize( cg.address, nft.address, 0) 
  await catRebaser.initialize( cg.address, nft.address, 1) 

  Dist = await ethers.getContractFactory("Distributor");
  dist = await Dist.deploy(treasury.address, cg.address, 600e9);

  await cg.setDistributor(dist.address);

  console.log("cg deployed to: ", cg.address)
  console.log("dist deployed to: ", dist.address)

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
