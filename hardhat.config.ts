import {config as dotEnvConfig} from "dotenv";
import {HardhatUserConfig} from "hardhat/types";
import "@openzeppelin/hardhat-upgrades";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";

dotEnvConfig();

const INFURA_API_KEY = process.env.INFURA_API_KEY || "";

const MOONRABBIT_TEST_KEY = process.env.MOONRABBIT_TEST_KEY || "";
const MOONRABBIT_PRIVATE_KEY = process.env.MOONRABBIT_PRIVATE_KEY || "";
const RINKEBY_PRIVATE_KEY = process.env.RINKEBY_PRIVATE_KEY || "";
const RINKEBY_PRIVATE_KEY_2 = process.env.RINKEBY_PRIVATE_KEY_2 || "";
const RINKEBY_PRIVATE_KEY_3 = process.env.RINKEBY_PRIVATE_KEY_3 || "";

const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    solidity: {
        compilers: [
            {
                version: "0.8.0",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200
                    }
                }
            },
        ]
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts"
    },
    networks: {
        hardhat: {
            accounts: [
                {
                    privateKey: RINKEBY_PRIVATE_KEY, balance: "10000000000000000000000",
                },
                {
                    privateKey: RINKEBY_PRIVATE_KEY_2, balance: "10000000000000000000000",
                },
                {
                    privateKey: RINKEBY_PRIVATE_KEY_3, balance: "10000000000000000000000",
                }
            ]
        },
        moonrabbit: {
            url: `https://evm.moonrabbit.com`,
            chainId: 1280,
            accounts: [MOONRABBIT_PRIVATE_KEY],
        },
        moonrabbit_test: {
            url: `https://testnetevm.moonrabbit.com`,
            chainId: 1280,
            accounts: [MOONRABBIT_TEST_KEY],
        },
        rinkeby: {
            url: `https://rinkeby.infura.io/v3/${INFURA_API_KEY}`,
            accounts: [RINKEBY_PRIVATE_KEY, RINKEBY_PRIVATE_KEY_2],
        },
        local: {
            url: "http://127.0.0.1:8545",
            accounts: [RINKEBY_PRIVATE_KEY, RINKEBY_PRIVATE_KEY_2, RINKEBY_PRIVATE_KEY_3],
            gas: 8000000,
            timeout: 100000
            /*chainId: 1*/
        }
    },
    contractSizer: {
        alphaSort: true,
        runOnCompile: true,
        disambiguatePaths: false,
    },
    gasReporter: {
        currency: 'USD'
    }
};

export default config;
