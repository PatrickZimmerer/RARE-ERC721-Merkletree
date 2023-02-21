const { network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");
const keccak256 = require("keccak256");
const { MerkleTree } = require("merkletreejs");

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();

    // Generate set of special users that can enter the presale
    const approvedAddressesForPresale = [
        "0xe4064d8E292DCD971514972415664765e51B5364",
        "0x98697033803CEf8bdDB7CA883786CfA9a96F2Be4",
        "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "0xb7e390864a90b7b923c9f9310c6f98aafe43f707",
        "0xea674fdde714fd979de3edf0f56aa9716b898ec8",
        "0x054b7Ca525a58326162b916360166881dEB5F9C3",
    ];

    // Get proofs which will be passed into the constructor
    const proofs = approvedAddressesForPresale.map((address) =>
        keccak256(
            Buffer.concat([Buffer.from(address.replace("0x", ""), "hex")])
        )
    );

    // Create merkle tree for constructor
    const merkleTree = new MerkleTree(proofs, keccak256, {
        sortPairs: true,
    });

    const royaltyFeeInBip = 250; // 250 => 2.5% royalty

    const arguments = [proofs, merkleTree.getHexRoot(), royaltyFeeInBip];

    const erc721Merkle = await deploy("ERC721Merkle", {
        from: deployer,
        args: arguments,
        logs: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    });

    // only verify the code when not on development chains as hardhat
    if (
        !developmentChains.includes(network.name) &&
        process.env.ETHERSCAN_API_KEY
    ) {
        log("Verifying...");
        await verify(erc721Merkle.address, arguments);
    }
    log("deployed successfully at:", erc721Merkle.address);
    log("-----------------------------------------");
};

module.exports.tags = ["all", "erc721Merkle"];
