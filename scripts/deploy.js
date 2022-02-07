// const PolkaWarToken = "0xCCf84A8B29F706F01816071f386079E9B5aBac76";
const PolkaWarToken = "0x16153214e683018d5aa318864c8e692b66e16778"; // bsc test net Polka War token address

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const PolkaWarGame = await ethers.getContractFactory("PolkaWar");
  const polkaWarGame = await PolkaWarGame.deploy(PolkaWarToken);

  console.log("PolkaWarGame address:", polkaWarGame.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });