import {ethers, upgrades} from "hardhat";
import {
    Marketplace
} from "../typechain";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";

async function main() {
    let creator: SignerWithAddress;

    const nftAuctionStep = ethers.constants.WeiPerEther.mul(1000); //1000 ETH
    [creator] = await ethers.getSigners();

    const marketplaceFactory = await ethers.getContractFactory("Marketplace", creator);
    const marketplace = await upgrades.deployProxy(marketplaceFactory, [nftAuctionStep, 0]);
    await marketplace.deployed();
    console.log(`marketplace is deployed at: ${marketplace.address}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
