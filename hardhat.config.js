require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require('dotenv').config({ path: './.env' });
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  // defaultNetwork: "rinkeby",
  networks: {
    hardhat: {
      // gas: 2100000,
      // gasPrice: 8000000000
    },
    rinkeby: {
      url: "https://eth-rinkeby.alchemyapi.io/v2/tJQIbyElY-WxAgsk-BuTYebHKw0eZX18",
      accounts: [process.env.MNEMONIC]
    },
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts: [process.env.MNEMONIC]
    }
  },
  etherscan: {
    apiKey: {
      // mainnet: process.env.MAINNET_API_KEY,
      bscTestnet: process.env.BSCTESTNET_API_KEY,
      rinkeby: process.env.RINKEBY_API_KEY
    }
  },
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  }
};
